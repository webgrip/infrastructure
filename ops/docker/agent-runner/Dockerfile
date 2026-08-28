# Release re-entry touch, fourth boarding: runs 426/430 died on the ai-skills PO rename
# (fixed in 2f0ddb8 — see SKILLS_CORE), run 431 in the semantic-release image plumbing,
# and run 435 on the notes-toolchain pair the manifest-less composite install could not
# express. PR #135 ended that class: the toolchain is now the committed root
# package.json + package-lock.json (`npm ci`), overrides forcing the PR #10 pair. The
# matrix is push-diff, so a dropped train needs a touch like this or a workflow_dispatch.
ARG REGISTRY_DOCKERHUB=docker.io
# dhi.io refuses anonymous pulls; this one defaults to the Harbor proxy (ADR-0023).
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
ARG REGISTRY_GHCR=ghcr.io

# The dark-factory agent runner: one of these executes a single ticket end to end.
#
# DESIGN — agent tooling is baked; LANGUAGE TOOLCHAINS ARE NOT, and neither is a docker
# client. The agent plane is daemonless (homelab-cluster ADR-0053): the agent edits code
# and opens a PR, and language gates run in CI, in the very images CI uses —
# rust-ci-runner / ci-runner / playwright-runner, php:8.5-cli, node:24-alpine — which makes
# the gates match CI exactly instead of approximately, and keeps this image small enough to
# pull per ticket. Baking rust alone cost ~1.4GB and made every publish crawl; the docker
# CLI this image used to carry served a privileged DinD sidecar the cluster no longer
# admits.
#
# All base-image refs are global ARGs (before any FROM) so their composed defaults resolve;
# the registry is a variable so CI can route through the Harbor pull-through proxy. Annotated
# for the digest-aware regex manager — the dockerfile manager silently cannot update
# registry-variable FROMs ('Cannot find replaceString'), which is how these digests sat frozen
# since July while agent-runner accrued 43 criticals from a stale python base.
# uv is copied from its official image (reproducible; no `curl | sh`).
# renovate: datasource=docker depName=ghcr.io/astral-sh/uv versioning=docker
ARG UV_IMAGE=${REGISTRY_GHCR}/astral-sh/uv:0.9.2@sha256:6dbd7c42a9088083fa79e41431a579196a189bcee3ae68ba904ac2bf77765867
# node 24 — for the agent's own workflow tooling (openspec, moon), not for running gates.
# MUST match the base's libc: the node binary is dynamically linked, so an alpine base needs an
# alpine node (and alpine 3.24 to match the python base's musl).
# renovate: datasource=docker depName=dhi.io/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DHI}/node:24.19.0-alpine3.24-dev@sha256:4b70bb724239d33250044c831c04746c75c4041e1247fecd9372b5da59d5d972
# ADR-0006 Stage 2. python 3.12 still, matching CI's python:3.12 for the domain scripts.
#
# ALPINE, and the reason is measured: the digest refresh (v1.0.4) recovered nothing — 43/101
# against 43/107 — and the gate's worst-packages list is 44 findings across libperl5.36, perl,
# perl-base and perl-modules. Those arrive because Debian's `git` DEPENDS on perl. Alpine's git
# does not, which is exactly why act-runner (40/123 -> 6/25) and helm-deploy (16/63 -> 8/54)
# collapsed on the same move. The debian13 variant is NOT the alternative here: it measured
# worse than stock on semantic-release (62/114 vs 36/73) for the same class of reason.
#
# THE RISK THIS BUILD TESTS: no compiler lives here on purpose ("nothing compiles here" below),
# so every wheel in openhands' tree must exist for musllinux — a package that only ships
# manylinux would try to build from sdist and fail. The build-time `openhands --version`
# assertions are the arbiter; a green build-check IS the compatibility evidence.
#
# BUILD PREREQUISITE: the `dhi` Harbor proxy project (homelab-cluster ADR-0023).
# renovate: datasource=docker depName=dhi.io/python versioning=docker
ARG BASE_IMAGE=${REGISTRY_DHI}/python:3.12.13-alpine3.24-dev@sha256:cf1c0e16904b7e831e430a02811cd36381c0e5b8ccf615be9be37fed0953260b

