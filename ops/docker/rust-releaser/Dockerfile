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
###############################################################################
RUN curl -sSf https://sh.rustup.rs | bash -s -- -y --profile minimal --default-toolchain stable && \
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /etc/profile.d/cargo.sh
ENV PATH="/root/.cargo/bin:${PATH}"

# Fast installer for pre-built Rust binaries
RUN cargo install --locked cargo-binstall

# Bring in the Rust CLIs required by the composite action
RUN cargo binstall --no-confirm cargo-release git-cliff

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
WORKDIR /workspace

ENTRYPOINT ["bash"]