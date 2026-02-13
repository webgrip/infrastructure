ARG BASE_IMAGE=alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659
FROM ${BASE_IMAGE}

RUN apk add --no-cache docker git bash curl

ARG ACT_VERSION=latest

RUN if [ "$ACT_VERSION" = "latest" ]; then \
        curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin; \
    else \
        curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin -- -d v${ACT_VERSION}; \
    fi

WORKDIR /workspace

LABEL org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
	org.opencontainers.image.description="Container with nektos/act for local GitHub Actions simulation" \
	org.opencontainers.image.base.name="${BASE_IMAGE}" \
	org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["act"]