FROM ${UV_IMAGE} AS uv
FROM ${NODE_IMAGE} AS node

FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

# OpenHands CLI (bundles the Software Agent SDK). Pinned + released — never @next
# (homelab-cluster ADR-0047: an unattended factory does not run on a self-updating beta).
# The image NAME is deliberately harness-neutral so a future runtime swap is a content
# change, not a rename of every manifest and pull-ref.
# renovate: datasource=pypi depName=openhands
ARG OPENHANDS_VERSION=1.16.0
# Agent workflow tooling (mise.toml / .forgejo CI in the erfbeeld repo).
# renovate: datasource=npm depName=@moonrepo/cli
ARG MOON_VERSION=2.4.4
# renovate: datasource=npm depName=@fission-ai/openspec
ARG OPENSPEC_VERSION=1.6.0
# renovate: datasource=pypi depName=pyyaml
ARG PYYAML_VERSION=6.0.3
# Skills loadout (board #268). The core set is baked from the webgrip marketplace at BUILD
# time so a run needs no network for its core skills; per-ticket extras are cloned at runtime
# by the entrypoint when OPENHANDS_SKILLS_PROFILE is set. CI can override SKILLS_REPO with
# the in-cluster URL (http://forgejo-http.forgejo.svc.cluster.local:3000/...).
# product-owner, not vikunja-product-owner: ai-skills a2b15b2 consolidated the PO craft
# into one cross-board skill (breaking rename), which dropped runs 426/430 exactly the
# way this loud clone guard is meant to — a missing core skill fails the BUILD, not a run.
ARG SKILLS_REPO=https://forgejo.webgrip.dev/webgrip/ai-skills.git
ARG SKILLS_REF=main
ARG SKILLS_CORE="guard-secrets adr-writer product-owner skill-usage"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    OPENHANDS_SUPPRESS_BANNER=1 \
    # headless runner: dependency DeprecationWarnings (authlib->joserfc et al) are
    # upstream's to fix and only pollute the run logs here.
    PYTHONWARNINGS=ignore::DeprecationWarning \
    # uv: link tool executables into a PATH dir, use the base image's CPython, no network
    # Python fetches, no build cache layer.
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_PYTHON_DOWNLOADS=never \
    UV_NO_CACHE=1

# System deps only: git+ca-certificates (clone), bash (entrypoint). No curl — the LiteLLM
# key mint/revoke it existed for moved into `litellm-key` (node fetch, inputs via env only,
# shared with code14's agent-runner): no key or master key in argv where the agent can read
# /proc, and one fewer CVE-bearing package.
# No build-essential — nothing compiles here; compilation happens in CI's images.
RUN apk add --no-cache git ca-certificates bash

# --- OpenHands ----------------------------------------------------------------------------
COPY --from=uv /uv /uvx /usr/local/bin/
RUN uv tool install "openhands==${OPENHANDS_VERSION}" \
 && openhands --version

# The CLI hardcodes load_public_skills=True — a startup git-sync of
# github.com/OpenHands/extensions with NO opt-out (their #483 died stale; the
# SDK's own default is False). Our runners have no GitHub egress by policy, so
# every run burned ~5 min of git timeouts, and unvetted third-party skills are
# unwanted in metered runs anyway (VIK-590). Patch the installed CLI back to
# the SDK default; the greps fail THIS BUILD loudly if an upstream release
# moves or rewords the line, so behavior can never silently revert. Drop this
# when a CLI release ships a real knob.
RUN AGENT_STORE="$(find /root/.local/share/uv/tools/openhands -name agent_store.py -path '*/openhands_cli/*')" \
 && test -n "${AGENT_STORE}" \
 && grep -q 'load_public_skills=True' "${AGENT_STORE}" \
 && sed -i 's/load_public_skills=True/load_public_skills=False/' "${AGENT_STORE}" \
 && grep -q 'load_public_skills=False' "${AGENT_STORE}" \
 && ! grep -q 'load_public_skills=True' "${AGENT_STORE}" \
 # Bake the version banner: `openhands --version` at runtime is a full cold import
 # of the CLI tree — measured at 2m20s under the in-cluster worker's CPU limit
 # (ploeg silver run, 2026-07-27) just to log one line. The entrypoint cats this
 # file instead. test -s keeps the broken-CLI build guard the invocation provided.
 && openhands --version | head -1 > /etc/openhands-version \
 && test -s /etc/openhands-version

