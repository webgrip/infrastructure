ARG REGISTRY_DOCKERHUB=docker.io
ARG REGISTRY_GHCR=ghcr.io

# All base-image refs are global ARGs (before any FROM) so their composed defaults resolve;
# the registry is a variable so CI can route through the Harbor pull-through proxy, and the
# literal tag+digest lets Renovate's dockerfile manager keep both current.
# uv is copied from its official image (reproducible; no `curl | sh`).
ARG UV_IMAGE=${REGISTRY_GHCR}/astral-sh/uv:0.9.2@sha256:6dbd7c42a9088083fa79e41431a579196a189bcee3ae68ba904ac2bf77765867
# OpenHands is a Python tool; base on the matching CPython slim image.
ARG BASE_IMAGE=${REGISTRY_DOCKERHUB}/library/python:3.12-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b

FROM ${UV_IMAGE} AS uv

FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

# OpenHands CLI (bundles the Software Agent SDK v1.21.0). Pinned + released — never @next
# (homelab-cluster ADR-0047: an unattended factory does not run on a self-updating beta).
# renovate: datasource=pypi depName=openhands
ARG OPENHANDS_VERSION=1.16.0

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    OPENHANDS_SUPPRESS_BANNER=1 \
    # uv: link tool executables into a PATH dir, use the base image's CPython, no network
    # Python fetches, no build cache layer.
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_PYTHON_DOWNLOADS=never \
    UV_NO_CACHE=1

# git + ca-certificates: clone the target repo. curl: LiteLLM key mint / health checks
# (Slice D). Bash: the entrypoint. Kept minimal — the gate toolchain (node/rust/…) is Slice B.
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      git ca-certificates curl bash \
 && rm -rf /var/lib/apt/lists/*

# uv/uvx from the pinned official image.
COPY --from=uv /uv /uvx /usr/local/bin/

# Install OpenHands as a uv tool; verify the binary resolves on PATH at build time.
RUN uv tool install "openhands==${OPENHANDS_VERSION}" \
 && openhands --version

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /workspace

LABEL org.opencontainers.image.title="WebGrip OpenHands Runner" \
    org.opencontainers.image.description="Headless OpenHands agent runtime (SDK v1.21.0) for the dark factory — runs 'openhands --headless' against the metered LiteLLM plane with a per-run x-litellm-trace-id" \
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

ENTRYPOINT ["docker-entrypoint.sh"]
