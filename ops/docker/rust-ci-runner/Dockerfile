ARG RUST_VERSION=1.87.0

FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION}-slim-bullseye AS build

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates pkg-config libssl-dev \
 && rm -rf /var/lib/apt/lists/*

RUN cargo install --locked cargo-binstall

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

RUN rustup toolchain install nightly \
 && rustup component add --toolchain nightly rustfmt clippy

RUN rustup default ${RUST_VERSION}


FROM debian:bullseye-slim AS final

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      ca-certificates libssl1.1 libgcc-s1 libzstd1 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/cargo/  /usr/local/cargo/
COPY --from=build /usr/local/rustup/ /usr/local/rustup/

ENV PATH="/usr/local/cargo/bin:${PATH}"

RUN rustup default stable

ENTRYPOINT ["bash"]