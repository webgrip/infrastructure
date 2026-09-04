# syntax=docker/dockerfile:1
#
# Static-site CI job image for Forgejo Actions — the toolchain behind
# webgrip/workflows' lighthouse-budgets, axe-scan and link-check-static-site lanes.
#
# Born from twente.dev run 98's warning sweep: the lanes npx-installed @lhci/cli at
# job time, which dragged its legacy tree (glob@7, inflight, rimraf@2, uuid@8)
# through npm's deprecation warnings on every single run — noise nobody can act on,
# produced by an install ADR-0005 says should not exist. The toolchain is an image,
# not an install: lhci comes from the committed lockfile here, lychee is a pinned
# release binary, and job containers execute — they resolve nothing.
#
# Chrome comes from the cypress/browsers base — the exact image the lanes already
# ran on, now pinned by tag AND digest (house pattern) instead of :latest.
ARG REGISTRY_DOCKER=docker.io
# renovate: datasource=docker depName=cypress/browsers versioning=loose
ARG BASE_IMAGE=${REGISTRY_DOCKER}/cypress/browsers:node-24.20.0-chrome-152.0.7977.64-1-ff-155.0-edge-152.0.4191.53-1@sha256:4e487953a62c66c9b0ba84e07ecc84089612e213718b2a76c13c98ca66f97bae
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG TZ=Europe/Amsterdam
ENV TZ=${TZ}

# renovate: datasource=github-releases depName=lycheeverse/lychee
ARG LYCHEE_VERSION=lychee-v0.24.2

# dnsutils: the link-check lane's multi-resolver dig sweep. curl: absent from the
# cypress base (the lanes always curled from the runner, never the container) and
# needed here and by future job scripts. Baked at BUILD time — runner pods have
# restricted egress, and apt-get at job time is the exact failure the
# node-ci-runner image already documented.
RUN apt-get update \
 && apt-get install -y --no-install-recommends dnsutils curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && curl -sSfL "https://github.com/lycheeverse/lychee/releases/download/${LYCHEE_VERSION}/lychee-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin lychee-x86_64-unknown-linux-gnu/lychee \
 && lychee --version

# The checkout's `git init` prints a hint asking for init.defaultBranch on every job.
# That hint is a configuration request — so configure it, estate default: main.
RUN git config --system init.defaultBranch main

# @lhci/cli from the committed lockfile (npm ci), installed once at build time —
# where the deprecation warnings of ITS transitive tree belong: visible in this
# image's build log, absent from every consumer's CI run.
COPY package.json package-lock.json /opt/lhci/
RUN cd /opt/lhci \
 && npm ci --omit=dev --no-audit --no-fund \
 && ln -s /opt/lhci/node_modules/.bin/lhci /usr/local/bin/lhci \
 && lhci --version

LABEL org.opencontainers.image.title="WebGrip Static Site CI Runner" \
    org.opencontainers.image.description="Chrome + lhci + lychee + dnsutils for the static-site CI lanes (no runtime installs on egress-restricted runners)" \
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

CMD ["bash"]
