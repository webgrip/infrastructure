###############################################################################
# Base image: Node 22 on Debian 12 (bookworm-slim)
###############################################################################
ARG REGISTRY_DOCKERHUB=docker.io
# renovate: datasource=docker depName=docker.io/library/node versioning=docker
ARG NODE_VERSION=24
ARG DEBIAN_CODENAME=bookworm
FROM ${REGISTRY_DOCKERHUB}/library/node:${NODE_VERSION}-${DEBIAN_CODENAME}-slim

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG REGISTRY_DOCKERHUB
ARG NODE_VERSION
ARG DEBIAN_CODENAME
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

ARG RUST_TOOLCHAIN=stable
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain ${RUST_TOOLCHAIN}

###############################################################################
# Rust helpers
###############################################################################
ARG CARGO_RELEASE_VERSION=latest
ARG GIT_CLIFF_VERSION=latest
ARG CROSS_VERSION=latest
ARG WASM_BINDGEN_CLI_VERSION=latest
RUN cargo install --locked cargo-binstall && \
    ( [ "${CARGO_RELEASE_VERSION}" = "latest" ] && cargo binstall --no-confirm cargo-release || cargo binstall --no-confirm cargo-release@${CARGO_RELEASE_VERSION} ) && \
    ( [ "${GIT_CLIFF_VERSION}" = "latest" ] && cargo binstall --no-confirm git-cliff || cargo binstall --no-confirm git-cliff@${GIT_CLIFF_VERSION} ) && \
    ( [ "${CROSS_VERSION}" = "latest" ] && cargo install --locked cross || cargo install --locked cross@${CROSS_VERSION} ) && \
    ( [ "${WASM_BINDGEN_CLI_VERSION}" = "latest" ] && cargo install --locked wasm-bindgen-cli || cargo install --locked wasm-bindgen-cli@${WASM_BINDGEN_CLI_VERSION} ) && \
    rustup target add wasm32-unknown-unknown

###############################################################################
# semantic-release core + plugins
###############################################################################
ARG SEMREL_VERSION=latest
RUN if [ "${SEMREL_VERSION}" = "latest" ]; then \
            npm install -g \
                semantic-release \
                @semantic-release/changelog \
                @semantic-release/commit-analyzer \
                @semantic-release/exec \
                @semantic-release/git \
                @semantic-release/github \
                @semantic-release/release-notes-generator \
                semantic-release-cargo \
                semantic-release-github-actions-tags \
                semantic-release-helm3; \
        else \
            npm install -g \
                semantic-release@${SEMREL_VERSION} \
                @semantic-release/changelog \
                @semantic-release/commit-analyzer \
                @semantic-release/exec \
                @semantic-release/git \
                @semantic-release/github \
                @semantic-release/release-notes-generator \
                semantic-release-cargo \
                semantic-release-github-actions-tags \
                semantic-release-helm3; \
        fi

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
    org.opencontainers.image.base.name="${REGISTRY_DOCKERHUB}/library/node:${NODE_VERSION}-${DEBIAN_CODENAME}-slim" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["bash"]
