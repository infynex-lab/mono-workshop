#!/usr/bin/env bash
# End-to-end smoke test against a running container: Web Forms app (/webforms) and MVC app (/mvc).
# Usage: tests/smoke.sh [base-url]        default http://localhost:8080
# Env:   CHECK_LANDING=1  also checks the Apache landing page (apache target only)
set -uo pipefail
BASE="${1:-http://localhost:8080}"; BASE="${BASE%/}"
PASS=0; FAIL=0
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
check() {  # check <name> <haystack> <needle>
  if grep -qF -- "$3" <<<"$2"; then ok "$1"
  else bad "$1   (expected to find: $3)"; printf '%s\n' "$2" | head -15 | sed 's/^/        | /'; fi
}
status() { curl -s -o /dev/null -m 30 -w '%{http_code}' "$@"; }
expect_status() {  # expect_status <name> <code> <curl args...>
  local name="$1" want="$2"; shift 2
  local got; got="$(status "$@")"
  if [ "$got" = "$want" ]; then ok "$name -> $want"; else bad "$name -> expected $want, got $got"; fi
}

# Replays a Web Forms postback: sends every hidden field (ViewState etc.) + the given fields + the button.
postback() {  # postback <url> <cookiejar> <page-html> <button-id-suffix> [fieldSuffix=value ...]
  local url="$1" jar="$2" html="$3" button="$4"; shift 4
  local args=() tag n v kv field fname bname bval
  while IFS= read -r tag; do
    n="$(grep -oP 'name="\K[^"]*' <<<"$tag" | head -1)"
    v="$(grep -oP 'value="\K[^"]*' <<<"$tag" | head -1 || true)"
    args+=(--data-urlencode "$n=$v")
  done < <(grep -oP '<input[^>]*type="hidden"[^>]*>' <<<"$html")
  bname="$(grep -oP "<input[^>]*name=\"\K[^\"]*${button}(?=\")" <<<"$html" | head -1)"
  bval="$(grep -oP "<input[^>]*name=\"[^\"]*${button}\"[^>]*value=\"\K[^\"]*" <<<"$html" | head -1)"
  args+=(--data-urlencode "$bname=$bval")
  for kv in "$@"; do
    field="${kv%%=*}"
    fname="$(grep -oP "<input[^>]*name=\"\K[^\"]*${field}(?=\")" <<<"$html" | head -1)"
    args+=(--data-urlencode "$fname=${kv#*=}")
  done
  curl -sS -m 30 -b "$jar" -c "$jar" -X POST "$url" "${args[@]}"
}

api_tests() {  # api_tests <app>   (webforms | mvc)
  local app="$1" root="$BASE/$1" h l created
  echo "== [$app] JSON API =="
  h="$(curl -sS -m 30 "$root/api/health")"
  check "[$app] health ok"                   "$h" '"status":"ok"'
  check "[$app] health reports app name"     "$h" "\"app\":\"$app\""
  check "[$app] runs on Mono"                "$h" 'Mono'
  check "[$app] NuGet Newtonsoft.Json 13 loaded" "$h" '"newtonsoft":"13.'

  l="$(curl -sS -m 30 "$root/api/products")"
  check "[$app] list contains Keyboard"      "$l" 'Keyboard'
  expect_status "[$app] GET unknown id"      404 "$root/api/products?id=999"
  expect_status "[$app] POST invalid body"   400 -X POST -H 'Content-Type: application/json' -d '{"name":"","price":-1}' "$root/api/products"

  created="$(curl -sS -m 30 -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' \
             -d "{\"name\":\"Api-$app\",\"price\":19.9}" "$root/api/products")"
  check "[$app] POST returns 201"            "$created" '201'
  check "[$app] POST echoes product"         "$created" "Api-$app"
  check "[$app] new product listed"          "$(curl -sS -m 30 "$root/api/products")" "Api-$app"
}

webforms_tests() {
  local root="$BASE/webforms" jar="$WORK/wf.jar" html out
  echo "== [webforms] pages =="
  html="$(curl -sS -m 60 -c "$jar" "$root/Default.aspx")"
  check "[webforms] home renders (master page)" "$html" 'Classic Web Forms on Linux'
  check "[webforms] home shows Mono runtime"    "$html" 'Mono'
  check "[webforms] ViewState field present"    "$html" '__VIEWSTATE'

  out="$(postback "$root/Default.aspx" "$jar" "$html" btnGreet txtName='Mono Fans')"
  check "[webforms] postback handled"           "$out" 'Hello, Mono Fans!'
  check "[webforms] ViewState counter works"    "$out" 'clicked 1 time'

  html="$(curl -sS -m 30 -c "$jar" "$root/Products.aspx")"
  check "[webforms] grid lists seed data"       "$html" 'Keyboard'
  out="$(postback "$root/Products.aspx" "$jar" "$html" btnAdd txtName=WfWidget txtPrice=12.5)"
  check "[webforms] add product via postback"   "$out" 'Added product'
  check "[webforms] grid shows new product"     "$out" 'WfWidget'
  check "[webforms] API sees page-created data" "$(curl -sS -m 30 "$root/api/products")" 'WfWidget'
  expect_status "[webforms] static css served"  200 "$root/Content/Site.css"
}

mvc_tests() {
  local root="$BASE/mvc" jar="$WORK/mvc.jar" html out
  echo "== [mvc] pages =="
  html="$(curl -sS -m 90 -c "$jar" "$root/")"
  check "[mvc] home renders (Razor + layout)"   "$html" 'Classic ASP.NET MVC on Linux'
  check "[mvc] home shows Mono runtime"         "$html" 'Mono'
  check "[mvc] products page lists seed data"   "$(curl -sS -m 30 "$root/Products")" 'Keyboard'
  out="$(curl -sSL -m 30 -b "$jar" -c "$jar" -d 'name=MvcMouse&price=19.9' "$root/Products/Create")"
  check "[mvc] form POST + redirect works"      "$out" 'Added product'
  check "[mvc] new product rendered"            "$out" 'MvcMouse'
  expect_status "[mvc] static css served"       200 "$root/Content/Site.css"
  expect_status "[mvc] view source not served"  404 "$root/Views/Home/Index.cshtml"
}

echo "Waiting for $BASE (first request compiles the apps, can take a while) ..."
for app in webforms mvc; do
  for i in $(seq 1 90); do
    [ "$(status "$BASE/$app/api/health")" = 200 ] && break
    sleep 2
    [ "$i" = 90 ] && { echo "ERROR: $app did not become ready"; exit 1; }
  done
done

[ "${CHECK_LANDING:-0}" = 1 ] && { echo "== landing =="; check "landing page links to both apps" "$(curl -sS "$BASE/")" '/mvc/'; }
api_tests webforms
webforms_tests
api_tests mvc
mvc_tests

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
