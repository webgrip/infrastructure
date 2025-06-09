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
      cargo-audit \
      cargo-deny \
      cargo-outdated \
      cargo-udeps \
      cargo-msrv \
      cargo-sort \
      cargo-nextest \
      cargo-tarpaulin

# ----------------------------------------------------------------------
# 4. optional nightly + components
# ----------------------------------------------------------------------
RUN rustup toolchain install nightly -y \
 && rustup component add rustfmt clippy --toolchain nightly

# ----------------------------------------------------------------------
# 6. final stage (tiny runtime image with the tools in /usr/local/bin)
# ----------------------------------------------------------------------
FROM debian:bullseye-slim AS final
COPY --from=base /root/.cargo/bin/ /usr/local/bin/
ENTRYPOINT ["bash"]