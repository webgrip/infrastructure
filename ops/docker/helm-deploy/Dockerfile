# Release re-entry touch: run 135 dropped this train (npm 404); the matrix is push-diff.
ARG REGISTRY_DOCKERHUB=docker.io
ARG BASE_IMAGE=${REGISTRY_DOCKERHUB}/library/alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11
FROM ${BASE_IMAGE}

ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

LABEL org.opencontainers.image.title="WebGrip Helm Deploy" \
  org.opencontainers.image.description="Helm + kubectl + auxiliary tooling for deployments" \
  org.opencontainers.image.source="https://github.com/webgrip/infrastructure" \
  org.opencontainers.image.url="https://github.com/webgrip/infrastructure" \
  org.opencontainers.image.documentation="https://github.com/webgrip/infrastructure/tree/main/docs/techdocs" \
  org.opencontainers.image.vendor="WebGrip" \
  org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.base.name="${BASE_IMAGE}" \
  org.opencontainers.image.created="${IMAGE_CREATED}" \
  org.opencontainers.image.version="${IMAGE_VERSION}" \
  org.opencontainers.image.revision="${IMAGE_REVISION}"

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

# Every tool below: version-pinned download, published checksum verified before install — the
# pattern ci-runner adopted in #88. Previously all five installed UNVERIFIED, and this image's
# whole job is holding credentials that can deploy to the cluster; a tampered kubectl or sops
# here is a cluster compromise. The never-exercised 'latest' branches are gone with it: the
# pinned path is now the only path. A Renovate version bump without its checksum fails the
# build rather than shipping unverified.
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION="v1.34.0"
ARG KUBECTL_SHA256="cfda68cba5848bc3b6c6135ae2f20ba2c78de20059f68789c090166d6abc3e2c"
RUN curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    echo "${KUBECTL_SHA256}  kubectl" | sha256sum -c - && \
    install -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Direct release tarball, not `curl | bash` of get-helm-3 from helm's master branch.
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION="3.18.6"
ARG HELM_SHA256="3f43c0aa57243852dd542493a0f54f1396c0bc8ec7296bbb2c01e802010819ce"
RUN curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    echo "${HELM_SHA256}  helm-v${HELM_VERSION}-linux-amd64.tar.gz" | sha256sum -c - && \
    tar -xzf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    install -m 0755 linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 "helm-v${HELM_VERSION}-linux-amd64.tar.gz"

# renovate: datasource=github-releases depName=digitalocean/doctl
ARG DO_CLI_VERSION="1.141.0"
ARG DO_CLI_SHA256="72045e8e6fc16a5e52eaf3ceef8c5cbe92f6ba2d02e3ed79996f3125f4efd932"
RUN curl -fsSL -o doctl.tar.gz "https://github.com/digitalocean/doctl/releases/download/v${DO_CLI_VERSION}/doctl-${DO_CLI_VERSION}-linux-amd64.tar.gz" && \
    echo "${DO_CLI_SHA256}  doctl.tar.gz" | sha256sum -c - && \
    tar -xzf doctl.tar.gz && \
    mv doctl /usr/local/bin/ && \
    rm doctl.tar.gz

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION="4.47.1"
ARG YQ_SHA256="0fb28c6680193c41b364193d0c0fc4a03177aecde51cfc04d506b1517158c2fb"
RUN wget -q "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" -O /usr/local/bin/yq && \
    echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum -c - && \
    chmod +x /usr/local/bin/yq

# getsops/sops — the project moved out of mozilla/; the old org redirects today and will not
# forever.
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION="3.10.2"
ARG SOPS_SHA256="79b0f844237bd4b0446e4dc884dbc1765fc7dedc3968f743d5949c6f2e701739"
RUN wget -q "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" -O /usr/local/bin/sops && \
    echo "${SOPS_SHA256}  /usr/local/bin/sops" | sha256sum -c - && \
    chmod +x /usr/local/bin/sops

RUN kubectl version --client && helm version && doctl version && yq --version && sops --version

WORKDIR /workspace

CMD ["bash"]
