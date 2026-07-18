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

# --override-with-envs makes OpenHands read LLM_* (incl. LLM_EXTRA_HEADERS) from the env above.
exec openhands --override-with-envs "$@"
