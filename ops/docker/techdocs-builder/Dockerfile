ARG REGISTRY_DOCKERHUB=docker.io
# Every stage base pinned AND annotated. These digests were pinned without annotations, which is
# why the node and python stages sat on alpine3.20 while the final stage moved to 3.23 — nothing
# was watching them. The digests are unchanged here (annotating is not upgrading); Renovate now
# proposes the catch-up bumps as reviewable PRs.
# renovate: datasource=docker depName=docker.io/library/alpine versioning=docker
ARG FINAL_BASE=${REGISTRY_DOCKERHUB}/library/alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11
# renovate: datasource=docker depName=docker.io/library/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24.1.0-alpine3.20@sha256:8fe019e0d57dbdce5f5c27c0b63d2775cf34b00e3755a7dea969802d7e0c2b25
# renovate: datasource=docker depName=docker.io/library/python versioning=docker
ARG PYTHON_IMAGE=${REGISTRY_DOCKERHUB}/library/python:3.13.3-alpine3.20@sha256:40a4559d3d6b2117b1fbe426f17d55b9100fa40609733a1d0c3f39e2151d4b33
# renovate: datasource=docker depName=docker.io/library/eclipse-temurin versioning=docker
ARG JRE_IMAGE=${REGISTRY_DOCKERHUB}/library/eclipse-temurin:11.0.31_11-jre-jammy@sha256:76ffb747ad3a62a8b81ac3c76e2c3b1c06e475b1e10109d0a4dd604db627c9f5

FROM ${NODE_IMAGE} AS node

RUN corepack enable && corepack prepare npm@latest --activate

RUN apk add --no-cache python3 make g++

RUN npm install -g \
    @techdocs/cli@1.9.0 \
    @mermaid-js/mermaid-cli@11.4.2


FROM ${PYTHON_IMAGE} AS python

RUN apk add --no-cache graphviz

# Hash-locked installs. Direct deps live in requirements*.in; the .txt locks are
# regenerated with `pip-compile --generate-hashes --strip-extras --allow-unsafe`
# INSIDE python:3.13-alpine (matching this stage) so resolution and hashes are
# computed for the environment that actually installs them.
COPY requirements.txt requirements-zensical.txt ./
RUN pip3 install --no-cache-dir --require-hashes -r requirements.txt

# zensical CANNOT share the mkdocs environment: mkdocs-techdocs-core hard-pins
# pymdown-extensions==10.x (still true in 1.7.0) while zensical requires >=11 —
# pip ResolutionImpossible, which is what killed the v1.4.0 release gate (run 334).
# Own venv, own resolver universe; only the CLI lands on PATH.
RUN python3 -m venv /opt/zensical \
    && /opt/zensical/bin/pip install --no-cache-dir --require-hashes -r requirements-zensical.txt \
    && ln -s /opt/zensical/bin/zensical /usr/local/bin/zensical


FROM ${JRE_IMAGE} AS openjdk

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

RUN curl -o /opt/plantuml.jar -L http://sourceforge.net/projects/plantuml/files/plantuml.1.2023.7.jar/download && \
    echo "93fe1101c59381e0b3af86262b844871ca0eb987  /opt/plantuml.jar" | sha1sum -c - && \
    echo '#!/bin/sh\nexec java -jar /opt/plantuml.jar "$@"' > /usr/local/bin/plantuml && \
    chmod +x /usr/local/bin/plantuml


FROM ${FINAL_BASE} AS final

ARG FINAL_BASE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

RUN apk add --no-cache \
    libstdc++ \
    libffi \
    graphviz \
    chromium \
    rclone

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

COPY --from=node /usr/local /usr/local
COPY --from=python /usr/local /usr/local
# zensical's isolated venv (see the python stage); its bin/python symlinks into
# /usr/local, which the line above already carried over.
COPY --from=python /opt/zensical /opt/zensical

# gitleaks: static (CGO_ENABLED=0) binary from the official Alpine-based image,
# via the Harbor ghcr pull-through. Gates every docs-site publish (`gitleaks dir
# site/ --config /etc/gitleaks/docs.toml`) — see gitleaks-docs.toml for the
# deliberately-narrow allowlist rationale.
# renovate: datasource=docker depName=ghcr.io/gitleaks/gitleaks versioning=docker
COPY --from=harbor.webgrip.dev/ghcr/gitleaks/gitleaks:v8.30.1 /usr/bin/gitleaks /usr/local/bin/gitleaks
COPY gitleaks-docs.toml /etc/gitleaks/docs.toml
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
    org.opencontainers.image.base.name="${FINAL_BASE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

