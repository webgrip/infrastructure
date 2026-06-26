ARG REGISTRY_DOCKERHUB=docker.io
ARG BASE_IMAGE=${REGISTRY_DOCKERHUB}/library/alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

RUN apk add --no-cache docker git bash curl

ARG ACT_VERSION=latest

RUN if [ "$ACT_VERSION" = "latest" ]; then \
        curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin; \
    else \
        curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin -- -d v${ACT_VERSION}; \
    fi

WORKDIR /workspace

LABEL org.opencontainers.image.title="WebGrip ACT Runner" \
    org.opencontainers.image.description="Container with nektos/act for local GitHub Actions simulation" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${BASE_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["act"]
