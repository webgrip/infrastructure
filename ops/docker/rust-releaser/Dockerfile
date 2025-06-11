###############################################################################
# Base image: Node 22 on Debian 12 (bookworm-slim)
###############################################################################
FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
# OS-level build tooling + Docker CLI + QEMU for cross-compilation
###############################################################################
RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        ca-certificates \
        curl \
        git \
        docker.io \               # for `cross` — uses host Docker daemon
        qemu-user-static \        # foreign-arch emulation inside target images
        binfmt-support \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# Rust toolchain (stable, minimal profile)
###############################################################################
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN set -eux; \
    mkdir -p "$RUSTUP_HOME" "$CARGO_HOME"; \
    curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable

###############################################################################
# Rust helpers
###############################################################################
#  - cargo-binstall      -> lightning-fast pre-built binaries
#  - cross               -> painless cross-compiles via Docker images
#  - wasm-bindgen-cli    -> produce browser-friendly .wasm
#  - cargo-release & git-cliff (already used in your repo)
###############################################################################
RUN cargo install --locked cargo-binstall && \
    cargo binstall --no-confirm cargo-release git-cliff && \
    cargo install --locked cross wasm-bindgen-cli && \
    rustup target add wasm32-unknown-unknown

###############################################################################
# semantic-release core + plugins
###############################################################################
RUN npm install -g \
      semantic-release \
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
# Image defaults
###############################################################################
ENTRYPOINT ["bash"]
