# Release re-entry touch: attempt 4 — run 135 died to daemon overload, run 145 to the
# push-main concurrency cancel, run 153 to config 1.1.0's unbundled monorepo peer.
# Merge while main is quiet; the verify build needs ~40 min.
###############################################################################
# Base image: Node 22 on Debian 12 (bookworm-slim)
###############################################################################
ARG REGISTRY_DOCKERHUB=docker.io
# One ARG carrying tag AND digest (house pattern): Renovate moves them together via the
# digest-aware annotated-ARG manager.
# renovate: datasource=docker depName=docker.io/library/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24-bookworm-slim@sha256:3638d9a6fe4030bd716be989438248074489337ba3275657f93595428be4fc03
FROM ${NODE_IMAGE}

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG REGISTRY_DOCKERHUB
ARG NODE_IMAGE
ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
# Core build tooling, Docker CLI, QEMU (for cross-compilation)
###############################################################################
RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        ca-certificates \
        curl \
        git \
        docker.io \
        qemu-user-static \
        binfmt-support \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# Rust toolchain (stable, minimal)  ➜  lives in /usr/local/cargo
###############################################################################
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

# 'stable' resolves to whatever rust-lang shipped most recently — the toolchain that compiles
# release artifacts was unversioned. Pinned to the same version rust-ci-runner builds with.
# renovate: datasource=docker depName=docker.io/library/rust versioning=docker
ARG RUST_TOOLCHAIN=1.97.0
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain ${RUST_TOOLCHAIN}

###############################################################################
# Rust helpers
###############################################################################
# All four were 'latest': the image contents were decided by whenever the build ran, not by this
# file, and the latest/else branching meant the pinned path was never actually exercised. Pinned
# at what 'latest' resolved to on 2026-08-08; Renovate moves each independently.
# renovate: datasource=crate depName=cargo-release
ARG CARGO_RELEASE_VERSION=1.1.4
# renovate: datasource=crate depName=git-cliff
ARG GIT_CLIFF_VERSION=2.13.1
# renovate: datasource=crate depName=cross
ARG CROSS_VERSION=0.2.5
# renovate: datasource=crate depName=wasm-bindgen-cli
ARG WASM_BINDGEN_CLI_VERSION=0.2.127
RUN cargo install --locked cargo-binstall && \
    cargo binstall --no-confirm cargo-release@${CARGO_RELEASE_VERSION} && \
    cargo binstall --no-confirm git-cliff@${GIT_CLIFF_VERSION} && \
    cargo install --locked cross@${CROSS_VERSION} && \
    cargo install --locked wasm-bindgen-cli@${WASM_BINDGEN_CLI_VERSION} && \
    rustup target add wasm32-unknown-unknown

###############################################################################
# semantic-release core + plugins
###############################################################################
# Core pinned; the plugins still float at install time. The honest fix for the whole set is a
# committed package-lock.json like the semantic-release images carry (webgrip/workflows ADR-0005)
# — this image predates that pattern and should eventually adopt it. Until then, pinning the core
# at least fixes the resolver every plugin's peer range is evaluated against.
# renovate: datasource=npm depName=semantic-release
ARG SEMREL_VERSION=25.0.9
RUN npm install -g \
        semantic-release@${SEMREL_VERSION} \
        @semantic-release/changelog \
        @semantic-release/commit-analyzer \
        @semantic-release/exec \
        @semantic-release/git \
        @semantic-release/github \
        @semantic-release/release-notes-generator \
        semantic-release-cargo \
        semantic-release-github-actions-tags \
        semantic-release-helm3

###############################################################################
# Default entry
###############################################################################

RUN mkdir -p /root/.cargo/bin && \
    ln -sf /usr/local/cargo/bin/{cargo,rustc,rustup} /root/.cargo/bin/

LABEL org.opencontainers.image.title="WebGrip Rust Releaser" \
    org.opencontainers.image.description="Rust + Node release automation toolchain" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${NODE_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["bash"]
