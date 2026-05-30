ARG FINAL_BASE=alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

FROM node:24-alpine3.20@sha256:8fe019e0d57dbdce5f5c27c0b63d2775cf34b00e3755a7dea969802d7e0c2b25 AS node

RUN corepack enable && corepack prepare npm@latest --activate

RUN npm install -g \
    @techdocs/cli@1.9.0 \
    @mermaid-js/mermaid-cli@11.4.2

# python 
FROM python:3.13.3-alpine3.20@sha256:40a4559d3d6b2117b1fbe426f17d55b9100fa40609733a1d0c3f39e2151d4b33 AS python

RUN apk add --no-cache graphviz

RUN pip3 install --no-cache-dir \
    mkdocs-techdocs-core==1.5.3 \
    markdown-inline-mermaid==1.0.4 \
    mkdocs-mermaid2-plugin==1.2.1 \
    mkdocs-macros-plugin==1.3.7 \
    mkdocs-dracula-theme==1.0.7


FROM eclipse-temurin:11.0.31_11-jre-alpine@sha256:a83a14eeeee6151dfefea24b390f0190f25b7add6ff752e93757a39fb8378eb9 AS openjdk

RUN apk add --no-cache curl

RUN curl -o /opt/plantuml.jar -L http://sourceforge.net/projects/plantuml/files/plantuml.1.2023.7.jar/download && \
    echo "93fe1101c59381e0b3af86262b844871ca0eb987  /opt/plantuml.jar" | sha1sum -c - && \
    echo '#!/bin/sh\nexec java -jar /opt/plantuml.jar "$@"' > /usr/local/bin/plantuml && \
    chmod +x /usr/local/bin/plantuml


FROM ${FINAL_BASE} AS final

ARG FINAL_BASE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

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

LABEL org.opencontainers.image.title="WebGrip TechDocs Builder" \
    org.opencontainers.image.description="TechDocs build image with MkDocs, PlantUML, Mermaid, and Chromium" \
    org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${FINAL_BASE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"
