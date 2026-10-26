#!/usr/bin/env bash
# Restores NuGet packages and builds the solution with Mono's msbuild, then collects the
# deployable sites into ./artifacts (or $OUT_DIR):
#
#   artifacts/webforms/   Default.aspx, Site.Master, Web.config, bin/*.dll ...
#   artifacts/mvc/        Global.asax, Views/, Web.config, bin/*.dll ...
#   artifacts/manifest.txt
#
# Usage: scripts/build.sh [restore|build|all]        (default: all)
# Env:   CONFIGURATION (Release)  TARGET_FRAMEWORK (e.g. v4.8; empty = value from the .csproj files)
#        OUT_DIR  PACKAGES_DIR  SOLUTION  NUGET_EXE  VSWEB_VERSION  REFASM_VERSION
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="${1:-all}"
SOLUTION="${SOLUTION:-MonoWorkshop.sln}"
CONFIGURATION="${CONFIGURATION:-Release}"
TARGET_FRAMEWORK="${TARGET_FRAMEWORK:-}"
OUT_DIR="${OUT_DIR:-$ROOT/artifacts}"
PACKAGES_DIR="${PACKAGES_DIR:-$ROOT/packages}"
TOOLS_DIR="$ROOT/.tools"
VSWEB_VERSION="${VSWEB_VERSION:-14.0.0.3}"     # NuGet package that provides Microsoft.WebApplication.targets on Linux
REFASM_VERSION="${REFASM_VERSION:-1.0.3}"       # reference assemblies, only used if Mono lacks the target framework
NUGET_EXE="${NUGET_EXE:-$(command -v nuget.exe || true)}"

nuget_cli() {
  if [ -n "$NUGET_EXE" ]; then mono "$NUGET_EXE" "$@"; else nuget "$@"; fi
}

restore() {
  # Optional credentials for a private feed (see nuget.config); Docker passes them as build secrets
  [ -r /run/secrets/feed_user ] && export FEED_USER="$(cat /run/secrets/feed_user)" || true
  [ -r /run/secrets/feed_pass ] && export FEED_PASS="$(cat /run/secrets/feed_pass)" || true

  mkdir -p "$PACKAGES_DIR" "$TOOLS_DIR"

  # 1) every packages.config in the repo -> ./packages
  while IFS= read -r pc; do
    echo ">> nuget restore $pc"
    nuget_cli restore "$pc" -PackagesDirectory "$PACKAGES_DIR" -ConfigFile nuget.config -NonInteractive
  done < <(find src -name packages.config | sort)

  # 2) build-time tooling: web application targets (needed to build Web Application Projects without Visual Studio)
  echo ">> nuget install MSBuild.Microsoft.VisualStudio.Web.targets $VSWEB_VERSION"
  nuget_cli install MSBuild.Microsoft.VisualStudio.Web.targets -Version "$VSWEB_VERSION" \
      -OutputDirectory "$TOOLS_DIR" -ConfigFile nuget.config -NonInteractive
}

effective_framework() {
  if [ -n "$TARGET_FRAMEWORK" ]; then echo "$TARGET_FRAMEWORK"; return; fi
  grep -oP '<TargetFrameworkVersion>\K[^<]+' src/Workshop.Core/Workshop.Core.csproj | head -1
}

build() {
  local vstools fw refdir digits tmp
  vstools="$(find "$TOOLS_DIR" -type d -name VSToolsPath | head -1 || true)"
  [ -n "$vstools" ] || { echo "VSToolsPath not found in $TOOLS_DIR - run '$0 restore' first" >&2; exit 1; }

  local extra=()
  if [ -n "$TARGET_FRAMEWORK" ]; then extra+=("-p:TargetFrameworkVersion=$TARGET_FRAMEWORK"); fi

  # Does this Mono ship reference assemblies for the requested framework (4.6 / 4.7.2 / 4.8 ...)?
  fw="$(effective_framework)"
  refdir="/usr/lib/mono/${fw#v}-api"
  if [ ! -d "$refdir" ]; then
    digits="${fw#v}"; digits="${digits//./}"
    echo ">> Mono has no $refdir; fetching Microsoft.NETFramework.ReferenceAssemblies.net$digits"
    nuget_cli install "Microsoft.NETFramework.ReferenceAssemblies.net$digits" -Version "$REFASM_VERSION" \
        -OutputDirectory "$TOOLS_DIR" -ConfigFile nuget.config -NonInteractive
    refdir="$(find "$TOOLS_DIR" -type d -path "*/build/.NETFramework/$fw" | head -1 || true)"
    [ -n "$refdir" ] || { echo "Could not locate reference assemblies for $fw" >&2; exit 1; }
    extra+=("-p:FrameworkPathOverride=$refdir")
  fi

  tmp="$(mktemp -d)"
  echo ">> msbuild $SOLUTION ($CONFIGURATION, framework $fw)"
  msbuild "$SOLUTION" -nologo -v:minimal \
      -p:Configuration="$CONFIGURATION" \
      -p:OutDir="$tmp/" \
      -p:VSToolsPath="$vstools" \
      -p:VisualStudioVersion=14.0 \
      ${extra[@]+"${extra[@]}"}

  # Web Application Projects publish a ready-to-deploy site into _PublishedWebsites/<ProjectName>
  local pub="$tmp/_PublishedWebsites"
  for p in Workshop.WebForms Workshop.Mvc; do
    [ -d "$pub/$p" ] || { echo "Expected $pub/$p was not produced. Found:" >&2; ls -R "$tmp" | head -50 >&2; exit 1; }
  done

  rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"
  cp -r "$pub/Workshop.WebForms" "$OUT_DIR/webforms"
  cp -r "$pub/Workshop.Mvc"      "$OUT_DIR/mvc"

  {
    echo "Built: $(date -u +%Y-%m-%dT%H:%M:%SZ)  configuration=$CONFIGURATION  framework=$fw"
    echo
    echo "Assemblies in artifacts (path, size):"
    (cd "$OUT_DIR" && find . -name '*.dll' -printf '  %P  (%s bytes)\n' | sort)
  } > "$OUT_DIR/manifest.txt"
  cat "$OUT_DIR/manifest.txt"
  rm -rf "$tmp"
  echo ">> Output written to $OUT_DIR"
}

case "$MODE" in
  restore) restore ;;
  build)   build ;;
  all)     restore; build ;;
  *) echo "usage: $0 [restore|build|all]" >&2; exit 2 ;;
esac
