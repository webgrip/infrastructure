# ADR-0006 Stage 2: Docker Hardened Images base. The -dev variant on purpose — this image
# installs packages (docker, git, bash, curl) and act itself needs a shell and the docker CLI at
# runtime, so the shell-less runtime variant cannot carry it. Same Alpine lineage as before;
# apk behaves identically. The dev-variant tradeoff is the one ADR-0006 documents for CI images:
# less of the theoretical benefit than a production service would capture, in exchange for a
# continuously-rebuilt, advisory-tracked, signed base.
#
# BUILD PREREQUISITE: the `dhi` Harbor proxy project (homelab-cluster ADR-0023) — dhi.io refuses
# anonymous pulls, so unlike the other REGISTRY_* ARGs this one DEFAULTS to the proxy.
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
# renovate: datasource=docker depName=dhi.io/alpine-base versioning=docker
ARG BASE_IMAGE=${REGISTRY_DHI}/alpine-base:3.23-dev@sha256:a5d8ac99e233c9141bbefb2afa1809923f420aeeeb11e9dbb463d0bddb943327
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

RUN apk add --no-cache docker git bash curl

# Version-pinned, checksum-verified release download — not `curl | bash` of an installer that
# resolves 'latest' at build time. 'latest' meant the image contents were decided by whenever the
# build happened to run, not by this file; and piping an unverified script into bash trusts both
# the CDN and the repo's master branch at whatever commit is HEAD that day. Same house pattern as
# ci-runner's helm/yq (#88): fetch the release artifact, verify the published checksum, install.
# renovate: datasource=github-releases depName=nektos/act
ARG ACT_VERSION=0.2.89
ARG ACT_SHA256=0191d6f1f3b716b5c55820032605d05fc3c1cdbf581ebeff655019e5dd1524c0

RUN set -eux; \
    curl -fsSL -o /tmp/act.tar.gz \
      "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/act_Linux_x86_64.tar.gz"; \
    echo "${ACT_SHA256}  /tmp/act.tar.gz" | sha256sum -c -; \
    tar -C /usr/local/bin -xzf /tmp/act.tar.gz act; \
    rm /tmp/act.tar.gz; \
    act --version

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
