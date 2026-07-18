ARG REGISTRY_DOCKERHUB=docker.io
ARG REGISTRY_GHCR=ghcr.io

# All base-image refs are global ARGs (before any FROM) so their composed defaults resolve;
# the registry is a variable so CI can route through the Harbor pull-through proxy, and the
# literal tag+digest lets Renovate's dockerfile manager keep both current. Toolchains are
# copied from their official bookworm-slim images — glibc-compatible with the CPython base.
# uv is copied from its official image (reproducible; no `curl | sh`).
ARG UV_IMAGE=${REGISTRY_GHCR}/astral-sh/uv:0.9.2@sha256:6dbd7c42a9088083fa79e41431a579196a189bcee3ae68ba904ac2bf77765867
# node 24 (matches CI node:24-alpine) — for moon, openspec, and the web gates.
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d
# rust stable (matches CI rust:latest) — for the core-rs gates + the wasm32 target.
ARG RUST_IMAGE=${REGISTRY_DOCKERHUB}/library/rust:1-slim-bookworm@sha256:99e09cb2284e2ddbb73a995deee3e91783fd04d177602ccf6eab326d778ee777
# docker CLI (client only; the daemon is a DinD sidecar reached via DOCKER_HOST) — for
# OpenHands' Docker sandbox and docker-based gates. Matches the cluster DinD docker:29.5.3.
ARG DOCKER_IMAGE=${REGISTRY_DOCKERHUB}/library/docker:29.5.3-cli@sha256:11e1133c30f3ceb73c6bdc7dfb78b3f9ed8e8e0d1d0400e91c5ec2eb240bf2ff
# OpenHands is a Python tool; base on the matching CPython slim image. python 3.12 also
# matches CI's python:3.12 for the domain scripts, so one interpreter serves both.
ARG BASE_IMAGE=${REGISTRY_DOCKERHUB}/library/python:3.12-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b

FROM ${UV_IMAGE} AS uv
FROM ${NODE_IMAGE} AS node
FROM ${RUST_IMAGE} AS rust
FROM ${DOCKER_IMAGE} AS docker

FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

# OpenHands CLI (bundles the Software Agent SDK v1.21.0). Pinned + released — never @next
# (homelab-cluster ADR-0047: an unattended factory does not run on a self-updating beta).
# renovate: datasource=pypi depName=openhands
ARG OPENHANDS_VERSION=1.16.0
# Gate toolchain pins (mise.toml / .forgejo CI in the erfbeeld repo).
# renovate: datasource=npm depName=@moonrepo/cli
ARG MOON_VERSION=2.4.4
# renovate: datasource=npm depName=@fission-ai/openspec
ARG OPENSPEC_VERSION=1.6.0
# renovate: datasource=pypi depName=pyyaml
ARG PYYAML_VERSION=6.0.3
# Skills loadout (Slice E / board #268). The core set is baked from the webgrip marketplace
# at BUILD time so a run needs no network for its core skills; per-ticket extras are cloned
# at runtime by the entrypoint when OPENHANDS_SKILLS_PROFILE is set. CI can override
# SKILLS_REPO with the in-cluster URL (http://forgejo-http.forgejo.svc.cluster.local:3000/...).
ARG SKILLS_REPO=https://forgejo.webgrip.dev/webgrip/webgrip-ai-skills.git
ARG SKILLS_REF=main
ARG SKILLS_CORE="guard-secrets adr-writer vikunja-product-owner skill-usage"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    OPENHANDS_SUPPRESS_BANNER=1 \
    # uv: link tool executables into a PATH dir, use the base image's CPython, no network
    # Python fetches, no build cache layer.
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_PYTHON_DOWNLOADS=never \
    UV_NO_CACHE=1 \
    # rust toolchain (copied below) lives under /usr/local; put cargo on PATH.
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:/usr/local/bin:/usr/bin:/bin

