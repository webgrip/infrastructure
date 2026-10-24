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
# renovate: datasource=docker depName=docker.io/library/rust versioning=docker
ARG RUST_IMAGE=${REGISTRY_DOCKERHUB}/library/rust:1.97.0-slim-bookworm@sha256:6d220bf85c74e842a79da63997af8d2e74455c0b8847d8bb3a5888572334991d
FROM ${RUST_IMAGE} AS rust

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

COPY --from=rust /usr/local/rustup /usr/local/rustup
COPY --from=rust /usr/local/cargo /usr/local/cargo
RUN rustup --version && rustc --version && cargo --version

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
# renovate: datasource=crate depName=cargo-binstall
ARG CARGO_BINSTALL_VERSION=1.26.0
RUN cargo install --locked cargo-binstall@${CARGO_BINSTALL_VERSION} && \
    cargo binstall --no-confirm cargo-release@${CARGO_RELEASE_VERSION} && \
    cargo binstall --no-confirm git-cliff@${GIT_CLIFF_VERSION} && \
    cargo install --locked cross@${CROSS_VERSION} && \
    cargo install --locked wasm-bindgen-cli@${WASM_BINDGEN_CLI_VERSION} && \
    rustup target add wasm32-unknown-unknown

###############################################################################
# semantic-release core + plugins
###############################################################################
COPY tools/semantic-release/package.json tools/semantic-release/package-lock.json /opt/semantic-release/
RUN npm ci --prefix /opt/semantic-release --omit=dev --no-audit --no-fund \
 && npm cache clean --force \
 && ln -s /opt/semantic-release/node_modules/.bin/semantic-release /usr/local/bin/semantic-release \
 && semantic-release --version

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
