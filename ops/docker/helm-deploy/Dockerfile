FROM alpine:3.21.3

LABEL maintainer="Ryan Grippeling <ryan@vendic.nl>"

RUN apk add --no-cache \
    ca-certificates \
    curl \
    wget \
    git \
    bash \
    tar \
    gnupg \
    lsb-release \
    openssl

ARG KUBECTL_VERSION="v1.32.2"
RUN if [ "$KUBECTL_VERSION" = "latest" ]; then \
      curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
    else \
      curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    fi && \
    install -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

ARG HELM_VERSION="3.17.1"
RUN if [ "$HELM_VERSION" = "latest" ]; then \
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -; \
    else \
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --version v${HELM_VERSION}; \
    fi

ARG DO_CLI_VERSION="1.123.0"
RUN curl -fsSL "https://github.com/digitalocean/doctl/releases/download/v${DO_CLI_VERSION}/doctl-${DO_CLI_VERSION}-linux-amd64.tar.gz" \
    | tar -xz && \
    mv doctl /usr/local/bin/

ARG YQ_VERSION="4.45.1"
RUN wget -q "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" -O /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

ARG SOPS_VERSION="3.7.3"
RUN wget -q "https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" -O /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops

WORKDIR /workspace

CMD ["bash"]
