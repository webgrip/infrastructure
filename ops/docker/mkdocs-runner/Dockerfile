ARG REGISTRY_GHCR=ghcr.io
ARG TECHDOCS_BUILDER=${REGISTRY_GHCR}/webgrip/techdocs-builder:1.2.7@sha256:ac891abd9e03fe3384b4d9d48f448f268aa7d8250ceb2a0c4a26029569df5632
FROM ${TECHDOCS_BUILDER} AS mkdocs

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG TECHDOCS_BUILDER

COPY ./ops/docker/mkdocs-runner/docker-entrypoint.sh ./docker-entrypoint.sh

LABEL org.opencontainers.image.title="WebGrip MkDocs Runner" \
    org.opencontainers.image.description="MkDocs runner image for serving TechDocs locally" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${TECHDOCS_BUILDER}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