# System deps: git+ca-certificates (clone), curl (LiteLLM mint/health — Slice D), bash
# (entrypoint), build-essential+pkg-config (cargo compiles + links the core-rs gates).
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      git ca-certificates curl bash build-essential pkg-config \
 && rm -rf /var/lib/apt/lists/*

# --- OpenHands (Slice A) -----------------------------------------------------------------
COPY --from=uv /uv /uvx /usr/local/bin/
RUN uv tool install "openhands==${OPENHANDS_VERSION}" \
 && openhands --version

# --- Node 24 (Slice B) -------------------------------------------------------------------
# Copy the node runtime + npm, then recreate the npm/npx shims the official image symlinks.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node --version && npm --version

# --- Rust stable + wasm32 (Slice B) ------------------------------------------------------
# Copy the toolchain from the pinned rust image (rust-ci-runner's pattern); add the wasm
# target the core build needs (ADR 0015).
COPY --from=rust /usr/local/cargo /usr/local/cargo
COPY --from=rust /usr/local/rustup /usr/local/rustup
# Symlink the toolchain proxies into /usr/local/bin so cargo/rustc/rustup resolve even in a
# login shell that resets PATH (CARGO_HOME/RUSTUP_HOME stay in ENV so the proxies still work).
RUN ln -sf /usr/local/cargo/bin/* /usr/local/bin/ \
 && rustup target add wasm32-unknown-unknown \
 && cargo --version && rustc --version

# --- moon + openspec (Slice B) -----------------------------------------------------------
RUN npm install -g "@moonrepo/cli@${MOON_VERSION}" "@fission-ai/openspec@${OPENSPEC_VERSION}" \
 && moon --version && openspec --version

# --- pyyaml for the domain scripts (Slice B) ---------------------------------------------
# Into the base CPython (matches CI's python:3.12 running scripts/*.py).
RUN pip install --no-cache-dir "pyyaml==${PYYAML_VERSION}" \
 && python3 -c "import yaml; print('pyyaml', yaml.__version__)"

# --- docker CLI (Slice C) ----------------------------------------------------------------
# Client + buildx/compose plugins from the pinned official image. The daemon is a privileged
# DinD sidecar in the k8s Job (mirrors forgejo-runner/app/scaledjob.yaml), reached at runtime
# via DOCKER_HOST — this image ships no daemon. OpenHands starts its sandbox against it.
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
RUN docker --version

# --- baked core skills (Slice E) ---------------------------------------------------------
# OpenHands discovers skills by DIRECTORY: anything under $HOME/.openhands/skills/installed
# is self-registered (its metadata file is self-healing — "add entries for extension
# directories that were manually copied in"). So delivery is a plain copy, no install API.
# We stage the core at /opt/webgrip/skills; the entrypoint copies it into the run's real
# $HOME (which varies: root locally, an emptyDir in-cluster).
RUN git clone --depth 1 --branch "${SKILLS_REF}" "${SKILLS_REPO}" /tmp/skills-src \
 && mkdir -p /opt/webgrip/skills \
 && for s in ${SKILLS_CORE}; do \
      if [ -d "/tmp/skills-src/skills/${s}" ]; then \
        cp -r "/tmp/skills-src/skills/${s}" /opt/webgrip/skills/; \
      else \
        echo "core skill '${s}' not found in the marketplace" >&2; exit 1; \
      fi; \
    done \
 && rm -rf /tmp/skills-src \
 && echo "baked core skills:" && ls -1 /opt/webgrip/skills

# Runtime defaults for the per-ticket loadout, mirroring what was baked.
ENV OPENHANDS_SKILLS_REPO=${SKILLS_REPO} \
    OPENHANDS_SKILLS_REF=${SKILLS_REF}

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /workspace

LABEL org.opencontainers.image.title="WebGrip OpenHands Runner" \
    org.opencontainers.image.description="Headless OpenHands agent runtime (SDK v1.21.0) with the erfbeeld gate toolchain (node 24, rust stable + wasm32, python 3.12 + pyyaml, moon, openspec) and a docker CLI for the DinD sandbox — runs 'openhands --headless' against the metered LiteLLM plane with a per-run x-litellm-trace-id" \
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

ENTRYPOINT ["docker-entrypoint.sh"]
