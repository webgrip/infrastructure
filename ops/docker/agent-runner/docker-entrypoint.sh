#!/usr/bin/env bash
# Entrypoint for the WebGrip OpenHands runner — the dark-factory build pod's inner command.
#
# Sets the metered-LiteLLM environment and a per-run x-litellm-trace-id, mints a per-run
# budgeted key (or uses a caller-supplied one), then runs OpenHands. Daemonless
# (homelab-cluster ADR-0053): no docker CLI, no sandbox wait — the agent edits code and
# opens a PR, and gates run in CI. Mirrors `.openhands/run-bronze.sh`. The key lifecycle
# (mint → run → revoke) is the same contract as code14's agent-runner and uses the same
# `litellm-key` helper — keys and the master key travel in the environment, never argv,
# so nothing the agent can read in /proc ever contains one.
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
set -Eeuo pipefail

export LLM_MODEL="${LLM_MODEL:-litellm_proxy/deepseek-chat}"
export LLM_BASE_URL="${LLM_BASE_URL:-https://litellm.webgrip.dev/v1}"

# Exported, not plain locals: `litellm-key` is a separate process and reads all of its
# inputs from the environment. A default applied here but left unexported would reach
# the helper as "unset" and it would refuse to run.
export LITELLM_ADMIN_URL="${LITELLM_ADMIN_URL:-${LLM_BASE_URL%/v1}}"
export LITELLM_KEY_BUDGET="${LITELLM_KEY_BUDGET:-5}"
export LITELLM_KEY_DURATION="${LITELLM_KEY_DURATION:-2h}"
key_model="${LLM_MODEL#litellm_proxy/}"; key_model="${key_model#openai/}"
export LITELLM_KEY_MODELS="${LITELLM_KEY_MODELS:-${key_model}}"
export LITELLM_KEY_SOURCE=openhands-runner

log() { printf '%s openhands-runner: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }

# --- per-run trace id: required by the litellm agent key (400 without it) and the
# correlation id that joins this run to its spend/latency for #287/#288. Built without a
# pipe into `head` so `set -o pipefail` can't trip on SIGPIPE. ------------------------------
if [[ -z "${LLM_TRACE_ID:-}" ]]; then
  uuid="$(cat /proc/sys/kernel/random/uuid)"
  uuid="${uuid//-/}"
  LLM_TRACE_ID="openhands-$(date -u +%Y%m%dT%H%M%SZ)-${uuid:0:8}"
fi
export LLM_EXTRA_HEADERS="{\"x-litellm-trace-id\":\"${LLM_TRACE_ID}\"}"
# litellm-key stamps the same id on the mint/revoke admin calls, so they join the run too.
export LITELLM_TRACE_ID="${LLM_TRACE_ID}"

# --- per-run key: caller-supplied wins; else mint from the master key + revoke on exit -----
minted_key=""
revoke_key() {
  [[ -n "${minted_key}" ]] || return 0
  # The key travels in the environment, never in argv: revoke_key runs from an EXIT
  # trap in a container the agent itself can read /proc in.
  if LITELLM_REVOKE_KEY="${minted_key}" litellm-key revoke; then
    log "revoked per-run key (alias ${LLM_TRACE_ID})"
  else
    # Deliberately not fatal: the run's real outcome matters more than the revoke,
    # and the key carries both a budget and a TTL as backstops.
    log "WARN could not revoke per-run key (alias ${LLM_TRACE_ID}) — it expires in ${LITELLM_KEY_DURATION}"
  fi
}

if [[ -n "${LLM_API_KEY:-}" ]]; then
  log "using caller-supplied LLM_API_KEY (mint/revoke owned by the caller)"
elif [[ -n "${LITELLM_MASTER_KEY:-}" ]]; then
  # litellm-key reports its own failures to stderr and exits non-zero; the only thing
  # on stdout is the key. `set -e` does not fire inside a tested command substitution,
  # hence the explicit `if !`.
  if ! minted_key="$(LITELLM_KEY_ALIAS="${LLM_TRACE_ID}" litellm-key mint)"; then
    log "ERROR could not mint a per-run key (see the error above)"
    exit 69
  fi
  export LLM_API_KEY="${minted_key}"
  trap revoke_key EXIT
  log "minted per-run key (models=[${LITELLM_KEY_MODELS}] budget=${LITELLM_KEY_BUDGET} ttl=${LITELLM_KEY_DURATION})"
else
  log "ERROR no LLM_API_KEY and no LITELLM_MASTER_KEY — cannot authenticate."
  exit 64
fi

log "model=${LLM_MODEL} base=${LLM_BASE_URL} trace-id=${LLM_TRACE_ID}"
# Baked at image build — invoking `openhands --version` here cold-imports the whole
# CLI tree (2m20s at the in-cluster CPU limit). Fallback covers pre-bake images.
log "$(cat /etc/openhands-version 2>/dev/null || openhands --version 2>/dev/null | head -1)"

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
  log "adding profile skills: ${OPENHANDS_SKILLS_PROFILE}"
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
    log "WARN could not clone the skills repo; continuing with baked core"
  fi
  rm -rf "${_skills_tmp}"
fi
log "skills available: $(ls -1 "${SKILLS_DIR}" 2>/dev/null | tr '\n' ' ')"

# --- run -----------------------------------------------------------------------------------
# Deliberately NOT `exec`, and deliberately not a plain foreground child either. Two
# things must both be true, and each of the simpler shapes gives only one:
#
#   - the agent must receive SIGTERM promptly. bash as PID 1 does not forward signals,
#     and it runs traps only AFTER a foreground child exits — so a foreground openhands
#     would never hear the pod's TERM, spend the whole grace period oblivious, and be
#     SIGKILLed mid-write (with the EXIT trap never firing and the key living to TTL);
#   - the per-run key must be revoked when the run ends, and an EXIT trap cannot
#     survive exec — the shell is replaced, so the trap is discarded.
#
# Backgrounding the agent and waiting keeps both: the TERM/INT trap forwards the signal
# to the real process, `wait` returns its status, and the EXIT trap still revokes. A hard
# kill (SIGKILL/eviction) still skips the trap; the key's TTL is the backstop.
# --override-with-envs makes OpenHands read LLM_* (incl. LLM_EXTRA_HEADERS).
openhands --override-with-envs "$@" &
agent_pid=$!

forward_signal() {
  log "forwarding $1 to agent (pid ${agent_pid})"
  kill "-$1" "${agent_pid}" 2>/dev/null || true
}
trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT

# `wait` is interrupted by a trapped signal and must be retried, or a SIGTERM would
# return here immediately and revoke the key while the agent is still shutting down.
rc=0
while :; do
  if wait "${agent_pid}"; then rc=0; else rc=$?; fi
  # 128+n means wait itself was interrupted by signal n; the child lives on.
  if (( rc > 128 )) && kill -0 "${agent_pid}" 2>/dev/null; then
    continue
  fi
  break
done

log "agent exited rc=${rc}"
exit "${rc}"
