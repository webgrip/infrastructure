# Tauri CI job image: rust-ci-runner + the webkit2gtk/gtk3 headers a Tauri 2 shell
# compile-gate needs. Kept as a SEPARATE image on purpose — these are ~600 MB of GUI
# headers only the tauri gates want; baking them into the shared rust-ci-runner would
# bloat every Rust job (see erfbeeld's on_tauri_change.yml, which apt-installed these at
# run time for ~25 min/run before this image existed).
#
# First-party base: rust-ci-runner already bakes node (JS actions exec INSIDE job
# containers), git, the stable channel + wasm32 target, pkg-config and libssl-dev — so
# this layer is exactly the GUI toolkit delta.
ARG REGISTRY_WEBGRIP=harbor.webgrip.dev/webgrip
# renovate: datasource=docker depName=harbor.webgrip.dev/webgrip/rust-ci-runner
ARG RUST_CI_RUNNER_VERSION=1.3.0

FROM ${REGISTRY_WEBGRIP}/rust-ci-runner:${RUST_CI_RUNNER_VERSION}

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      libwebkit2gtk-4.1-dev \
      libgtk-3-dev \
 && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.title="WebGrip Tauri CI Runner" \
    org.opencontainers.image.description="Tauri CI job image: rust-ci-runner plus webkit2gtk/gtk3 dev headers for Tauri shell compile gates" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${REGISTRY_WEBGRIP}/rust-ci-runner:${RUST_CI_RUNNER_VERSION}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["bash"]
