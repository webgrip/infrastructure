# ADR-0006 Stage 2: the techdocs chain — the estate's worst surface (131 critical / 501 high
# measured on the stock stages). Three structural changes, forced by how DHI lays images out:
#
#   1. The FINAL stage IS dhi/python now. The old final was bare alpine that received its whole
#      python runtime via `COPY --from=python /usr/local` — stock alpine-python lives in
#      /usr/local, but dhi/python puts the interpreter in /usr/bin and site-packages in
#      /usr/lib/python3.13, so that transfer cannot survive the swap. Making the final stage the
#      python base itself dissolves the problem: pip installs (hash-locked, unchanged) run right
#      here, and the zensical venv's symlinks resolve against the same interpreter path.
#   2. node is copied EXPLICITLY. Stock node lives in /usr/local (so the old tree-copy carried
#      it); dhi/node keeps the binary in /usr/bin and ships no /usr/local at all — npm creates
#      /usr/local when the global tools install, so that tree still carries techdocs-cli,
#      mermaid-cli and pagefind, but the runtime needs the extra one-file COPY for node itself.
#   3. The plantuml stage is byte-identical on purpose. GitHub's release jar for the same
#      version is a DIFFERENT artifact than sourceforge's (sha1 mismatch, verified) — moving
#      the fetch would silently change shipped bytes. Also noted while here: the final image
#      carries plantuml.jar and its wrapper but NO JRE — `plantuml` cannot currently run in
#      this image; whether to add openjdk-jre via apk or drop the jar is a deliberate decision
#      for a separate change, not a side effect of this one.
#
# BUILD PREREQUISITE: the `dhi` Harbor proxy project (homelab-cluster ADR-0023) — dhi.io
# refuses anonymous pulls, so REGISTRY_DHI defaults to the proxy.
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
ARG REGISTRY_DOCKERHUB=docker.io
# renovate: datasource=docker depName=dhi.io/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DHI}/node:24.19.0-alpine3.23-dev@sha256:d00350837e082dc254939ffcf53861b3b965ff159e506d6ab1775710f91a82fe
# renovate: datasource=docker depName=dhi.io/python versioning=docker
ARG BASE_IMAGE=${REGISTRY_DHI}/python:3.13.15-alpine3.24-dev@sha256:8e51f99fa957d0b2531c4936b178d67d997e76fe48d7150357143295a03b1fd4
# The jar-fetch stage only runs curl; its base never ships. Kept on the stock JRE image purely
# to keep the fetched artifact byte-identical (see header note 3).
# renovate: datasource=docker depName=docker.io/library/eclipse-temurin versioning=docker
ARG JRE_IMAGE=${REGISTRY_DOCKERHUB}/library/eclipse-temurin:11.0.31_11-jre-jammy@sha256:eca8fa395077325c4065446e99e79af91c7283f10600d7f8c11530493e38a07c

FROM ${NODE_IMAGE} AS node

RUN corepack enable && corepack prepare npm@latest --activate

RUN apk add --no-cache python3 make g++

RUN npm install -g \
    @techdocs/cli@1.9.0 \
    @mermaid-js/mermaid-cli@11.4.2 \
    pagefind@1.5.2


FROM ${JRE_IMAGE} AS openjdk

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

RUN curl -o /opt/plantuml.jar -L http://sourceforge.net/projects/plantuml/files/plantuml.1.2023.7.jar/download && \
    echo "93fe1101c59381e0b3af86262b844871ca0eb987  /opt/plantuml.jar" | sha1sum -c - && \
    echo '#!/bin/sh\nexec java -jar /opt/plantuml.jar "$@"' > /usr/local/bin/plantuml && \
    chmod +x /usr/local/bin/plantuml


FROM ${BASE_IMAGE} AS final

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

RUN apk add --no-cache \
    libstdc++ \
    libffi \
    graphviz \
    chromium \
    rclone \
    git \
    tzdata

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Hash-locked installs, directly into this (python) base — see header note 1. Locks are
# regenerated with `pip-compile --generate-hashes --strip-extras --allow-unsafe` inside a
# python:3.13-alpine-lineage image; hashes are artifact hashes and hold across patch bumps.
COPY requirements.txt requirements-zensical.txt ./
RUN pip3 install --no-cache-dir --require-hashes -r requirements.txt && rm requirements.txt

# zensical CANNOT share the mkdocs environment: mkdocs-techdocs-core hard-pins
# pymdown-extensions==10.x while zensical requires >=11 — pip ResolutionImpossible (run 334).
# Own venv, own resolver universe; only the CLI lands on PATH.
RUN python3 -m venv /opt/zensical \
    && /opt/zensical/bin/pip install --no-cache-dir --require-hashes -r requirements-zensical.txt \
    && rm requirements-zensical.txt \
    && install -d /usr/local/bin \
    && ln -s /opt/zensical/bin/zensical /usr/local/bin/zensical

# The npm-global tree (techdocs-cli, mermaid-cli, pagefind) — npm creates /usr/local on
# dhi/node, so this carries exactly the tools. node itself stays in /usr/bin there and needs
# the explicit copy (musl -> musl, same alpine lineage).
COPY --from=node /usr/local /usr/local
COPY --from=node /usr/bin/node /usr/local/bin/node

# gitleaks: static (CGO_ENABLED=0) binary from the official Alpine-based image,
# via the Harbor ghcr pull-through. Gates every docs-site publish (`gitleaks dir
# site/ --config /etc/gitleaks/docs.toml`) — see gitleaks-docs.toml for the
# deliberately-narrow allowlist rationale.
# renovate: datasource=docker depName=ghcr.io/gitleaks/gitleaks versioning=docker
COPY --from=harbor.webgrip.dev/ghcr/gitleaks/gitleaks:v8.30.1 /usr/bin/gitleaks /usr/local/bin/gitleaks
COPY gitleaks-docs.toml /etc/gitleaks/docs.toml

# lychee: external link-rot checking (homelab estate item #15). Static musl
# build straight from the release tarball; lives here (not its own CI image)
# because this IS the docs toolchain — and the lycheeverse image mysteriously
# never started as a job container on the shared dind (7s failures, 2026-08-11).
# renovate: datasource=github-releases depName=lycheeverse/lychee versioning=semver
ARG LYCHEE_VERSION=0.24.2
RUN wget -qO- "https://github.com/lycheeverse/lychee/releases/download/lychee-v${LYCHEE_VERSION}/lychee-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /tmp \
    && mv "/tmp/lychee-x86_64-unknown-linux-musl/lychee" /usr/local/bin/lychee \
    && rm -rf /tmp/lychee-x86_64-unknown-linux-musl \
    && lychee --version
COPY --from=openjdk /opt/plantuml.jar /opt/plantuml.jar
COPY --from=openjdk /usr/local/bin/plantuml /usr/local/bin/plantuml

WORKDIR /docs

LABEL org.opencontainers.image.title="WebGrip TechDocs Builder" \
    org.opencontainers.image.description="TechDocs build image with MkDocs, PlantUML, Mermaid, and Chromium" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${BASE_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

