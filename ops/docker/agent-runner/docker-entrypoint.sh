#!/usr/bin/env bash
# Entrypoint for the WebGrip OpenHands runner — the dark-factory build pod's inner command.
#
# Sets the metered-LiteLLM environment and a per-run x-litellm-trace-id, mints a per-run
# budgeted key (or uses a caller-supplied one), waits for the Docker sandbox, then runs
# OpenHands. Mirrors `.openhands/run-bronze.sh` in the erfbeeld repo.
#
#   # local: caller supplies the key
#   docker run --rm -e LLM_API_KEY=… webgrip/openhands-runner --headless -t "<task>"
#   # in-cluster: the pod supplies the master key; a per-run key is minted + revoked
#   … -e LITELLM_MASTER_KEY=… -e LITELLM_ADMIN_URL=http://litellm.ai.svc.cluster.local:4000
#
# Env:
#   LLM_MODEL           litellm_proxy/<model>        (default deepseek-chat)
#   LLM_BASE_URL        OpenAI-compatible proxy URL  (default https://litellm.webgrip.dev/v1)
#   LLM_API_KEY         caller-supplied key; if set, no minting happens
#   LITELLM_MASTER_KEY  admin key used to mint a per-run key when LLM_API_KEY is unset
#   LITELLM_ADMIN_URL   litellm admin base           (default: LLM_BASE_URL without /v1)
#   LITELLM_KEY_BUDGET  per-run max_budget in USD    (default 5)
#   LITELLM_KEY_DURATION per-run key TTL             (default 2h — also the revoke backstop)
#   LITELLM_KEY_MODELS  comma-separated model scope  (default: the LLM_MODEL model)
set -euo pipefail

export LLM_MODEL="${LLM_MODEL:-litellm_proxy/deepseek-chat}"
export LLM_BASE_URL="${LLM_BASE_URL:-https://litellm.webgrip.dev/v1}"
LITELLM_ADMIN_URL="${LITELLM_ADMIN_URL:-${LLM_BASE_URL%/v1}}"

# --- per-run trace id: required by the litellm agent key (400 without it) and the
# correlation id that joins this run to its spend/latency for #287/#288. Built without a
# pipe into `head` so `set -o pipefail` can't trip on SIGPIPE. ------------------------------
if [[ -z "${LLM_TRACE_ID:-}" ]]; then
  uuid="$(cat /proc/sys/kernel/random/uuid)"
  uuid="${uuid//-/}"
  LLM_TRACE_ID="openhands-$(date -u +%Y%m%dT%H%M%SZ)-${uuid:0:8}"
fi
export LLM_EXTRA_HEADERS="{\"x-litellm-trace-id\":\"${LLM_TRACE_ID}\"}"

# --- per-run key: caller-supplied wins; else mint from the master key + revoke on exit -----
MINTED_KEY=""
revoke_key() {
  [[ -n "${MINTED_KEY:-}" ]] || return 0
  if curl -sS -m 15 -X POST "${LITELLM_ADMIN_URL}/key/delete" \
       -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
       -H "x-litellm-trace-id: ${LLM_TRACE_ID}" \
       -H "Content-Type: application/json" \
       -d "{\"keys\":[\"${MINTED_KEY}\"]}" >/dev/null 2>&1; then
    echo "openhands-runner: revoked per-run key" >&2
  else
    echo "openhands-runner: WARN could not revoke per-run key (it expires via TTL)" >&2
  fi
}

if [[ -n "${LLM_API_KEY:-}" ]]; then
  echo "openhands-runner: using caller-supplied LLM_API_KEY (no minting)" >&2
elif [[ -n "${LITELLM_MASTER_KEY:-}" ]]; then
  key_model="${LLM_MODEL#litellm_proxy/}"; key_model="${key_model#openai/}"
  body="$(KEY_MODELS="${LITELLM_KEY_MODELS:-$key_model}" \
          BUDGET="${LITELLM_KEY_BUDGET:-5}" \
          DURATION="${LITELLM_KEY_DURATION:-2h}" \
          TRACE="${LLM_TRACE_ID}" \
          python3 -c '
