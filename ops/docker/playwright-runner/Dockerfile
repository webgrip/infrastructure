FROM mcr.microsoft.com/playwright:v1.51.0-noble

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

RUN add-apt-repository ppa:ondrej/php -y && \
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


RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["npx", "playwright", "test"]
