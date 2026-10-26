# syntax=docker/dockerfile:1
#
# Stages / targets
#   build      compiles the solution with Mono msbuild (+ NuGet restore)
#   artifacts  scratch image holding ONLY the build output  -> docker build --target artifacts --output artifacts .
#   xsp        runtime: Mono's standalone xsp4 server       (debug / compare)
#   apache     runtime: Apache httpd + mod_mono             (the workshop goal, default)
#
# Build args
#   TARGET_FRAMEWORK  e.g. v4.6.2 / v4.7.2 / v4.8 (empty = whatever the .csproj files say)
#   CONFIGURATION     Release (default) or Debug
#   BUILD_IMAGE       image that has Mono + msbuild (default mono:6.12)

ARG BUILD_IMAGE=mono:6.12

############################ build ############################
FROM ${BUILD_IMAGE} AS build
ARG NUGET_VERSION=v6.9.1
# Debian 10 (buster) is EOL - use archive.debian.org
RUN printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list \
 && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive \
 && apt-get update && apt-get install -y --no-install-recommends ca-certificates && update-ca-certificates && rm -rf /var/lib/apt/lists/*
ENV MONO_TLS_PROVIDER=legacy
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_DIR=/etc/ssl/certs
RUN printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list \
 && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive \
 && apt-get update && apt-get install -y --no-install-recommends msbuild nuget ca-certificates curl && rm -rf /var/lib/apt/lists/* || true
RUN if ! command -v nuget.exe >/dev/null 2>&1 && ! command -v nuget >/dev/null 2>&1; then \
      curl -fsSL "https://dist.nuget.org/win-x86-commandline/${NUGET_VERSION}/nuget.exe" -o /usr/local/bin/nuget.exe 2>/dev/null || \
      curl -fsSL "https://aka.ms/nugetclidl" -o /usr/local/bin/nuget.exe 2>/dev/null || true; \
    fi && \
    chmod +x /usr/local/bin/nuget.exe 2>/dev/null || true

WORKDIR /src
ENV OUT_DIR=/out

# Layer 1: only what NuGet restore needs, so packages are cached until a csproj/packages.config changes
COPY nuget.config MonoWorkshop.sln ./
COPY scripts/build.sh scripts/build.sh
COPY src/Workshop.Core/Workshop.Core.csproj          src/Workshop.Core/packages.config          src/Workshop.Core/
COPY src/Workshop.WebForms/Workshop.WebForms.csproj  src/Workshop.WebForms/packages.config      src/Workshop.WebForms/
COPY src/Workshop.Mvc/Workshop.Mvc.csproj            src/Workshop.Mvc/packages.config           src/Workshop.Mvc/
RUN --mount=type=cache,target=/root/.local/share/NuGet \
    --mount=type=secret,id=feed_user,required=false \
    --mount=type=secret,id=feed_pass,required=false \
    bash scripts/build.sh restore

# Layer 2: sources + compile
COPY src/ src/
ARG TARGET_FRAMEWORK=
ARG CONFIGURATION=Release
ENV TARGET_FRAMEWORK=${TARGET_FRAMEWORK} CONFIGURATION=${CONFIGURATION}
RUN bash scripts/build.sh build

############################ artifacts (export only) ############################
FROM scratch AS artifacts
COPY --from=build /out/ /

############################ runtime base: Mono + Apache + mod_mono ############################
# Debian 10 "buster" is the last Debian release that ships libapache2-mod-mono.
# It is end-of-life, so packages come from archive.debian.org. Fine for a workshop, not for production.
FROM debian:buster-slim AS runtime-base
RUN printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list \
 && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apache2 libapache2-mod-mono mono-apache-server4 mono-xsp4 mono-complete \
        libgdiplus ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
ENV HOME=/tmp

############################ xsp ############################
FROM runtime-base AS xsp
COPY --from=build /out/webforms /var/www/webforms
COPY --from=build /out/mvc      /var/www/mvc
EXPOSE 80
CMD ["xsp4", "--applications", "/webforms:/var/www/webforms,/mvc:/var/www/mvc", "--address", "0.0.0.0", "--port", "80", "--nonstop"]

############################ apache (default) ############################
FROM runtime-base AS apache
RUN a2dismod mpm_event \
 && a2enmod mpm_prefork mod_mono \
 && a2dissite 000-default \
 && echo 'ServerName localhost' > /etc/apache2/conf-available/servername.conf \
 && a2enconf servername \
 && ln -sf /dev/stdout /var/log/apache2/access.log \
 && ln -sf /dev/stderr /var/log/apache2/error.log

COPY docker/workshop.conf /etc/apache2/sites-available/workshop.conf
RUN a2ensite workshop
COPY docker/index.html /var/www/html/index.html

COPY --from=build /out/webforms /var/www/webforms
COPY --from=build /out/mvc      /var/www/mvc
RUN chown -R www-data:www-data /var/www/webforms /var/www/mvc

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
HEALTHCHECK --interval=15s --timeout=10s --start-period=30s --retries=6 \
  CMD curl -fsS http://localhost/webforms/api/health || exit 1
ENTRYPOINT ["/entrypoint.sh"]
