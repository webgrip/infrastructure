FROM ghcr.io/actions/actions-runner:latest AS base

USER root

RUN apt-get update && apt-get install -y \
    curl \
    jq \
    git \
    unzip \
    rsync \
    && apt-get clean

LABEL maintainer="Ryan Grippeling <ryan@webgrip.nl>"

USER runner
