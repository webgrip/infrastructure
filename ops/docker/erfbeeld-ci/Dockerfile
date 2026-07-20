# syntax=docker/dockerfile:1
#
# Erfbeeld CI image — the job container for ryangr0/nuala-nalatenschap's Rust jobs.
#
# Design line: EVERYTHING THE JOB NEEDS IS BAKED. A job container must never apt-get or
# curl a toolchain at run time. Three reasons, all learned the hard way on 2026-07-20:
#
#   1. JS actions (checkout@v4, artifact actions) exec `node` INSIDE this container —
#      act_runner's own externals are host-mode only. A job image without node cannot
#      run a single JS action ("exec: \"node\": executable file not found").
#   2. `rust:latest` is a moving target; it drifted 1.97.0 -> 1.97.1 mid-debugging. CI
#      toolchains must be pinned or "works on my machine" becomes unfalsifiable.
#   3. Runtime installs put deb.nodesource.com and apt mirrors on the critical path of
#      every build, and cost minutes per job (tauri: 25 min, rust-core: 13 min).
#
# Pull cost matters here: runner pods use an emptyDir Docker root, so every job pulls
# this image fresh. Keep it lean, and pull it from Harbor (LAN) rather than Docker Hub.
ARG REGISTRY_DOCKERHUB=docker.io

# Pinned by index digest — Renovate bumps these deliberately, never silently.
ARG RUST_IMAGE=${REGISTRY_DOCKERHUB}/library/rust:1.97.1-slim-bookworm@sha256:99e09cb2284e2ddbb73a995deee3e91783fd04d177602ccf6eab326d778ee777
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d

FROM ${NODE_IMAGE} AS node

FROM ${RUST_IMAGE} AS final

# Re-declared: ARGs from before the first FROM are not in scope inside a build stage,
# so the base.name label below would otherwise expand to an empty string.
ARG RUST_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

# git/curl: checkout@v4 shells out to git; ca-certificates for HTTPS fetches.
# pkg-config + libssl-dev: the core crates' build scripts.
# libwebkit2gtk-4.1-dev + libgtk-3-dev: the Tauri shell's compile check — this apt
# install alone was the bulk of that job's 25-minute runtime.
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      pkg-config \
      libssl-dev \
      libwebkit2gtk-4.1-dev \
      libgtk-3-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Node from the official image rather than nodesource: same Debian base, so the glibc
# matches, and it is pinned by digest instead of trusting a setup script at build time.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node --version && npm --version

# The repo's packages/core-rs/rust-toolchain.toml requests channel = "stable" (ADR 0009,
# floating on purpose). The official rust image installs its version as a PINNED toolchain,
# not as the stable CHANNEL, so rustup re-downloaded ~200 MB on every single job. Baking
# the stable channel itself — with the components and target the workflow uses — makes that
# a no-op whenever the baked stable still matches upstream. When upstream moves, rustup
# syncs once and Renovate's next bump of RUST_IMAGE re-bakes it.
RUN rustup toolchain install stable --profile minimal --component rustfmt --component clippy \
 && rustup default stable \
 && rustup target add --toolchain stable wasm32-unknown-unknown \
 && cargo --version && rustc --version && rustup show active-toolchain

ENV CARGO_TERM_COLOR=always \
    CARGO_INCREMENTAL=0

LABEL org.opencontainers.image.title="Erfbeeld CI" \
    org.opencontainers.image.description="Job container for the Erfbeeld Rust CI jobs: pinned Rust + wasm32 target + node for JS actions + Tauri's webkit/gtk headers" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${RUST_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"
