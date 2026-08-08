ARG REGISTRY_MCR=mcr.microsoft.com
# One ARG carrying tag AND digest (house pattern): a floating tag means the CVE count changes with
# every upstream rebuild, and this image's budget is the largest and least reducible in the estate
# (three browser engines) — it above all needs its baseline to describe a fixed artifact.
# renovate: datasource=docker depName=mcr.microsoft.com/playwright versioning=docker
ARG BASE_IMAGE=${REGISTRY_MCR}/playwright:v1.51.0-noble@sha256:dcc7a57c035cea22d94ef62edaf4e63b2d84352d990f936424344c6b05a3d9b4
FROM ${BASE_IMAGE}

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG TZ=Europe/Amsterdam
ENV TZ=${TZ}

WORKDIR /app

RUN npx playwright install --with-deps

COPY ./seccomp_profile.json /etc/seccomp_profile.json
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

RUN apt-get update && \
    apt-get install -y \
        curl \
        bash \
        jq \
        git \
        patch \
        unzip \
        rsync \
        software-properties-common \
        yq

ARG PHP_VERSION=8.3
RUN add-apt-repository ppa:ondrej/php -y && \
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


# Installer verified against the signature composer publishes on a SEPARATE host
# (composer.github.io vs getcomposer.org) — the official verification flow. Previously the
# installer ran unverified, which trusts getcomposer.org's CDN with arbitrary code execution
# in the build.
RUN EXPECTED="$(curl -fsSL https://composer.github.io/installer.sig)" && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    echo "${EXPECTED}  composer-setup.php" | sha384sum -c - && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer

LABEL org.opencontainers.image.title="WebGrip Playwright Runner" \
    org.opencontainers.image.description="Playwright test runner with PHP ${PHP_VERSION}" \
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

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["npx", "playwright", "test"]
