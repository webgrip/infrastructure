FROM ghcr.io/webgrip/techdocs-builder:latest AS techdocs

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

RUN apk add --no-cache \
    python3 \
    py3-pip

COPY --from=ghcr.io/webgrip/techdocs-builder:latest /usr/local /usr/local
COPY --from=ghcr.io/webgrip/techdocs-builder:latest /opt/plantuml.jar /opt/plantuml.jar
COPY --from=ghcr.io/webgrip/techdocs-builder:latest /usr/local/bin/plantuml /usr/local/bin/plantuml

COPY ./ops/docker/techdocs-runner/docker-entrypoint.sh ./docker-entrypoint.sh

LABEL org.opencontainers.image.title="WebGrip TechDocs Runner" \
    org.opencontainers.image.description="TechDocs runtime image for building and serving documentation" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="ghcr.io/webgrip/techdocs-builder:latest" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
