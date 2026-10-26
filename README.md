# Classic .NET Framework on Linux: Web Forms + MVC 5 with Apache + mod_mono

A complete workshop repository. It contains a real **Visual Studio solution** with two classic
.NET Framework web applications and a shared library that uses a **NuGet package**,
a **Dockerfile** that restores, builds and hosts them with **Apache + mod_mono**,
a **smoke-test suite**, and a **GitHub Actions pipeline** that builds, tests and publishes the binaries.

> **Honest caveat.** Mono/mod_mono are deprecated and Debian 10 (the last Debian shipping mod_mono)
> is end-of-life. This is ideal for learning and for evaluating legacy apps. For production, the supported
> options are Windows containers (IIS) or migrating to ASP.NET Core.

## 1. What is in the repo

```
MonoWorkshop.sln                  Open in Visual Studio (Windows) or build with msbuild (Mono)
nuget.config                      NuGet sources (nuget.org; private-feed example included)
src/
  Workshop.Core/                  Class library (.NET Framework). NuGet: Newtonsoft.Json
  Workshop.WebForms/              ASP.NET Web Forms app: master page, GridView, postback, ViewState,
                                  IHttpHandler JSON API (api/health, api/products)
  Workshop.Mvc/                   ASP.NET MVC 5.2.7 app: Razor views, routes, JSON API controllers
docker/
  Dockerfile                      Stages: build -> artifacts | xsp | apache (default)
  workshop.conf                   Apache vhost with mod_mono directives (hosts /webforms and /mvc)
  entrypoint.sh, index.html
scripts/build.sh                  NuGet restore + msbuild + collect output (works inside and outside Docker)
tests/smoke.sh                    End-to-end tests for both apps (pages, postbacks, API)
.github/workflows/                CI: build, test (apache + xsp), upload binaries, publish image
Makefile, docker-compose.yml
```

Both apps use the **same** `Workshop.Core` library and the same in-memory product data, and both
expose `GET /api/health` and `GET/POST /api/products`. `/api/health` reports the Mono version and the loaded
`Newtonsoft.Json` version, which proves the NuGet package was restored and shipped.

## 2. Quick start

Requirements: Docker with BuildKit (Docker 20.10+), `make`, `curl`. No .NET or Mono needed on your machine.

```bash
make artifacts    # NuGet restore + msbuild inside Docker; binaries land in ./artifacts
make build        # build the Apache + mod_mono runtime image
make run          # http://localhost:8080
make test         # smoke tests: Web Forms + MVC + API
```

Open:

- http://localhost:8080/webforms/Default.aspx and http://localhost:8080/webforms/Products.aspx
- http://localhost:8080/mvc/ and http://localhost:8080/mvc/Products
- http://localhost:8080/webforms/api/health, http://localhost:8080/mvc/api/products

Debug without Apache (standalone Mono server): `make build run test TARGET=xsp PORT=8081`.

## 3. The build output (the binaries)

`make artifacts` (or the `artifacts` job step in CI) writes:

```
artifacts/
  webforms/                 deployable site: Default.aspx, Products.aspx, Site.Master, Web.config,
    bin/                    Workshop.WebForms.dll, Workshop.Core.dll, Newtonsoft.Json.dll
  mvc/                      deployable site: Global.asax, Views/, Content/, Web.config,
    bin/                    Workshop.Mvc.dll, Workshop.Core.dll, Newtonsoft.Json.dll,
                            System.Web.Mvc.dll, System.Web.Razor.dll, System.Web.WebPages*.dll,
                            System.Web.Helpers.dll, Microsoft.Web.Infrastructure.dll
  manifest.txt              list of produced assemblies with sizes
```

Each folder is a complete, self-contained ASP.NET site: a folder you can point a web server at.
The `.dll` files in `bin/` are your compiled application (`Workshop.WebForms.dll`, `Workshop.Mvc.dll`,
`Workshop.Core.dll`) plus the NuGet dependencies.

### How to use the output

| Goal | How |
|---|---|
| **Run it right now, no image rebuild** | `make run-artifacts` mounts `artifacts/webforms` and `artifacts/mvc` into the Apache image on http://localhost:8082 |
| **Bake it into an image** | `make build`: the Dockerfile copies the same folders to `/var/www/webforms` and `/var/www/mvc` |
| **Pull it out of an existing image** | `docker create --name tmp webforms-mono:apache && docker cp tmp:/var/www/webforms ./webforms && docker rm tmp` |
| **Deploy on a Linux server** | Install `apache2 libapache2-mod-mono mono-apache-server4 mono-complete`, copy the folders to `/var/www/...`, drop `docker/workshop.conf` into `sites-available`, `a2enmod mod_mono`, `a2ensite` |
| **Run with xsp4 only** | `xsp4 --applications /webforms:/path/to/artifacts/webforms,/mvc:/path/to/artifacts/mvc --port 8080` |
| **Deploy on Windows/IIS** | Copy the same folders into an IIS site (the compiled assemblies are plain .NET Framework). `Web.config` already contains the IIS `system.webServer` sections |
| **CI download** | The pipeline uploads the folder as the build artifact **webforms-mvc-binaries** |

## 4. How the build works

`scripts/build.sh` is the single entry point (used by the Dockerfile, `make local-build`, and runnable on any
machine that has Mono + msbuild):

1. **NuGet restore**: every `src/**/packages.config` is restored into `./packages`
   (`nuget.exe restore packages.config -PackagesDirectory packages`). Csproj `HintPath`s point there.
2. **Web build tooling**: installs the NuGet package `MSBuild.Microsoft.VisualStudio.Web.targets`.
   It provides `Microsoft.WebApplication.targets`, which Visual Studio normally supplies,
   so Web Application Projects build on Linux. It is passed to msbuild as `VSToolsPath`.
