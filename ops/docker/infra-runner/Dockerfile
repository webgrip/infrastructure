# syntax=docker/dockerfile:1
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
# renovate: datasource=docker depName=dhi.io/node versioning=docker
ARG NODE_IMAGE=${REGISTRY_DHI}/node:24.22.1-alpine3.24-dev@sha256:c7999456f9380ed100bb430baeb4fdbf4fec59c51d3bab2b0bd3ea77a44e3677

FROM ${NODE_IMAGE}

ARG NODE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown

SHELL ["/bin/sh", "-euo", "pipefail", "-c"]

RUN apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      curl \
      git \
      jq \
      openssh-client \
      tar \
 && apk del --no-cache npm yarn corepack \
 && deluser --remove-home node \
 && addgroup -g 1000 runner \
 && adduser -D -u 1000 -G runner -h /home/runner -s /bin/bash runner \
 && install -d -m 0755 /usr/local/bin

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# renovate: datasource=github-releases depName=opentofu/opentofu
ARG TOFU_VERSION=1.13.2
ARG TOFU_SHA256=ac05d9952662c7db28dd57e93f0a68018837bfdf9342384ec0987977c16a9645
RUN archive="/tmp/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
 && curl -fsSL -o "${archive}" "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
 && echo "${TOFU_SHA256}  ${archive}" | sha256sum -c - \
 && tar -xzf "${archive}" -C /tmp tofu \
 && install -m 0755 /tmp/tofu /usr/local/bin/tofu \
 && rm -f "${archive}" /tmp/tofu

# renovate: datasource=github-releases depName=FiloSottile/age
ARG AGE_VERSION=1.3.2
ARG AGE_SHA256=cbe24006683f8eb669266162894b9a522a1af52f2665fbc63a4bb032ed26ac10
RUN archive="/tmp/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
 && curl -fsSL -o "${archive}" "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
 && echo "${AGE_SHA256}  ${archive}" | sha256sum -c - \
 && tar -xzf "${archive}" -C /tmp age/age age/age-keygen \
 && install -m 0755 /tmp/age/age /tmp/age/age-keygen /usr/local/bin/ \
 && rm -rf "${archive}" /tmp/age

# renovate: datasource=github-releases depName=etcd-io/etcd
ARG ETCD_VERSION=3.7.3
ARG ETCD_SHA256=5dfa9cc3b3ce3b4b491fbcc2057d3daa166bcc6676f743fcd20f8e5760cb9775
RUN archive="/tmp/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" \
 && unpacked="/tmp/etcd-v${ETCD_VERSION}-linux-amd64" \
 && curl -fsSL -o "${archive}" "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" \
 && echo "${ETCD_SHA256}  ${archive}" | sha256sum -c - \
 && tar -xzf "${archive}" -C /tmp \
 && install -m 0755 "${unpacked}/etcd" "${unpacked}/etcdctl" "${unpacked}/etcdutl" /usr/local/bin/ \
 && rm -rf "${archive}" "${unpacked}"

LABEL org.opencontainers.image.title="WebGrip Infra Runner" \
    org.opencontainers.image.description="Hardened OpenTofu, age and etcd toolchain for infrastructure CI jobs that hold production credentials" \
    org.opencontainers.image.source="https://forgejo.webgrip.dev/webgrip/infrastructure" \
    org.opencontainers.image.url="https://forgejo.webgrip.dev/webgrip/infrastructure" \
    org.opencontainers.image.documentation="https://forgejo.webgrip.dev/webgrip/infrastructure/src/branch/main/docs/techdocs/docs/general/docker-images/infra-runner.md" \
    org.opencontainers.image.vendor="WebGrip" \
    org.opencontainers.image.authors="Ryan Grippeling <ryan@webgrip.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.base.name="${NODE_IMAGE}" \
    org.opencontainers.image.created="${IMAGE_CREATED}" \
    org.opencontainers.image.version="${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}"

ENV HOME=/home/runner
WORKDIR /home/runner
USER 1000

RUN node --version \
 && tofu version \
 && age --version \
 && age-keygen --version \
 && etcd --version \
 && etcdctl version \
 && etcdutl version \
 && bash --version | head -n 1 \
 && curl --version | head -n 1 \
 && jq --version \
 && ssh -V \
 && git --version \
 && date --version | head -n 1 \
 && tar --version | head -n 1 \
 && test "$(id -u):$(id -g)" = "1000:1000" \
 && test -w "${HOME}"

CMD ["bash"]
