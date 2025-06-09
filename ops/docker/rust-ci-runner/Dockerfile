# syntax=docker/dockerfile:1.7
ARG RUST_VERSION=1.87.0
FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION}-slim-bullseye AS base

# ----------------------------------------------------------------------
# 1. system deps
# ----------------------------------------------------------------------
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates pkg-config libssl-dev \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="${PATH}:${HOME}/.cargo/bin"

# ----------------------------------------------------------------------
# 2. install cargo-binstall once
# ----------------------------------------------------------------------
RUN cargo install --locked cargo-binstall

# ----------------------------------------------------------------------
# 3. grab all the Rust CLI tools
#    anything that *doesn't* ship binaries still falls back to cargo install,
#    but that’s only a handful of tiny crates so the build stays fast.
# ----------------------------------------------------------------------
RUN set -eux; \
    cargo binstall --no-confirm \
      cargo-audit@latest \
      cargo-deny@latest \
      cargo-outdated@latest \
      cargo-udeps@latest \
      cargo-msrv@latest \
      cargo-sort@latest

# ----------------------------------------------------------------------
# 4. grab nextest + tarpaulin from GitHub Releases
#    (cargo-binstall could do this too; a manual curl keeps the image minimal)
# ----------------------------------------------------------------------
ARG TARGETARCH
RUN set -eux; \
    case "$TARGETARCH" in \
        amd64)   PLATFORM="x86_64-unknown-linux-gnu" ;; \
        arm64)   PLATFORM="aarch64-unknown-linux-gnu" ;; \
        *)       echo "unsupported arch $TARGETARCH" && exit 1 ;; \
    esac; \
    curl -LsSf "https://get.nexte.st/latest/${PLATFORM}" \
      | tar xz -C "${HOME}/.cargo/bin"; \
    curl -LsSf \
      "https://github.com/xd009642/tarpaulin/releases/latest/download/cargo-tarpaulin-${PLATFORM}.tar.gz" \
      | tar xz --strip-components=1 -C "${HOME}/.cargo/bin";

# ----------------------------------------------------------------------
# 5. optional nightly + components
# ----------------------------------------------------------------------
RUN rustup toolchain install nightly -y \
 && rustup component add rustfmt clippy --toolchain nightly

# ----------------------------------------------------------------------
# 6. final stage (tiny runtime image with the tools in /usr/local/bin)
# ----------------------------------------------------------------------
FROM debian:bullseye-slim AS final
COPY --from=base /root/.cargo/bin/ /usr/local/bin/
ENTRYPOINT ["bash"]