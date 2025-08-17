FROM ghcr.io/actions/actions-runner:2.328.0 AS runner


LABEL maintainer="Ryan Grippeling <ryan@webgrip.nl>"

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

RUN add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y \
      php8.3-cli \
      php8.3-common \
      php8.3-bcmath \
      php8.3-curl \
      php8.3-gd \
      php8.3-intl \
      php8.3-mbstring \
      php8.3-mysql \
      php8.3-soap \
      php8.3-sockets \
      php8.3-xml \
      php8.3-zip \
    && apt-get clean

# Install Composer using the official installer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer

USER runner
