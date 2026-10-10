###############################################################################
# Release re-entry: v0.1.1 shipped UNSIGNED — its Sign & Attest died on the security
# namespace's ingress default-deny dropping runner->openbao:8200 (run 301; fixed in
# homelab-cluster#550). Harbor's immutable tags make re-signing-by-rebuild impossible
# (proven on run 301 attempt 2), so this cuts a signed successor; delete the unsigned
# 0.1.1 tag after it lands.
###############################################################################
# semantic-release toolchain + cargo, for Rust crate release trains
#
# (webgrip/workflows' rust-semantic-release composite.)
#
# Same locked toolchain as the semantic-release image, plus a minimal Rust toolchain and
# semantic-release-cargo.
#
# NOT rust-releaser: that image is the heavy cross-compilation environment (cross, wasm-bindgen,
# QEMU, docker CLI) whose semantic-release install is `npm install -g … latest` — unpinned, which
# is the problem this family exists to remove. This is the release toolchain for a Rust crate, not
# a build farm. Nothing stops a repo needing both from building FROM rust-releaser and copying
# /opt/semrel out of here.
#
# cargo-release and git-cliff are deliberately absent: semantic-release-cargo performs the version
# bump and publish, semantic-release itself writes the changelog, and neither tool has a prebuilt
# arm64 artifact on binstall's path — including them turns a one-minute image build into a
# from-source cargo compile. Add them here, not to a job, if a consumer actually needs them.
###############################################################################
ARG REGISTRY_DOCKERHUB=docker.io
# One ARG carrying tag AND digest (house pattern, see cve-gate): Renovate moves them together
# via the digest-aware annotated-ARG manager, and a budget measured against this base stays a
# statement about THIS base until Renovate says otherwise.
# renovate: datasource=docker depName=docker.io/library/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DOCKERHUB}/library/node:24-bookworm-slim@sha256:d6aa754f16b3197301076f047b5def2f02ea1dbbc2ca920407d46d7ec7f87b20

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
ARG REGISTRY_DOCKERHUB
ARG NODE_IMAGE

# Shared runtime — keep this block the same in all three semantic-release* images.
# Duplicated on purpose. These images used to build FROM one another, which made a sibling's
# PUBLISHED artifact a build dependency: run 167's base image build was killed on the shared runner
# pool, so 0.1.0 existed as a release with no image and both derived builds failed for two more
# runs on a FROM that could never resolve. Independent images cannot fail that way. The duplication
# costs text, not bytes: identical instructions on an identical base produce identical layer
# digests, so Harbor stores them once and a runner pulls them once.
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# yq — required by @webgrip/semantic-release-config's Chart.yaml version/appVersion bump and by
# repo prepareCmds. Downloading and checksum-verifying a binary is BUILD work; it used to happen
# inside every release job in every repo.
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

# SEMREL_PREBAKED is the contract with webgrip/workflows' composites; PATH and NODE_PATH are what
# make it usable. NODE_PATH is not optional: a consumer's .releaserc.cjs does a bare
# require('@webgrip/semantic-release-config') from its own checkout, which resolves against that
# workspace only unless NODE_PATH says otherwise.
ENV SEMREL_PREBAKED=/opt/semrel/node_modules \
    NODE_PATH=/opt/semrel/node_modules \
    PATH=/opt/semrel/node_modules/.bin:$PATH

# A release job bind-mounts a checkout owned by another uid; git refuses to touch it otherwise.
RUN git config --system --add safe.directory '*'

###############################################################################
# Rust toolchain (stable, minimal) ➜ lives in /usr/local/cargo, as in rust-releaser
###############################################################################
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

# Release re-entry: v0.1.3 promoted by digest but its sign scan was killed by node pressure
# (run 401; runner request raised to 3Gi in homelab-cluster 97361c7b). This cuts the signed
# successor.
# Pinned: 'stable' resolves to whatever rust-lang shipped most recently — the float the
# 2026-08-08 pin train fixed in rust-releaser and missed here. Same version as the rust images.
# renovate: datasource=docker depName=docker.io/library/rust versioning=docker
ARG RUST_TOOLCHAIN=1.97.0
RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain ${RUST_TOOLCHAIN} && \
    chmod -R a+w "${CARGO_HOME}" "${RUSTUP_HOME}" && \
    cargo --version

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
 && node -e "require.resolve('semantic-release-cargo')" \
 && bash -ec 'semantic-release --version'
# NB: that --version prints the IMAGE version, not 25.x — yargs walks up from its own location to
# the first package.json, which is this image's root manifest (deliberately named after the image).
# The line is an EXECUTION probe, not a version assert (the node check above pins the real major):
# it proves bash exists (every composite step declares shell: bash), the bin wrapper runs, and its
# own git preflight passes on this base.

LABEL org.opencontainers.image.title="WebGrip semantic-release Toolchain (Rust)" \
    org.opencontainers.image.description="Locked semantic-release 25 toolchain + cargo and semantic-release-cargo" \
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
