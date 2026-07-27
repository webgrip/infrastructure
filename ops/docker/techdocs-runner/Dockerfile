# First-party base straight from the Harbor webgrip project (same pattern as tauri-ci-runner):
# the old ${REGISTRY_GHCR} route stopped receiving new techdocs-builder versions when the GHCR
# mirror was disabled, freezing this base at 1.2.7 while Harbor moved on.
ARG REGISTRY_WEBGRIP=harbor.webgrip.dev/webgrip
# renovate: datasource=docker depName=harbor.webgrip.dev/webgrip/techdocs-builder
ARG TECHDOCS_BUILDER_VERSION=1.2.21
FROM ${REGISTRY_WEBGRIP}/techdocs-builder:${TECHDOCS_BUILDER_VERSION} AS techdocs

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG REGISTRY_WEBGRIP
ARG TECHDOCS_BUILDER_VERSION

RUN apk add --no-cache \
    python3 \
    py3-pip

# Build context is this directory (CI passes docker-context: ops/docker/<image>; docker-compose
# and the verifyRelease gate build from here too) — paths must be context-relative.
COPY docker-entrypoint.sh ./docker-entrypoint.sh

LABEL org.opencontainers.image.title="WebGrip TechDocs Runner" \
    org.opencontainers.image.description="TechDocs runtime image for building and serving documentation" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${REGISTRY_WEBGRIP}/techdocs-builder:${TECHDOCS_BUILDER_VERSION}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
