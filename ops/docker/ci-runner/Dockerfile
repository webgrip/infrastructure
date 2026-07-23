
ARG RUNNER_VERSION=2.335.1@sha256:08c30b0a7105f64bddfc485d2487a22aa03932a791402393352fdf674bda2c29
ARG REGISTRY_GHCR=ghcr.io
FROM ${REGISTRY_GHCR}/actions/actions-runner:${RUNNER_VERSION} AS runner

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG REGISTRY_GHCR
ARG RUNNER_VERSION

LABEL org.opencontainers.image.title="WebGrip CI Runner" \
    org.opencontainers.image.description="Shared CI runner toolchain (PHP, .NET, Node, Python, Claude Code CLI). Runs as a GitHub Actions self-hosted runner under ARC, and as the host-mode toolchain for the in-cluster Forgejo runner (which injects the forgejo-runner binary alongside it)." \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${REGISTRY_GHCR}/actions/actions-runner:${RUNNER_VERSION}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

USER root

# gettext-base provides envsubst. sigstore/cosign-installer v4+ shells out to it unconditionally
# to expand the `$HOME` in its default install-dir, so without it every signing job dies
# "envsubst: command not found" (exit 127) before cosign is even installed. Host-mode Forgejo jobs
# execute in THIS image, so the tool has to be here — a workflow can't apt-get it (non-root runner).
RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    curl \
    bash \
    jq \
    git \
    patch \
    unzip \
    rsync \
    gettext-base \
    software-properties-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Regression guard for the tool the signing path depends on: cosign-installer v4+ hard-requires
# envsubst, so a base-image bump or refactor that drops gettext-base must fail THIS build --
# not every future release's Sign & Attest job at runtime (which is exactly what happened
# before gettext-base was added).
RUN command -v envsubst

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Helm, baked in: CI jobs currently run azure/setup-helm per job — a WAN download plus an
# action clone on every run. With helm on PATH the shared reusables' setup-helm fallback
# becomes a no-op.
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=3.21.3
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
      | tar -xz -C /tmp linux-amd64/helm && \
    install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm && \
    rm -rf /tmp/linux-amd64 && \
    helm version --short

# https://github.com/orgs/community/discussions/177903
# This "fixes" a "bug" that causes errors on self-hosted runners when runner ghcp agents workloads
# The problem is that the workload expects codeql to be installed, but it's not present by default

# Pinned to a commit SHA (was `main`): an unpinned script made the image irreproducible and
# handed upstream a silent code-execution path into every rebuild. Renovate can bump the pin.
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/actions/runner-images/60599408e44b8b49421b7c60c1f8bb4e1abedbd0/images/ubuntu/scripts/build/install-codeql-bundle.sh)"

ARG DOTNET_CHANNEL=9.0
ENV DOTNET_INSTALL_DIR=/opt/dotnet \
    DOTNET_ROOT=/opt/dotnet \
    PATH=/opt/dotnet:/opt/dotnet/tools:${PATH} \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

RUN set -eux; \
    mkdir -p "$DOTNET_INSTALL_DIR"; \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh; \
    chmod +x /tmp/dotnet-install.sh; \
    /tmp/dotnet-install.sh --channel "$DOTNET_CHANNEL" --quality ga --install-dir "$DOTNET_INSTALL_DIR"; \
    rm -f /tmp/dotnet-install.sh; \
    dotnet --info; \
    chown -R runner:runner "$DOTNET_INSTALL_DIR"

ARG PHP_VERSION=8.3
RUN add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-sockets \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Composer using the official installer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer

# Node.js toolchain for host-mode jobs. The actions-runner base bundles node under
# externals/ for JS actions only (not on PATH, and its layout is a runner internal), so
# install Node properly: host-mode steps need `node`/`npm`/`npx` on PATH, and a stable
# global npm prefix for the CLI below. Size is not a per-job cost — the kubelet pulls this
# image once per node and containerd caches it (that is the point of host mode).
ARG NODE_MAJOR=24
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    node --version && npm --version

# Restore the GLIBC node20 external the actions-runner base dropped. Base 2.335.x ships
# ONLY externals/node24_alpine (musl): container-mode JS actions (checkout@v4 declares
# node20) then have no node to inject into glibc job containers — rust:latest/php:8.5-cli
# jobs die with 'exec: "node": executable file not found' while alpine jobs keep working
# (observed 2026-07-19/20, nuala runs 30-37, verified in the dind daemon logs). Official
# glibc build, laid out exactly where forgejo-runner looks.
# renovate: datasource=node-version depName=node versioning=node
ARG EXTERNAL_NODE20_VERSION=20.19.5
RUN mkdir -p /home/runner/externals/node20 && \
    curl -fsSL "https://nodejs.org/dist/v${EXTERNAL_NODE20_VERSION}/node-v${EXTERNAL_NODE20_VERSION}-linux-x64.tar.gz" \
      | tar -xz --strip-components=1 -C /home/runner/externals/node20 && \
    chown -R runner:runner /home/runner/externals/node20 && \
    /home/runner/externals/node20/bin/node --version

# PyYAML for CI that parses YAML from python (e.g. webgrip/ai-skills' plugin test suites).
# From apt, not pip: the base python3 is externally-managed (PEP 668), so pip would need
# --break-system-packages.
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-yaml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Anthropic's Claude Code CLI — `claude plugin validate` is the official manifest/frontmatter
# validator used by the skills/plugin repos. Pinned so validation is reproducible and moves
# only on a deliberate image rebuild (Renovate bumps this ARG).
ARG CLAUDE_CODE_VERSION=2.1.214
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" && \
    npm cache clean --force

# Prebaked semantic-release toolchain. The webgrip/workflows semantic-release composites
# npm-install exactly this set on every release job (~4 min measured per run); when
# SEMREL_PREBAKED is set and the directory exists they skip the install and put
# $SEMREL_PREBAKED/.bin on PATH instead. Versions pinned exactly (--save-exact) so the
# baked tree mirrors what the composites would have installed.
RUN mkdir -p /opt/semrel && \
    cd /opt/semrel && \
    npm init -y > /dev/null && \
    npm install --save-exact --no-audit --no-fund \
      semantic-release@24.2.7 \
      semantic-release-monorepo@8.0.2 \
      @semantic-release/commit-analyzer@13.0.0 \
      @semantic-release/exec@7.0.3 \
      @semantic-release/git@10.0.1 \
      @semantic-release/changelog@6.0.3 \
      @saithodev/semantic-release-gitea@2.1.0 \
      @semantic-release/release-notes-generator@14.0.0 \
      conventional-changelog-conventionalcommits@7.0.2 \
      semantic-release-helm3@2.10.0 && \
    npm cache clean --force
ENV SEMREL_PREBAKED=/opt/semrel/node_modules

USER runner
