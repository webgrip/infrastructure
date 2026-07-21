# syntax=docker/dockerfile:1
#
# Node CI job image for Forgejo Actions.
#
# node:24-alpine ships without git, and the moon task graph needs a vcs client to detect
# touched projects. Installing it at job time (`apk add git`) fails: runner pods have
# restricted egress and cannot reach dl-cdn.alpinelinux.org ("unable to select packages").
# So git — and the handful of tools the web/preview jobs shell out to — are baked here, at
# BUILD time (which has egress), not fetched per run.
ARG REGISTRY_DOCKERHUB=docker.io
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24-alpine

FROM ${NODE_IMAGE}

ARG NODE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

# git: moon's vcs client. bash/curl: job scripts. python3: the preview job's slug/build
# helpers. ca-certificates: HTTPS. All from apk at build time — never at job time.
RUN apk add --no-cache \
      git \
      bash \
      curl \
      python3 \
      ca-certificates \
 && git --version && node --version

LABEL org.opencontainers.image.title="WebGrip Node CI Runner" \
    org.opencontainers.image.description="Node CI job image with git and common tools baked (no runtime apk on egress-restricted runners)" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${NODE_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

CMD ["bash"]
