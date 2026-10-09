ARG REGISTRY_DOCKERHUB=docker.io
# renovate: datasource=docker depName=docker.io/library/rust versioning=docker
ARG RUST_VERSION=1.97.0
# Same image as ${RUST_VERSION}-slim-bookworm, pinned by digest. Two ARGs because RUST_VERSION is
# also a rustup toolchain name (`rustup default ${RUST_VERSION}`), where a digest suffix would
# corrupt it. Both carry the same Renovate depName, so they move in the same PR — the digest ARG's
# tag must track RUST_VERSION.
# renovate: datasource=docker depName=docker.io/library/rust versioning=docker
ARG RUST_IMAGE=${REGISTRY_DOCKERHUB}/library/rust:1.97.0-slim-bookworm@sha256:6d220bf85c74e842a79da63997af8d2e74455c0b8847d8bb3a5888572334991d
# Node is not a Rust tool, but every Forgejo Actions JS action (checkout@v4, the artifact
# actions) is exec'd INSIDE the job container — act_runner's own externals are host-mode
# only. A Rust CI image without node cannot run a single JS action, which is why glibc
# job containers failed with 'exec: "node": executable file not found' while alpine ones
# passed. Pinned by digest; the same digest resolves through the Harbor pull-through proxy.
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d
ARG DEBIAN_BASE=${REGISTRY_DOCKERHUB}/library/debian:bookworm-slim@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb

# ────────────────────────────────────────────────────────────────
# 1️⃣ Build stage – Rust toolchains & CLI helpers
# ────────────────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM ${RUST_IMAGE} AS build

# Without this redeclaration, step 1.6's `rustup default ${RUST_VERSION}` expanded to a bare
# `rustup default` — which PRINTS the default rather than setting it. It looked green because the
# base image's default toolchain happens to be the same version; the pin itself never operated.
ARG RUST_VERSION

# 1.1 System packages needed to *build* helper crates
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates pkg-config libssl-dev build-essential \
 && rm -rf /var/lib/apt/lists/*

# 1.2 Fast binary installer for Rust CLI tools
RUN cargo install --locked cargo-binstall

# 1.3 Grab the Rust CLI helpers
#     – everything **except** cargo-sort (see 1.4)
#     sccache: shared compilation cache for CI; enabled per-workflow via RUSTC_WRAPPER.
RUN set -eux; \
    cargo binstall --no-confirm \
      cargo-audit \
      cargo-deny \
      cargo-outdated \
      cargo-udeps \
      cargo-msrv \
      cargo-nextest \
      cargo-tarpaulin \
      sccache

# 1.4 cargo-sort: build **from source** so it targets Bookworm’s glibc 2.37
RUN cargo install --locked cargo-sort

# 1.5 Optional nightly tool-chain + components
RUN rustup toolchain install nightly \
 && rustup component add --toolchain nightly rustfmt clippy

# 1.6 Pin stable as default & add clippy/rustfmt to it
RUN rustup default ${RUST_VERSION} \
 && rustup component add clippy rustfmt

# 1.7 The `stable` CHANNEL itself, plus the wasm target.
#     The official rust image installs its version as a PINNED toolchain, not as the stable
#     channel. A repo whose rust-toolchain.toml says `channel = "stable"` (a common, and in
#     Erfbeeld's case deliberate, choice — ADR 0009) therefore makes rustup download the
#     whole channel (~200 MB) on EVERY job. Baking it makes that a no-op while the baked
#     stable matches upstream, and a single sync when it does not.
#     wasm32-unknown-unknown: any Rust core compiled to WASM builds with no network.
RUN rustup toolchain install stable --profile minimal --component rustfmt --component clippy \
 && rustup target add --toolchain stable wasm32-unknown-unknown

# ────────────────────────────────────────────────────────────────
# 2️⃣ Runtime / CI stage – tiny Debian image
# ────────────────────────────────────────────────────────────────
FROM ${NODE_IMAGE} AS node

FROM ${DEBIAN_BASE} AS final

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

# 2.1 Runtime **and** build tools (gcc, make, pkg-config, OpenSSL headers).
#     git + curl are not optional for a CI image: checkout@v4 shells out to git, and
#     without it the very first step of every workflow fails.
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      build-essential \
      pkg-config \
      libssl-dev \
      libssl3 libgcc-s1 libzstd1 \
      git \
      curl \
 && rm -rf /var/lib/apt/lists/*

# 2.2 Copy Cargo bin dir + Rustup tool-chains from build stage
COPY --from=build /usr/local/cargo/  /usr/local/cargo/
COPY --from=build /usr/local/rustup/ /usr/local/rustup/

# 2.3 Node for JS actions (see NODE_IMAGE above). Taken from the official image rather
#     than nodesource so it is digest-pinned and its glibc matches this Debian base.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# 2.4 Environment so rustup shims resolve correctly
ENV \
  CARGO_HOME=/usr/local/cargo \
  RUSTUP_HOME=/usr/local/rustup \
  PATH="/usr/local/cargo/bin:${PATH}"

LABEL org.opencontainers.image.title="WebGrip Rust CI Runner" \
    org.opencontainers.image.description="Rust CI job image: toolchains (stable channel + wasm32), audit/test tooling, git, and node for Forgejo Actions JS actions" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${DEBIAN_BASE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["bash"]
