FROM ghcr.io/webgrip/techdocs-builder:latest AS mkdocs

COPY ./ops/docker/mkdocs-runner/docker-entrypoint.sh ./docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
