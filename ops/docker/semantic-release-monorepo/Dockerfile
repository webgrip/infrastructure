###############################################################################
# semantic-release toolchain + semantic-release-monorepo, for per-package release trains
# (webgrip/workflows' semantic-release-monorepo.yml).
#
# FROM the base toolchain image, so node, git, yq, the SEMREL_PREBAKED contract and the OCI
# metadata are inherited rather than restated. The only difference is the locked dependency set:
# it adds semantic-release-monorepo, which @webgrip/semantic-release-config deliberately does NOT
# depend on (2026-07-26 security cleanup — it drags a legacy dep with findings, and bundling it in
# the config would push it into every consumer's tree). The image carries it instead, so only the
# repos that need it get it.
#
# The whole tree is REPLACED rather than layered on: semantic-release resolves plugins relative to
# its own install and the cwd, not via NODE_PATH, so a second node_modules would not be found. One
# resolution root, locked, is the only shape that cannot half-work.
###############################################################################
ARG REGISTRY_DOCKERHUB=docker.io
ARG REGISTRY_WEBGRIP=harbor.webgrip.dev/webgrip
# renovate: datasource=docker depName=harbor.webgrip.dev/webgrip/semantic-release
ARG SEMANTIC_RELEASE_VERSION=1.0.0
# renovate: datasource=docker depName=docker.io/library/node versioning=docker
ARG NODE_VERSION=24
ARG DEBIAN_CODENAME=bookworm

###############################################################################
# Locked toolchain (same node as the base image builds its own with)
###############################################################################
FROM ${REGISTRY_DOCKERHUB}/library/node:${NODE_VERSION}-${DEBIAN_CODENAME}-slim AS deps
WORKDIR /opt/semrel
COPY toolchain/.npmrc /tmp/npmrc
COPY toolchain/package.json toolchain/package-lock.json ./
RUN NPM_CONFIG_USERCONFIG=/tmp/npmrc npm ci --omit=dev --no-audit --no-fund

###############################################################################
FROM ${REGISTRY_WEBGRIP}/semantic-release:${SEMANTIC_RELEASE_VERSION}

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG REGISTRY_WEBGRIP
ARG SEMANTIC_RELEASE_VERSION

RUN rm -rf /opt/semrel/node_modules
COPY --from=deps /opt/semrel/node_modules /opt/semrel/node_modules

RUN cd /tmp \
 && node -e "const v=require('semantic-release/package.json').version; if(v.split('.')[0]!=='25') throw new Error('expected semantic-release 25.x, got '+v); console.log('semantic-release '+v)" \
 && node -e "require.resolve('@webgrip/semantic-release-config')" \
 && node -e "require.resolve('semantic-release-monorepo')"

LABEL org.opencontainers.image.title="WebGrip semantic-release Toolchain (monorepo)" \
    org.opencontainers.image.description="Locked semantic-release 25 toolchain + semantic-release-monorepo, for per-package release trains" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${REGISTRY_WEBGRIP}/semantic-release:${SEMANTIC_RELEASE_VERSION}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["bash"]
