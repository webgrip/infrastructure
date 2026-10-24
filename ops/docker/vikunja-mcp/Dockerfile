ARG REGISTRY_DOCKERHUB=docker.io

# supergateway is the stdio<->streamableHttp MCP bridge; the @aimbitgmbh/vikunja-mcp server
# is stdio-only. The stock deployment ran `npx -y @aimbitgmbh/vikunja-mcp@0.1.0` as the
# --stdio child, which fetches the package from npm at every session spawn (a startup
# network dependency + the reason the pod needs an internet-egress NetworkPolicy carve-out).
# Bake the pinned MCP in so supergateway spawns a local `vikunja-mcp` binary instead.
# Literal tag+digest in the ARG default keeps Renovate's dockerfile manager current; the
# registry is a variable so CI can route through the Harbor pull-through proxy.
ARG BASE_IMAGE=${REGISTRY_DOCKERHUB}/supercorp/supergateway:3.4.3@sha256:095acf4471e142553c1a5514aa5e480abbc5885d00549d4a3481cc70eac53889
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

COPY tools/vikunja-mcp/package.json tools/vikunja-mcp/package-lock.json /opt/vikunja-mcp/
RUN npm ci --prefix /opt/vikunja-mcp --omit=dev --no-audit --no-fund \
 && npm cache clean --force \
 && ln -s /opt/vikunja-mcp/node_modules/.bin/vikunja-mcp /usr/local/bin/vikunja-mcp \
 && command -v vikunja-mcp

LABEL org.opencontainers.image.title="WebGrip Vikunja MCP" \
    org.opencontainers.image.description="supergateway with @aimbitgmbh/vikunja-mcp baked in — streamable-HTTP Vikunja MCP with no npx-at-startup npm fetch" \
    org.opencontainers.image.source="https://forgejo.webgrip.dev/webgrip/infrastructure" \
    org.opencontainers.image.url="https://forgejo.webgrip.dev/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://forgejo.webgrip.dev/webgrip/infrastructure/src/branch/main/docs/techdocs" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${BASE_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

# Preserve supergateway's entrypoint; the k8s Deployment supplies the args
# (--stdio vikunja-mcp --outputTransport streamableHttp --port 8000 --stateful ...).
ENTRYPOINT ["supergateway"]