3. **msbuild** of `MonoWorkshop.sln` with `OutDir` set. The web targets then create
   `_PublishedWebsites/<project>` (site files and `bin`).
4. **Collect**: the script copies those folders to `artifacts/webforms` and `artifacts/mvc` and writes `manifest.txt`.

The Dockerfile restores in a separate layer first, so NuGet packages are cached until a `.csproj` or
`packages.config` changes (plus a BuildKit cache mount for NuGet's HTTP cache).

## 5. NuGet packages: how they are covered

- Add a package in Visual Studio as usual (it edits `packages.config` and the csproj `<Reference>`)
  or manually: add `<package id=".." version=".." targetFramework="net472" />` to the project's `packages.config`
  and a `<Reference ...><HintPath>..\..\packages\Id.Version\lib\net45\X.dll</HintPath></Reference>` to the csproj.
- The pipeline always restores from `packages.config`; nothing is committed under `packages/`.
- `/api/health` shows the loaded Newtonsoft.Json version, and `tests/smoke.sh` asserts it, so a missing or
  wrong package fails the pipeline.
- **Private feeds**: add the source and the commented credentials block in `nuget.config`, then pass secrets:
  `docker build --secret id=feed_user,env=FEED_USER --secret id=feed_pass,env=FEED_PASS ...`
  (in GitHub Actions, uncomment the `secrets:` block in the workflow). Credentials are not stored in image layers.
- **Adding a new project**: add its `.csproj` and `packages.config` to the restore `COPY` lines in `docker/Dockerfile`,
  and to the solution.

## 6. Using your own solution

1. Copy your solution and projects into the repo (keep `scripts/`, `docker/`, `tests/`, `.github/`).
2. In `docker/Dockerfile`, update the `COPY ... .csproj ... packages.config` lines and the `/out/...` copy lines;
   in `scripts/build.sh`, update `SOLUTION` and the project names in `_PublishedWebsites`.
3. Choose the framework: compile against any 4.x target with `--build-arg TARGET_FRAMEWORK=v4.6.2` / `v4.8`
   (`make artifacts TARGET_FRAMEWORK=v4.8`). If the Mono image lacks those reference assemblies, `build.sh`
   fetches `Microsoft.NETFramework.ReferenceAssemblies.*` from NuGet automatically.
   Running on Mono does not need the same version: any 4.x app runs on Mono's 4.x runtime.
4. Mono limits: use `<compilation targetFramework="4.5">` in Web.config; avoid Windows-only features
   (Windows auth, COM, WCF hosting, Roslyn `CodeDom` provider package, `System.Web.Optimization` quirks).
5. Adapt `tests/smoke.sh` to your pages.

## 7. Workshop outline (about 2 hours)

1. **The problem (10 min)**: Web Forms/MVC 5 = `System.Web` + IIS. Options: Windows container, Mono, migration.
2. **Solution tour (15 min)**: csproj/packages.config, `Workshop.Core` shared by two apps, master page vs Razor layout,
   handlers vs controllers.
3. **Build (15 min)**: read `scripts/build.sh`; run `make artifacts`; explore `artifacts/` and `manifest.txt`.
4. **Run on xsp4 (10 min)**: `make build run test TARGET=xsp PORT=8081`. *If it fails on xsp4, mod_mono will not fix it.*
5. **Apache + mod_mono (20 min)**: read `docker/workshop.conf`; `make build run test`; follow `make logs`.
6. **Use the output (10 min)**: `make run-artifacts`; `docker cp`; Windows/IIS discussion.
7. **Pipeline (15 min)**: read the workflow: build, upload artifact, test both targets, publish.
8. **Break it on purpose (20 min)**: exercises below.
9. **Wrap-up (5 min)**: production options.

## 8. Exercises

- **Case sensitivity**: rename `Content/Site.css` to `site.css` (keep the reference) and watch the 404 on Linux.
- **Add a NuGet package** (e.g. `NLog`) to `Workshop.Core`, use it, rebuild, check `artifacts/manifest.txt`.
- **Add an API endpoint** in `Workshop.Core` and expose it in both apps (handler and controller).
- **Retarget**: `make artifacts TARGET_FRAMEWORK=v4.8`.
- **Break routing**: remove the `UrlRoutingModule` block in `Workshop.Mvc/Web.config` and observe MVC routes failing.
- **Read the logs**: throw an exception in a page and compare the xsp4 and Apache error output.
- **Persistence**: restart the container; the in-memory data resets. Add a volume or a database.

## 9. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `E: Unable to locate package libapache2-mod-mono` | The base distro no longer ships it. Keep `debian:buster-slim` + archive.debian.org, or use the `xsp` target |
| Build: `Microsoft.WebApplication.targets` not found | The VSToolsPath package was not restored: run `scripts/build.sh restore` and check network/nuget.config |
| Build: reference assembly / framework errors | Pass `TARGET_FRAMEWORK` (e.g. `v4.7.2`); see section 6 |
| `_PublishedWebsites/...` not produced | Look at the file listing the script prints; confirm the project imports `Microsoft.WebApplication.targets` |
| Apache starts, every request 500/503 | `make logs`; test with `TARGET=xsp` to isolate Apache vs app |
| Web Forms: control is `null` | Field in `.designer.cs` does not match the `ID` in the `.aspx` |
| MVC: 404 on every route | Routing module missing, or the app is not hosted at the path you request (`/mvc/...`) |
| MVC: Razor compile errors | `Views/Web.config` versions must match the installed `System.Web.Mvc` (5.2.7.0) |
| Works on Windows, 404 on Linux | File name casing |
| Smoke test postback fails | Compare with a browser (view source, hidden fields); Mono versions may omit `__EVENTVALIDATION` (that is fine) |
