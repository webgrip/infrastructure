###############################################################################
# Base image: Node 22 on Debian 12 (bookworm-slim)
###############################################################################
FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
# OS-level build tooling
###############################################################################
RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        ca-certificates \
        curl \
        git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# Rust toolchain (stable, minimal profile) + cargo-binstall
#
# GitHub Actions sets HOME to /github/home inside container jobs.  Installing
# toolchains under a deterministic prefix keeps them visible no matter what
# HOME points to.
###############################################################################
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN set -eux; \
    mkdir -p "$RUSTUP_HOME" "$CARGO_HOME"; \
    curl -sSf https://sh.rustup.rs \
      | sh -s -- -y --profile minimal --default-toolchain stable

# Fast installer for pre-built Rust binaries
RUN cargo install --locked cargo-binstall && \
    cargo binstall --no-confirm cargo-release git-cliff

###############################################################################
# semantic-release core + every plugin used in the action
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
