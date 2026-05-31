
ARG RUNNER_VERSION=2.334.0@sha256:b6614fce332517f74d0a76e7c762fb08e4f2ff13dcf333183397c8a5725b6e8e
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION} AS runner

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

LABEL org.opencontainers.image.title="WebGrip GitHub Runner" \
    org.opencontainers.image.description="Customized GitHub Actions self-hosted runner with PHP and .NET tooling" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="ghcr.io/actions/actions-runner:${RUNNER_VERSION}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

USER root

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
    software-properties-common

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    apt-get clean

# https://github.com/orgs/community/discussions/177903
# This "fixes" a "bug" that causes errors on self-hosted runners when runner ghcp agents workloads
# The problem is that the workload expects codeql to be installed, but it's not present by default

# Run https://github.com/actions/runner-images/blob/main/images/ubuntu/scripts/build/install-codeql-bundle.sh
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/actions/runner-images/main/images/ubuntu/scripts/build/install-codeql-bundle.sh)"

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
    && apt-get clean

# Install Composer using the official installer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer

USER runner
