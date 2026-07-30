###############################################################################
# The release toolchain every webgrip release job runs in.
#
# Before this image, each release job built its own toolchain: ~430 packages resolved from the
# network on the critical path, unlocked, on every release in every repo (ploeg run 122: 2m + 21s
# of npm for ~25s of releasing). Two runs of the same commit could cut the release with different
# plugin versions — the thing that decides version numbers was itself unversioned.
#
# Contract with webgrip/workflows' semantic-release composites: SEMREL_PREBAKED names an installed
# node_modules, with PATH and NODE_PATH pointing into it. The composites find it and run; they
# install nothing. See webgrip/workflows ADR-0005.
#
# The dependency set is LOCKED — npm ci against toolchain/package-lock.json. That is the whole
# point of the image, so the lockfile is committed and Renovate owns it. Derived images
# (semantic-release-monorepo, semantic-release-rust) build FROM this one.
###############################################################################
ARG REGISTRY_DOCKERHUB=docker.io
# renovate: datasource=docker depName=docker.io/library/node versioning=docker
ARG NODE_VERSION=24
ARG DEBIAN_CODENAME=bookworm

###############################################################################
# Locked toolchain, built in a separate stage so npm's cache and metadata never reach the image
###############################################################################
FROM ${REGISTRY_DOCKERHUB}/library/node:${NODE_VERSION}-${DEBIAN_CODENAME}-slim AS deps
WORKDIR /opt/semrel
# @webgrip packages come from the Forgejo registry (anonymous read; no credential in .npmrc).
COPY toolchain/.npmrc /tmp/npmrc
COPY toolchain/package.json toolchain/package-lock.json ./
RUN NPM_CONFIG_USERCONFIG=/tmp/npmrc npm ci --omit=dev --no-audit --no-fund

###############################################################################
# Runtime: node (which also runs the JS actions in a container job), git, yq
###############################################################################
FROM ${REGISTRY_DOCKERHUB}/library/node:${NODE_VERSION}-${DEBIAN_CODENAME}-slim

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG REGISTRY_DOCKERHUB
ARG NODE_VERSION
ARG DEBIAN_CODENAME
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# yq — required by @webgrip/semantic-release-config's Chart.yaml version/appVersion bump and by
# repo prepareCmds. Downloading and checksum-verifying a binary is BUILD work; it used to happen
# inside every release job in every repo.
###############################################################################
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.44.3
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    # Checksums as published with the version pinned above (the release's own `checksums` asset).
    # A Renovate bump lands here with no recorded hash: that WARNS rather than failing, so an
    # automated bump cannot break the image build — but the warning is the signal to record the
    # new pair.
    case "${YQ_VERSION}_${arch}" in \
      v4.44.3_amd64) yq_sha="a2c097180dd884a8d50c956ee16a9cec070f30a7947cf4ebf87d5f36213e9ed7" ;; \
      v4.44.3_arm64) yq_sha="0e7e1524f68d91b3ff9b089872d185940ab0fa020a5a9052046ef10547023156" ;; \
      *) yq_sha="" ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}"; \
    if [ -n "$yq_sha" ]; then \
      echo "${yq_sha}  /usr/local/bin/yq" | sha256sum -c -; \
    else \
      echo "WARNING: no recorded sha256 for yq ${YQ_VERSION}/${arch} — downloaded unverified; record it in this Dockerfile" >&2; \
    fi; \
    chmod +x /usr/local/bin/yq; \
    yq --version

COPY --from=deps /opt/semrel /opt/semrel

# SEMREL_PREBAKED is the contract; PATH and NODE_PATH are what make it usable. NODE_PATH is not
# optional: a consumer's .releaserc.cjs does a bare require('@webgrip/semantic-release-config')
# from its own checkout, which resolves against that workspace only unless NODE_PATH says otherwise.
ENV SEMREL_PREBAKED=/opt/semrel/node_modules \
    NODE_PATH=/opt/semrel/node_modules \
    PATH=/opt/semrel/node_modules/.bin:$PATH

# A release job bind-mounts a checkout owned by another uid; git refuses to touch it otherwise.
RUN git config --system --add safe.directory '*'

# Build-time proof of the contract the composites rely on: the major they target is what is
# installed, and a bare require() of the shared config resolves from an arbitrary cwd. A lockfile
# bump that breaks either fails the build instead of a release — including a semantic-release MAJOR
# bump, which must be a deliberate change to this image, its consumers' expectations and their tags.
RUN cd /tmp \
 && node -e "const v=require('semantic-release/package.json').version; if(v.split('.')[0]!=='25') throw new Error('expected semantic-release 25.x, got '+v); console.log('semantic-release '+v)" \
 && node -e "require.resolve('@webgrip/semantic-release-config')" \
 && node -e "require.resolve('semantic-release-helm3')"

LABEL org.opencontainers.image.title="WebGrip semantic-release Toolchain" \
    org.opencontainers.image.description="Locked semantic-release 25 toolchain + @webgrip/semantic-release-config, node, git, yq" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${REGISTRY_DOCKERHUB}/library/node:${NODE_VERSION}-${DEBIAN_CODENAME}-slim" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["bash"]
