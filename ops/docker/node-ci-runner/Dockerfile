# syntax=docker/dockerfile:1
#
# Release re-entry: v1.0.1 shipped UNSIGNED — its Sign & Attest died on the security
# namespace's ingress default-deny dropping runner->openbao:8200 (run 294; fixed in
# homelab-cluster#550). Harbor's immutable tags make re-signing-by-rebuild impossible,
# so this cuts a signed successor; delete the unsigned 1.0.1 tag after it lands.
#
# Node CI job image for Forgejo Actions.
#
# node:24-alpine ships without git, and the moon task graph needs a vcs client to detect
# touched projects. Installing it at job time (`apk add git`) fails: runner pods have
# restricted egress and cannot reach dl-cdn.alpinelinux.org ("unable to select packages").
# So git — and the handful of tools the web/preview jobs shell out to — are baked here, at
# BUILD time (which has egress), not fetched per run.
# ADR-0006 Stage 2: Docker Hardened Images base, same node-24-on-alpine lineage. The -dev
# variant on purpose (apk installs below; moon jobs shell out at runtime) — the documented
# CI-image tradeoff. Runs as root like the stock image did (-dev variants are root; the
# shell-less runtime variants are the nonroot ones).
#
# BUILD PREREQUISITE: the `dhi` Harbor proxy project (homelab-cluster ADR-0023) — dhi.io refuses
# anonymous pulls, so unlike the other REGISTRY_* ARGs this one DEFAULTS to the proxy.
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
# renovate: datasource=docker depName=dhi.io/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DHI}/node:24.19.0-alpine3.23-dev@sha256:ae1719f70383dcb697ee8a5f1101c39927d42f746e3cfba72bba7529d2d96de7

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
    org.opencontainers.image.source="https://forgejo.webgrip.dev/webgrip/infrastructure" \
    org.opencontainers.image.url="https://forgejo.webgrip.dev/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://forgejo.webgrip.dev/webgrip/infrastructure/src/branch/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${NODE_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

# (Build re-triggered after the initial release run was cancelled by push concurrency.)
CMD ["bash"]
