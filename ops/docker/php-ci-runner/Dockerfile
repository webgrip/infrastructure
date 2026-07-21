ARG REGISTRY_DOCKERHUB=docker.io
ARG COMPOSER_IMAGE=${REGISTRY_DOCKERHUB}/library/composer:2@sha256:1b73755de4f19775ba6087fd5313664493e06fab72b6fc27dc2044e87bb7c4c3
ARG PHP_IMAGE=${REGISTRY_DOCKERHUB}/library/php:8.5-cli@sha256:f7476cffd8d6c48daa07fd80a58b85f97da095ad5a03fcf3361fd872122e3d91
# renovate: datasource=github-releases depName=extism/extism
ARG EXTISM_VERSION=1.30.0

FROM ${COMPOSER_IMAGE} AS composer
FROM ${PHP_IMAGE}

ARG COMPOSER_IMAGE
ARG PHP_IMAGE
ARG EXTISM_VERSION
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

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
      libffi8 \
      $PHPIZE_DEPS \
      pkg-config \
      libicu-dev \
      libzip-dev \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      libonig-dev \
      libxml2-dev \
      libffi-dev \
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
      ffi \
 && pecl install pcov \
 && docker-php-ext-enable pcov \
 && echo "ffi.enable=1" > /usr/local/etc/php/conf.d/99-ffi.ini \
 && curl -fsSL "https://github.com/extism/extism/releases/download/v${EXTISM_VERSION}/libextism-x86_64-unknown-linux-gnu-v${EXTISM_VERSION}.tar.gz" \
      | tar -xz -C /usr/local/lib libextism.so \
 && ldconfig \
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
      libffi-dev \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.title="WebGrip PHP CI Runner" \
    org.opencontainers.image.description="PHP CI runner with Composer and common extensions" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${PHP_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

CMD ["bash"]