import json, os
models = [m.strip() for m in os.environ["KEY_MODELS"].split(",") if m.strip()]
print(json.dumps({
    # key_alias is REQUIRED by the proxy's hardened /key/generate (400 without it —
    # run #31's failure). The per-run trace id is unique, which aliases must be.
    "key_alias": os.environ["TRACE"],
    "models": models,
    "max_budget": float(os.environ["BUDGET"]),
    "duration": os.environ["DURATION"],
    "metadata": {"source": "openhands-runner", "trace_id": os.environ["TRACE"]},
}))')"
  resp="$(curl -sS -m 30 -X POST "${LITELLM_ADMIN_URL}/key/generate" \
    -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    -H "x-litellm-trace-id: ${LLM_TRACE_ID}" \
    -H "Content-Type: application/json" \
    -d "${body}")" || { echo "openhands-runner: key mint request failed" >&2; exit 69; }
  MINTED_KEY="$(printf '%s' "${resp}" | python3 -c 'import json,sys
try:
    k = json.load(sys.stdin).get("key")
except Exception:
    k = None
if not k:
    sys.exit(1)
print(k)')" || { echo "openhands-runner: mint response had no key: ${resp:0:200}" >&2; exit 69; }
  export MINTED_KEY
  export LLM_API_KEY="${MINTED_KEY}"
  trap revoke_key EXIT
  echo "openhands-runner: minted per-run key (models=[${LITELLM_KEY_MODELS:-$key_model}] budget=${LITELLM_KEY_BUDGET:-5} ttl=${LITELLM_KEY_DURATION:-2h})" >&2
else
  echo "openhands-runner: no LLM_API_KEY and no LITELLM_MASTER_KEY — cannot authenticate." >&2
  exit 64
fi

echo "openhands-runner: model=${LLM_MODEL} base=${LLM_BASE_URL} trace-id=${LLM_TRACE_ID}" >&2
echo "openhands-runner: $(openhands --version 2>/dev/null | head -1)" >&2

# --- skills loadout (Slice E / #268) -------------------------------------------------------
# OpenHands self-registers any directory under $HOME/.openhands/skills/installed (its metadata
# file is self-healing), so delivery is a plain copy — no install API and no network for the
# baked core. Repo-committed skills (AGENTS.md, .openhands/skills/) are separate and always-on;
# these installed ones are progressive-disclosure, which is what we want for a loadout.
SKILLS_DIR="${HOME:-/root}/.openhands/skills/installed"
mkdir -p "${SKILLS_DIR}"
if [[ -d /opt/webgrip/skills ]]; then
  cp -r /opt/webgrip/skills/. "${SKILLS_DIR}/" 2>/dev/null || true
fi
# Per-ticket extras: the dispatcher sets OPENHANDS_SKILLS_PROFILE (comma-separated) from the
# ticket's labels. Failure here is never fatal — the baked core still applies.
if [[ -n "${OPENHANDS_SKILLS_PROFILE:-}" ]]; then
  echo "openhands-runner: adding profile skills: ${OPENHANDS_SKILLS_PROFILE}" >&2
  _skills_tmp="$(mktemp -d)"
  if git clone --depth 1 --branch "${OPENHANDS_SKILLS_REF:-main}" \
       "${OPENHANDS_SKILLS_REPO:?OPENHANDS_SKILLS_REPO unset}" "${_skills_tmp}" >/dev/null 2>&1; then
    IFS=',' read -ra _want <<< "${OPENHANDS_SKILLS_PROFILE}"
    for _s in "${_want[@]}"; do
      _s="${_s// /}"
      [[ -z "${_s}" ]] && continue
      if [[ -d "${_skills_tmp}/skills/${_s}" ]]; then
        cp -r "${_skills_tmp}/skills/${_s}" "${SKILLS_DIR}/" && echo "  + ${_s}" >&2
      else
        echo "  WARN profile skill '${_s}' not in the marketplace — skipped" >&2
      fi
    done
  else
    echo "openhands-runner: WARN could not clone the skills repo; continuing with baked core" >&2
  fi
  rm -rf "${_skills_tmp}"
fi
echo "openhands-runner: skills available: $(ls -1 "${SKILLS_DIR}" 2>/dev/null | tr '\n' ' ')" >&2

# If a Docker sandbox host is wired (the in-cluster DinD sidecar sets DOCKER_HOST), wait for
# the daemon so OpenHands' runtime init doesn't race the sidecar's startup. Skipped when
# DOCKER_HOST is unset (e.g. local runs with an ambient daemon). Never fatal.
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

# Not `exec` — OpenHands runs as a child so the EXIT trap can revoke the minted key when it
# finishes (or errors). A hard kill (SIGKILL/eviction) skips the trap; the key's TTL is the
# backstop. --override-with-envs makes OpenHands read LLM_* (incl. LLM_EXTRA_HEADERS).
openhands --override-with-envs "$@"
