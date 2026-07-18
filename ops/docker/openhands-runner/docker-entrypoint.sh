#!/usr/bin/env bash
# Entrypoint for the WebGrip OpenHands runner — the dark-factory build pod's inner command.
#
# Sets the metered-LiteLLM environment and a per-run x-litellm-trace-id, then hands off to
# OpenHands. Mirrors `.openhands/run-bronze.sh` in the erfbeeld repo so local and in-cluster
# runs share one shape.
#
#   docker run --rm -e LLM_API_KEY=… webgrip/openhands-runner --headless -t "<task>"
#
# Slice A: the caller provides LLM_API_KEY. Slice D mints a per-run, budget-capped key from
# LITELLM_MASTER_KEY via /key/generate and revokes it on exit.
set -euo pipefail

export LLM_MODEL="${LLM_MODEL:-litellm_proxy/deepseek-chat}"
export LLM_BASE_URL="${LLM_BASE_URL:-https://litellm.webgrip.dev/v1}"

if [[ -z "${LLM_API_KEY:-}" ]]; then
  echo "openhands-runner: LLM_API_KEY is not set — Slice A expects a caller-provided key" \
       "(per-run minting from LITELLM_MASTER_KEY arrives in Slice D)." >&2
  exit 64
fi

# Per-run trace id: the LiteLLM agent key rejects requests without x-litellm-trace-id
# (HTTP 400), and the same id is the correlation key joining this run to its LiteLLM
# spend/latency for the dark-factory dashboards (#287/#288). Built without a pipe into
# `head` so `set -o pipefail` can't trip on SIGPIPE.
if [[ -z "${LLM_TRACE_ID:-}" ]]; then
  uuid="$(cat /proc/sys/kernel/random/uuid)"
  uuid="${uuid//-/}"
  LLM_TRACE_ID="openhands-$(date -u +%Y%m%dT%H%M%SZ)-${uuid:0:8}"
fi
export LLM_EXTRA_HEADERS="{\"x-litellm-trace-id\":\"${LLM_TRACE_ID}\"}"

echo "openhands-runner: model=${LLM_MODEL} base=${LLM_BASE_URL} trace-id=${LLM_TRACE_ID}" >&2
echo "openhands-runner: $(openhands --version 2>/dev/null | head -1)" >&2

# If a Docker sandbox host is wired (the in-cluster DinD sidecar sets DOCKER_HOST), wait for
# the daemon so OpenHands' runtime init doesn't race the sidecar's startup. Skipped when
# DOCKER_HOST is unset (e.g. local runs with an ambient daemon). Never fatal — warn and let
# OpenHands surface a clear error if the daemon truly never comes up.
if [[ -n "${DOCKER_HOST:-}" ]]; then
  echo "openhands-runner: waiting for docker daemon at ${DOCKER_HOST}…" >&2
  for i in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
      echo "openhands-runner: docker daemon ready ($(docker version --format '{{.Server.Version}}' 2>/dev/null))" >&2
      break
    fi
    if [[ $i -eq 30 ]]; then
      echo "openhands-runner: WARN docker daemon not ready after 30s; continuing" >&2
    fi
    sleep 1
  done
fi

# --override-with-envs makes OpenHands read LLM_* (incl. LLM_EXTRA_HEADERS) from the env above.
exec openhands --override-with-envs "$@"
