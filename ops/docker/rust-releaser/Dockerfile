###############################################################################
# Base image: Node 22 on Debian 12 (bookworm-slim)
###############################################################################
FROM node:22-bookworm-slim

###############################################################################
# Non-interactive APT
###############################################################################
ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
# Core build tooling + Docker CLI + QEMU (for cross-compilation images)
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
# Tell every subsequent layer that “home” is /github/home (same as GHA runner)
###############################################################################
ENV HOME=/github/home
RUN mkdir -p "$HOME"

###############################################################################
# Rust toolchain (stable, minimal profile) — installs into $HOME/.cargo
###############################################################################
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable

###############################################################################
# Add Cargo to PATH for all shells
###############################################################################
ENV PATH="$HOME/.cargo/bin:$PATH"

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
# Default entry
###############################################################################
ENTRYPOINT ["bash"]