# LiteLLM (inside OpenHands) fetches its model-cost map from raw.githubusercontent.com
# at startup; offline that's a wasted timeout before the documented fallback to the
# bundled map. Pin to the local map outright (VIK-590).
ENV LITELLM_LOCAL_MODEL_COST_MAP=True

# --- Node 24 (agent workflow tooling only) ------------------------------------------------
# DHI relocates the whole node payload: binary in /usr/bin, npm's modules in
# /usr/lib/node_modules (stock node uses /usr/local for both), and no /usr/local at all.
# Build-check 417 found this the honest way.
RUN install -d /usr/local/bin /usr/local/lib/node_modules
COPY --from=node /usr/bin/node /usr/local/bin/node
COPY --from=node /usr/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node --version && npm --version

# --- moon + openspec: the agent's own change-workflow tools --------------------------------
RUN npm install -g "@moonrepo/cli@${MOON_VERSION}" "@fission-ai/openspec@${OPENSPEC_VERSION}" \
 && moon --version && openspec --version

# --- pyyaml for the domain scripts ---------------------------------------------------------
RUN pip install --no-cache-dir "pyyaml==${PYYAML_VERSION}" \
 && python3 -c "import yaml; print('pyyaml', yaml.__version__)"

# --- baked core skills ---------------------------------------------------------------------
# OpenHands discovers skills by DIRECTORY: anything under $HOME/.openhands/skills/installed
# is self-registered (its metadata file is self-healing — "add entries for extension
# directories that were manually copied in"). So delivery is a plain copy, no install API.
# We stage the core at /opt/webgrip/skills; the entrypoint copies it into the run's real
# $HOME (which varies: root locally, an emptyDir in-cluster).
RUN git clone --depth 1 --branch "${SKILLS_REF}" "${SKILLS_REPO}" /tmp/skills-src \
 && mkdir -p /opt/webgrip/skills \
 && for s in ${SKILLS_CORE}; do \
      if [ -d "/tmp/skills-src/skills/${s}" ]; then \
        cp -r "/tmp/skills-src/skills/${s}" /opt/webgrip/skills/; \
      else \
        echo "core skill '${s}' not found in the marketplace" >&2; exit 1; \
      fi; \
    done \
 && rm -rf /tmp/skills-src \
 && echo "baked core skills:" && ls -1 /opt/webgrip/skills

# Runtime defaults for the per-ticket loadout, mirroring what was baked.
ENV OPENHANDS_SKILLS_REPO=${SKILLS_REPO} \
    OPENHANDS_SKILLS_REF=${SKILLS_REF}

# litellm-key is kept byte-identical with code14's agent-runner copy (see its header);
# the entrypoint's mint→run→revoke sections are the shared contract too.
COPY ./litellm-key.mjs /usr/local/bin/litellm-key
COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/litellm-key /usr/local/bin/docker-entrypoint.sh \
 # The helper that replaced curl. `mint` with nothing configured must fail loudly
 # rather than hang or silently emit an empty key — a helper that exits 0 on a
 # missing admin URL would hand the agent an empty credential.
 && if litellm-key mint 2>/dev/null; then echo "FATAL: litellm-key mint succeeded with no configuration" >&2; exit 1; fi

WORKDIR /workspace

LABEL org.opencontainers.image.title="WebGrip Agent Runner" \
    org.opencontainers.image.description="Dark-factory agent runner: headless OpenHands with a per-run LiteLLM key and a skills loadout. Daemonless (ADR-0053): the agent edits code and opens a PR; language gates run in CI, in CI's own images, so the image stays small and the gates match CI exactly." \
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
