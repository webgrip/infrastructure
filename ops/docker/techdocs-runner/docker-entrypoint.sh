#!/usr/bin/env bash

set -e

techdocs-cli generate \
    --no-docker \
    --verbose \
    --source-dir /docs \
    --output-dir /tmp/techdocs-site
