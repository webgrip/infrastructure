###############################################################################
# Base image: Node 22 on Debian 12 (bookworm-slim)
###############################################################################
FROM node:22-bookworm-slim

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

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable

###############################################################################
# Rust helpers
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
# Default entry
###############################################################################

RUN mkdir -p /root/.cargo/bin && \
    ln -sf /usr/local/cargo/bin/{cargo,rustc,rustup} /root/.cargo/bin/

ENTRYPOINT ["bash"]
