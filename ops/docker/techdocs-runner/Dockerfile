ARG REGISTRY_GHCR=ghcr.io
ARG TECHDOCS_BUILDER=${REGISTRY_GHCR}/webgrip/techdocs-builder:1.2.7@sha256:ac891abd9e03fe3384b4d9d48f448f268aa7d8250ceb2a0c4a26029569df5632
FROM ${TECHDOCS_BUILDER} AS techdocs

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG TECHDOCS_BUILDER

RUN apk add --no-cache \
    python3 \
    py3-pip

COPY --from=techdocs /usr/local /usr/local
COPY --from=techdocs /opt/plantuml.jar /opt/plantuml.jar
COPY --from=techdocs /usr/local/bin/plantuml /usr/local/bin/plantuml

COPY ./ops/docker/techdocs-runner/docker-entrypoint.sh ./docker-entrypoint.sh

LABEL org.opencontainers.image.title="WebGrip TechDocs Runner" \
    org.opencontainers.image.description="TechDocs runtime image for building and serving documentation" \
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
