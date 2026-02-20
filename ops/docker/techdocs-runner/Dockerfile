FROM ghcr.io/webgrip/techdocs-builder:latest AS techdocs

RUN apk add --no-cache \
    python3 \
    py3-pip

COPY --from=ghcr.io/webgrip/techdocs-builder:latest /usr/local /usr/local
COPY --from=ghcr.io/webgrip/techdocs-builder:latest /opt/plantuml.jar /opt/plantuml.jar
COPY --from=ghcr.io/webgrip/techdocs-builder:latest /usr/local/bin/plantuml /usr/local/bin/plantuml

COPY ./ops/docker/techdocs-runner/docker-entrypoint.sh ./docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
