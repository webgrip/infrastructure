FROM rust:1.87.0-slim-bullseye

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    cargo install --locked cargo-audit \
    && cargo install --locked cargo-deny \
    && cargo install --locked cargo-outdated \
    && cargo install --locked cargo-udeps \
    && cargo install --locked cargo-msrv \
    && cargo install --locked cargo-sort \
    && rustup toolchain install nightly \
    && rustup component add rustfmt clippy

CMD ["bash"]
