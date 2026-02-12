ARG PLAYWRIGHT_VERSION=1.51.0
ARG UBUNTU_CODENAME=noble
ARG BASE_IMAGE=mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-${UBUNTU_CODENAME}
FROM ${BASE_IMAGE}

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


RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer

LABEL org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.description="Playwright test runner with PHP ${PHP_VERSION}" \
    org.opencontainers.image.base.name="${BASE_IMAGE}" \
    org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["npx", "playwright", "test"]

