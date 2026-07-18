# CI toolchain for webgrip/ai-skills (Claude Code skills/plugin marketplace).
# Bakes the exact run-time toolchain those workflows used to install per job — node 24,
# system python3 + PyYAML, git, and Anthropic's Claude Code CLI — so the ephemeral in-cluster
# runner pulls one warm image (LAN, via the Harbor ghcr proxy) instead of pulling node:24-trixie
# fresh from Docker Hub (~4 min) and then running apt-get + `npm install -g` on every job.
#
# node:24-trixie (full Debian 13) is deliberate, matching the ai-skills workflow's original base:
# it ships system python3 3.13 so PyYAML installs from apt with no PEP 668 pip friction.
ARG REGISTRY_DOCKERHUB=docker.io
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24-trixie@sha256:eb2c73a27cf714b4b6b030f88ab72e62192c38b7d313ea3456695b8ae03c5f3c

FROM ${NODE_IMAGE}

ARG NODE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

ENV DEBIAN_FRONTEND=noninteractive

# python3 (3.13 on trixie) is already present in the full node image; python3-yaml (PyYAML) is not —
# it is what the ai-skills plugin test suites (domain-language's generators) need. git + ca-certificates
# back the token-authenticated checkout and the release job's commit/tag push. Listed explicitly so the
# image's contract is self-documenting; the ones already in the base are harmless no-ops.
RUN apt-get update -yq \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      python3 \
      python3-yaml \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Anthropic's official plugin validator (`claude plugin validate --strict`). Pinned so validation is
# reproducible and moves only on a deliberate image rebuild (Renovate bumps this ARG); baking it removes
# the per-job `npm install -g @anthropic-ai/claude-code`, the slowest of the run-time installs.
ARG CLAUDE_CODE_VERSION=2.1.214
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
 && npm cache clean --force

LABEL org.opencontainers.image.title="WebGrip Skills CI Runner" \
    org.opencontainers.image.description="Node 24 + Python 3.13 (PyYAML) + Claude Code CLI for validating Claude Code skills/plugins (webgrip/ai-skills CI)" \
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
