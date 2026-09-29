# syntax=docker/dockerfile:1.7
ARG REGISTRY_DHI=harbor.webgrip.dev/dhi
ARG BUILD_IMAGE=${REGISTRY_DHI}/python:3.12-debian13-dev@sha256:d18c63b540914a6584f731ab1a4ffe45b6ec8a01aae66c07ae7bbe94b0adb2e7
ARG BASE_IMAGE=${REGISTRY_DHI}/python:3.12-debian13@sha256:1bab11a972258285639bebc02b334326c7bdfc1740fb438540728a4f3f896235

FROM ${BUILD_IMAGE} AS build

ARG TORCH_VERSION=2.14.0
ARG LAYA_VERSION=0.3.22
ARG LAYA_MODEL_REVISION=55cf4c4ebb4ebe31b2550e8bdf3bd21b99753851

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/opt/hf \
    HF_HUB_DISABLE_TELEMETRY=1

RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install "torch==${TORCH_VERSION}" --index-url https://download.pytorch.org/whl/cpu \
 && /opt/venv/bin/pip install "laya[serve]==${LAYA_VERSION}"

RUN /opt/venv/bin/python -c "import laya; laya.load('convaiinnovations/laya', subfolder='typed-decisions', device='cpu', revision='${LAYA_MODEL_REVISION}')" \
 && chmod -R a+rX /opt/hf

FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_VERSION=dev
ARG IMAGE_REVISION=unknown
ARG LAYA_MODEL_REVISION=55cf4c4ebb4ebe31b2550e8bdf3bd21b99753851

COPY --from=build /opt/venv /opt/venv
COPY --from=build /opt/hf /opt/hf

ENV PATH=/opt/venv/bin:${PATH} \
    HF_HOME=/opt/hf \
    HF_HUB_OFFLINE=1 \
    HF_HUB_DISABLE_TELEMETRY=1 \
    LAYA_DEVICE=cpu \
    LAYA_MODELS=typed-decisions \
    LAYA_MAX_LOADED=1 \
    LAYA_PRELOAD=1 \
    LAYA_REVISION=${LAYA_MODEL_REVISION} \
    LAYA_HOST=0.0.0.0 \
    LAYA_PORT=8000

LABEL org.opencontainers.image.title="WebGrip Laya Serve" \
    org.opencontainers.image.description="laya-serve with the Laya typed-decisions checkpoint baked in at a pinned revision; a CPU classifier that speaks the Jev /v1/systemone API, offline at runtime" \
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

EXPOSE 8000

ENTRYPOINT ["laya-serve"]
