ARG BASE_IMAGE=ubuntu:noble
FROM ${BASE_IMAGE}

ARG BASE_IMAGE

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /workspace

RUN apt-get update -yq \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      bash \
      git \
      unzip \
      zip \
      jq \
      patch \
      rsync \
      software-properties-common \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ARG PHP_VERSION=8.4
RUN add-apt-repository ppa:ondrej/php -y \
 && apt-get update -yq \
 && apt-get install -y --no-install-recommends \
      php${PHP_VERSION}-cli \
      php${PHP_VERSION}-common \
      php${PHP_VERSION}-bcmath \
      php${PHP_VERSION}-curl \
      php${PHP_VERSION}-gd \
      php${PHP_VERSION}-intl \
      php${PHP_VERSION}-mbstring \
      php${PHP_VERSION}-mysql \
      php${PHP_VERSION}-pcov \
      php${PHP_VERSION}-soap \
      php${PHP_VERSION}-sockets \
      php${PHP_VERSION}-xml \
      php${PHP_VERSION}-zip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Install Composer using the official installer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
 && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
 && php -r "unlink('composer-setup.php');" \
 && chmod +x /usr/local/bin/composer

LABEL org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.description="PHP CI runner with Composer and common extensions" \
    org.opencontainers.image.base.name="${BASE_IMAGE}" \
    org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["bash"]
