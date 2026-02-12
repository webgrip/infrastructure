ARG RUNNER_VERSION=2.331.0
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION} AS runner


LABEL maintainer="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.description="Customized GitHub Actions self-hosted runner with PHP tooling" \
    org.opencontainers.image.base.name="ghcr.io/actions/actions-runner:${RUNNER_VERSION}" \
    org.opencontainers.image.licenses="MIT"

USER root

RUN apt-get update && \
    apt-get install -y \
        curl \
        bash \
        jq \
        git \
        patch \
        unzip \
        rsync \
        software-properties-common

# https://github.com/orgs/community/discussions/177903
# This "fixes" a "bug" that causes errors on self-hosted runners when runner ghcp agents workloads
# The problem is that the workload expects codeql to be installed, but it's not present by default

# Run https://github.com/actions/runner-images/blob/main/images/ubuntu/scripts/build/install-codeql-bundle.sh
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/actions/runner-images/main/images/ubuntu/scripts/build/install-codeql-bundle.sh)"


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

