ARG REGISTRY_DOCKERHUB=docker.io
ARG RUST_VERSION=1.87.0

# ────────────────────────────────────────────────────────────────
# 1️⃣ Build stage – Rust toolchains & CLI helpers
# ────────────────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM ${REGISTRY_DOCKERHUB}/library/rust:${RUST_VERSION}-slim-bookworm AS build

# 1.1 System packages needed to *build* helper crates
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates pkg-config libssl-dev build-essential \
 && rm -rf /var/lib/apt/lists/*

# 1.2 Fast binary installer for Rust CLI tools
RUN cargo install --locked cargo-binstall

# 1.3 Grab the Rust CLI helpers
#     – everything **except** cargo-sort (see 1.4)
RUN set -eux; \
    cargo binstall --no-confirm \
      cargo-audit \
      cargo-deny \
      cargo-outdated \
      cargo-udeps \
      cargo-msrv \
      cargo-nextest \
      cargo-tarpaulin

# 1.4 cargo-sort: build **from source** so it targets Bookworm’s glibc 2.37
RUN cargo install --locked cargo-sort

# 1.5 Optional nightly tool-chain + components
RUN rustup toolchain install nightly \
 && rustup component add --toolchain nightly rustfmt clippy

# 1.6 Pin stable as default & add clippy/rustfmt to it
RUN rustup default ${RUST_VERSION} \
 && rustup component add clippy rustfmt

# ────────────────────────────────────────────────────────────────
# 2️⃣ Runtime / CI stage – tiny Debian image
# ────────────────────────────────────────────────────────────────
ARG DEBIAN_BASE=${REGISTRY_DOCKERHUB}/library/debian:bookworm-slim@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb
FROM ${DEBIAN_BASE} AS final

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

# 2.1 Runtime **and** build tools (gcc, make, pkg-config, OpenSSL headers)
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      build-essential \
      pkg-config \
      libssl-dev \
      libssl3 libgcc-s1 libzstd1 \
 && rm -rf /var/lib/apt/lists/*

# 2.2 Copy Cargo bin dir + Rustup tool-chains from build stage
COPY --from=build /usr/local/cargo/  /usr/local/cargo/
COPY --from=build /usr/local/rustup/ /usr/local/rustup/

# 2.3 Environment so rustup shims resolve correctly
ENV \
  CARGO_HOME=/usr/local/cargo \
  RUSTUP_HOME=/usr/local/rustup \
  PATH="/usr/local/cargo/bin:${PATH}"

LABEL org.opencontainers.image.title="WebGrip Rust CI Runner" \
    org.opencontainers.image.description="Rust CI runner with auditing and testing tools" \
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
