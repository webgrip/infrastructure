###############################################################################
# semantic-release toolchain + cargo, for Rust crate release trains
# (webgrip/workflows' rust-semantic-release composite).
#
# FROM the base toolchain image: node, git, yq, the SEMREL_PREBAKED contract and the OCI metadata
# are inherited. This adds a minimal Rust toolchain and semantic-release-cargo.
#
# NOT rust-releaser: that image is the heavy cross-compilation environment (cross, wasm-bindgen,
# QEMU, docker CLI) whose semantic-release install is `npm install -g … latest` — unpinned, which
# is the problem this family exists to remove. This is the release toolchain for a Rust crate, not
# a build farm. Nothing stops a repo needing both from building FROM rust-releaser and copying
# /opt/semrel out of here.
#
# cargo-release and git-cliff are deliberately absent: semantic-release-cargo performs the version
# bump and publish, semantic-release itself writes the changelog, and neither tool has a prebuilt
# arm64 artifact on binstall's path — including them turns a one-minute image build into a
# from-source cargo compile. Add them here, not to a job, if a consumer actually needs them.
###############################################################################
ARG REGISTRY_DOCKERHUB=docker.io
ARG REGISTRY_WEBGRIP=harbor.webgrip.dev/webgrip
# The base image's own release train cut 0.1.0 first (a fresh dir starts from a seeded 0.0.0, so a
# feat lands as 0.1.0 — not 1.0.0). Renovate watches this; bump it deliberately after a base release.
# renovate: datasource=docker depName=harbor.webgrip.dev/webgrip/semantic-release
ARG SEMANTIC_RELEASE_VERSION=0.1.0
# renovate: datasource=docker depName=docker.io/library/node versioning=docker
ARG NODE_VERSION=24
ARG DEBIAN_CODENAME=bookworm

###############################################################################
# Locked toolchain (same node as the base image builds its own with)
###############################################################################
FROM ${REGISTRY_DOCKERHUB}/library/node:${NODE_VERSION}-${DEBIAN_CODENAME}-slim AS deps
WORKDIR /opt/semrel
COPY toolchain/.npmrc /tmp/npmrc
COPY toolchain/package.json toolchain/package-lock.json ./
RUN NPM_CONFIG_USERCONFIG=/tmp/npmrc npm ci --omit=dev --no-audit --no-fund

###############################################################################
FROM ${REGISTRY_WEBGRIP}/semantic-release:${SEMANTIC_RELEASE_VERSION}

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG REGISTRY_WEBGRIP
ARG SEMANTIC_RELEASE_VERSION
ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
# Rust toolchain (stable, minimal) ➜ lives in /usr/local/cargo, as in rust-releaser
###############################################################################
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

ARG RUST_TOOLCHAIN=stable
RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain ${RUST_TOOLCHAIN} && \
    chmod -R a+w "${CARGO_HOME}" "${RUSTUP_HOME}" && \
    cargo --version

RUN rm -rf /opt/semrel/node_modules
COPY --from=deps /opt/semrel/node_modules /opt/semrel/node_modules

RUN cd /tmp \
 && node -e "const v=require('semantic-release/package.json').version; if(v.split('.')[0]!=='25') throw new Error('expected semantic-release 25.x, got '+v); console.log('semantic-release '+v)" \
 && node -e "require.resolve('@webgrip/semantic-release-config')" \
 && node -e "require.resolve('semantic-release-cargo')"

LABEL org.opencontainers.image.title="WebGrip semantic-release Toolchain (Rust)" \
    org.opencontainers.image.description="Locked semantic-release 25 toolchain + cargo and semantic-release-cargo" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${REGISTRY_WEBGRIP}/semantic-release:${SEMANTIC_RELEASE_VERSION}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["bash"]
