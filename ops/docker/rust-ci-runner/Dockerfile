ARG RUST_VERSION=1.87.0

# ────────────────────────────────────────────────────────────────────────────────
# 1️⃣  Build stage – Rust toolchains & CLI helpers
# ────────────────────────────────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION}-slim-bookworm AS build

# 1.1  System deps needed while we *build* helper binaries
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates pkg-config libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# 1.2  Fast binary installer for Rust CLI tools
RUN cargo install --locked cargo-binstall

# 1.3  Grab the Rust CLI helpers (falls back to `cargo install` if no binary)
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

# 1.4  Optional nightly toolchain + components
RUN rustup toolchain install nightly \
 && rustup component add --toolchain nightly rustfmt clippy

# 1.5  Pin stable as the default so the rustup shim can resolve `cargo`
RUN rustup default ${RUST_VERSION}


# ────────────────────────────────────────────────────────────────────────────────
# 2️⃣  Runtime stage – tiny Debian image with the tools & toolchains
# ────────────────────────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS final

# 2.1  Runtime libs many Rust binaries expect (bullseye ships OpenSSL 1.1)
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      ca-certificates libssl3 libgcc-s1 libzstd1 \
 && rm -rf /var/lib/apt/lists/*

# 2.2  Copy BOTH the Cargo bin dir *and* the Rustup toolchains from build stage
COPY --from=build /usr/local/cargo/  /usr/local/cargo/
COPY --from=build /usr/local/rustup/ /usr/local/rustup/

# 2.3  Make the Rust shims see their homes (matches the official rust image)
ENV \
  CARGO_HOME=/usr/local/cargo \
  RUSTUP_HOME=/usr/local/rustup \
  PATH="/usr/local/cargo/bin:${PATH}"

ENTRYPOINT ["bash"]