ARG COMPOSER_IMAGE=composer:2@sha256:f0809732b2188154b3faa8e44ab900595acb0b09cd0aa6c34e798efe4ebc9021
ARG PHP_IMAGE=php:8.5-cli@sha256:2d7a7e055947c398314250fb6d657c85979872c44ce9912b9dc9d1456439b0b3

FROM ${COMPOSER_IMAGE} AS composer
FROM ${PHP_IMAGE}

ARG COMPOSER_IMAGE
ARG PHP_IMAGE

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /workspace

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

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
      libicu76 \
     libzip5 \
      libpng16-16 \
      libjpeg62-turbo \
      libfreetype6 \
      $PHPIZE_DEPS \
      pkg-config \
      libicu-dev \
      libzip-dev \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      libonig-dev \
      libxml2-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
      bcmath \
      intl \
      gd \
      mbstring \
      pdo_mysql \
      soap \
      sockets \
      zip \
 && pecl install pcov \
 && docker-php-ext-enable pcov \
 && apt-get purge -y \
      $PHPIZE_DEPS \
      pkg-config \
      libicu-dev \
      libzip-dev \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      libonig-dev \
      libxml2-dev \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.description="PHP CI runner with Composer and common extensions" \
     org.opencontainers.image.base.name="${PHP_IMAGE}" \
    org.opencontainers.image.licenses="MIT"

CMD ["bash"]
