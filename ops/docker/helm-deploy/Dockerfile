# ADR-0006 Stage 2: Docker Hardened Images base. The -dev variant on purpose — this image
# installs its toolset with apk and its job is running shell pipelines (helm/kubectl/sops)
# against the cluster, so the shell-less runtime variant cannot carry it. Same Alpine lineage;
# apk behaves identically. This is also the image whose credentials can deploy to the cluster —
# exactly where a continuously-rebuilt, advisory-tracked, signed base earns its keep.
#
# BUILD PREREQUISITE: the `dhi` Harbor proxy project (homelab-cluster ADR-0023) — dhi.io refuses
# anonymous pulls, so unlike the other REGISTRY_* ARGs this one DEFAULTS to the proxy.
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
# renovate: datasource=docker depName=dhi.io/alpine-base versioning=docker
ARG BASE_IMAGE=${REGISTRY_DHI}/alpine-base:3.24-dev@sha256:7182e0bc2f186386bb23bc0718508913450ba1876e93cf07e5e3cf263c4dbb63
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

# DHI alpine-base ships no /usr/local/bin (stock alpine does); every tool below lands there.
RUN install -d /usr/local/bin

# Every tool below: version-pinned download, published checksum verified before install — the
# pattern ci-runner adopted in #88. Previously all five installed UNVERIFIED, and this image's
# whole job is holding credentials that can deploy to the cluster; a tampered kubectl or sops
# here is a cluster compromise. The never-exercised 'latest' branches are gone with it: the
# pinned path is now the only path. A Renovate version bump without its checksum fails the
# build rather than shipping unverified.
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION="v1.37.2"
ARG KUBECTL_SHA256="c04487523e7aa7d1493f7808174c899db93d7a9cf57531420cd76b9bd415f8f4"
RUN curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    echo "${KUBECTL_SHA256}  kubectl" | sha256sum -c - && \
    install -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Direct release tarball, not `curl | bash` of get-helm-3 from helm's master branch.
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION="3.22.1"
ARG HELM_SHA256="896cf63684a42a723d61c980369d6e588330927deb13676ca0d85006dd6da0ea"
RUN curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    echo "${HELM_SHA256}  helm-v${HELM_VERSION}-linux-amd64.tar.gz" | sha256sum -c - && \
    tar -xzf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    install -m 0755 linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 "helm-v${HELM_VERSION}-linux-amd64.tar.gz"

# renovate: datasource=github-releases depName=digitalocean/doctl
ARG DO_CLI_VERSION="1.186.0"
ARG DO_CLI_SHA256="a36f2ae5e672160c3a20ab46e8cef79c9b24e8055417f4beb790a897c532d241"
RUN curl -fsSL -o doctl.tar.gz "https://github.com/digitalocean/doctl/releases/download/v${DO_CLI_VERSION}/doctl-${DO_CLI_VERSION}-linux-amd64.tar.gz" && \
    echo "${DO_CLI_SHA256}  doctl.tar.gz" | sha256sum -c - && \
    tar -xzf doctl.tar.gz && \
    mv doctl /usr/local/bin/ && \
    rm doctl.tar.gz

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION="4.54.1"
ARG YQ_SHA256="8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f"
RUN wget -q "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" -O /usr/local/bin/yq && \
    echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum -c - && \
    chmod +x /usr/local/bin/yq

# getsops/sops — the project moved out of mozilla/; the old org redirects today and will not
# forever.
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION="3.13.3"
ARG SOPS_SHA256="e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b"
RUN wget -q "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" -O /usr/local/bin/sops && \
    echo "${SOPS_SHA256}  /usr/local/bin/sops" | sha256sum -c - && \
    chmod +x /usr/local/bin/sops

RUN kubectl version --client && helm version && doctl version && yq --version && sops --version

WORKDIR /workspace

CMD ["bash"]
