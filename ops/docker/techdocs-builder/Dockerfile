FROM node:23-alpine3.20 AS node

RUN corepack enable && corepack prepare npm@latest --activate

RUN npm install -g \
    @techdocs/cli@1.9.0 \
    @mermaid-js/mermaid-cli@11.4.2


FROM python:3.13.2-alpine3.20 AS python

RUN apk add --no-cache graphviz

RUN pip3 install --no-cache-dir \
    mkdocs-techdocs-core==1.5.3 \
    markdown-inline-mermaid==1.0.4 \
    mkdocs-mermaid2-plugin==1.2.1 \
    mkdocs-macros-plugin==1.3.7 \
    mkdocs-dracula-theme==1.0.7


FROM openjdk:11-jre-slim AS openjdk

RUN apt-get update && apt-get install -y curl && apt-get clean

RUN curl -o /opt/plantuml.jar -L http://sourceforge.net/projects/plantuml/files/plantuml.1.2023.7.jar/download && \
    echo "93fe1101c59381e0b3af86262b844871ca0eb987  /opt/plantuml.jar" | sha1sum -c - && \
    echo '#!/bin/sh\nexec java -jar /opt/plantuml.jar "$@"' > /usr/local/bin/plantuml && \
    chmod +x /usr/local/bin/plantuml


FROM alpine:3.20 AS final

RUN apk add --no-cache \
    libstdc++ \
    libffi \
    graphviz \
    chromium

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

COPY --from=node /usr/local /usr/local
COPY --from=python /usr/local /usr/local
COPY --from=openjdk /opt/plantuml.jar /opt/plantuml.jar
COPY --from=openjdk /usr/local/bin/plantuml /usr/local/bin/plantuml

WORKDIR /docs
