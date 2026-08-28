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
# point of the image, so the lockfile is committed and Renovate owns it. The two variants
# (semantic-release-monorepo, semantic-release-rust) are INDEPENDENT images that repeat the runtime
# block below verbatim rather than building FROM this one; see that block for why.
###############################################################################
# Release re-entry: the alpine commit's wave was cancelled by the monorepo push that followed
# it too quickly (the push-main concurrency group; self-inflicted, documented). Sibling result
# on the identical base: monorepo v0.3.0 measured 0 critical / 8 high.
# ADR-0006 Stage 2, second iteration: DHI node on ALPINE. The first iteration took
# node:24.19.0-debian13-dev and the gate measured it WORSE than stock bookworm-slim
# (36/73 -> 62/114, v0.2.0): the debian13 -dev variant ships perl, curl and friends that
# slim never carried, and trixie's advisory backlog is young. The alpine variant is the
# in-estate counter-proof — node-ci-runner on this exact base measures 0 critical / 5 high.
# This toolchain is pure JS + git + a static yq; nothing here needs glibc.
#
# BUILD PREREQUISITE: the `dhi` Harbor proxy project (homelab-cluster ADR-0023) — dhi.io refuses
# anonymous pulls, so unlike the other REGISTRY_* ARGs this one DEFAULTS to the proxy.
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
# renovate: datasource=docker depName=dhi.io/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DHI}/node:24.19.0-alpine3.23-dev@sha256:d00350837e082dc254939ffcf53861b3b965ff159e506d6ab1775710f91a82fe

###############################################################################
# Locked toolchain, built in a separate stage so npm's cache and metadata never reach the image
###############################################################################
FROM ${NODE_IMAGE} AS deps
WORKDIR /opt/semrel
# @webgrip packages come from the Forgejo registry (anonymous read; no credential in .npmrc).
# NB: this dir's package.json is BOTH the release manifest (its name is the tag prefix, its version
# is bumped by @semantic-release/git) and the toolchain manifest. npm does not mind: it tolerates a
# root version ahead of the lock's, which is the state every release leaves behind, and it accepts a
# package that depends on its own name — which semantic-release-monorepo and semantic-release-rust
# both do, since the image name is also a package name.
COPY .npmrc /tmp/npmrc
COPY package.json package-lock.json ./
RUN NPM_CONFIG_USERCONFIG=/tmp/npmrc npm ci --omit=dev --no-audit --no-fund

###############################################################################
# Runtime: node (which also runs the JS actions in a container job), git, yq
###############################################################################
FROM ${NODE_IMAGE}

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG NODE_IMAGE

# Shared runtime — keep this block the same in all three semantic-release* images.
# Duplicated on purpose. These images used to build FROM one another, which made a sibling's
# PUBLISHED artifact a build dependency: run 167's base image build was killed on the shared runner
# pool, so 0.1.0 existed as a release with no image and both derived builds failed for two more
# runs on a FROM that could never resolve. Independent images cannot fail that way. The duplication
# costs text, not bytes: identical instructions on an identical base produce identical layer
# digests, so Harbor stores them once and a runner pulls them once.
# bash is not optional: every step of the semantic-release composites declares `shell: bash`,
# and the DHI node alpine base ships only busybox sh. The alpine wave (v0.2.0/v0.3.0) left the
# builds green while no consumer ran them — ploeg pinned the last debian image (0.1.2) — and the
# first real job on 0.3.1 died on its first bash step (ploeg runs 226/227, 2026-08-28).
RUN apk add --no-cache bash git ca-certificates curl

# yq — required by @webgrip/semantic-release-config's Chart.yaml version/appVersion bump and by
# repo prepareCmds. Downloading and checksum-verifying a binary is BUILD work; it used to happen
# inside every release job in every repo.
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.44.3
RUN set -eux; \
    # DHI's node image ships no /usr/local/bin (stock node puts the binary there; the hardened
    # build relocates it) — same finding as dhi/alpine-base, debian flavor.
    install -d /usr/local/bin; \
    case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; *) arch="$(uname -m)" ;; esac; \
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

# SEMREL_PREBAKED is the contract with webgrip/workflows' composites; PATH and NODE_PATH are what
# make it usable. NODE_PATH is not optional: a consumer's .releaserc.cjs does a bare
# require('@webgrip/semantic-release-config') from its own checkout, which resolves against that
# workspace only unless NODE_PATH says otherwise.
ENV SEMREL_PREBAKED=/opt/semrel/node_modules \
    NODE_PATH=/opt/semrel/node_modules \
    PATH=/opt/semrel/node_modules/.bin:$PATH

# A release job bind-mounts a checkout owned by another uid; git refuses to touch it otherwise.
RUN git config --system --add safe.directory '*'

COPY --from=deps /opt/semrel /opt/semrel

# Build-time proof of the contract the composites rely on: the major they target is what is
# installed, and a bare require() resolves from an arbitrary cwd (i.e. NODE_PATH works). A lockfile
# bump that breaks either fails the build instead of a release — including a semantic-release MAJOR
# bump, which must be a deliberate change to these images and their consumers together.
# The last two lines prove the RUNTIME half of the contract, which node-side resolution cannot:
# every composite step declares `shell: bash`, and the binary must actually execute on this base.
# The alpine wave (v0.2.0/v0.3.0) passed the node checks while shipping no bash — no consumer ran
# those images until ploeg's first job on 0.3.1 died on its first bash step (runs 226/227).
RUN cd /tmp \
 && node -e "const v=require('semantic-release/package.json').version; if(v.split('.')[0]!=='25') throw new Error('expected semantic-release 25.x, got '+v); console.log('semantic-release '+v)" \
 && node -e "require.resolve('@webgrip/semantic-release-config')" \
 && node -e "require.resolve('semantic-release-helm3')" \
 && bash -ec 'semantic-release --version'
# NB: that --version prints the IMAGE version, not 25.x — yargs walks up from its own location to
# the first package.json, which is this image's root manifest (deliberately named after the image).
# The line is an EXECUTION probe, not a version assert (the node check above pins the real major):
# it proves bash exists (every composite step declares shell: bash), the bin wrapper runs, and its
# own git preflight passes on this base.

LABEL org.opencontainers.image.title="WebGrip semantic-release Toolchain" \
    org.opencontainers.image.description="Locked semantic-release 25 toolchain + @webgrip/semantic-release-config, node, git, yq" \
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

ENTRYPOINT ["bash"]
