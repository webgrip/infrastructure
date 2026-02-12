ARG BASE_IMAGE=alpine:3.22.1
FROM ${BASE_IMAGE}

# Install dependencies needed by ACT
RUN apk add --no-cache docker git bash curl

ARG ACT_VERSION=latest
# Download and install ACT binary (Renovate can manage ACT_VERSION via regex manager)
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
