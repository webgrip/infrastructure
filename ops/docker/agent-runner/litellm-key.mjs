#!/usr/bin/env node
// litellm-key — mint and revoke the per-run LiteLLM key for one agent run.
//
// SHARED FILE — byte-identical to the webgrip twin at
// webgrip/infrastructure/ops/docker/agent-runner/litellm-key.mjs. The harnesses
// differ (Claude Code there vs OpenHands here — and vice versa), the key
// lifecycle does not. Edit both copies or edit neither.
//
// WHY THIS IS NODE AND NOT curl
// -----------------------------
// These two admin calls were the ONLY reason the image carried an HTTP client.
// The `curl` package was also the single largest source of findings in the CVE
// budget (8 critical / 9 high at 8.20.0-r0, every one `fix=unknown` because
// that is the newest build Alpine 3.23 ships). Node 24 has a global `fetch`,
// so the runtime this image already exists to provide can make the calls and
// the package can go. See the Dockerfile header.
//
// Usage — both subcommands read their inputs from the environment, never argv,
// so a key never appears in the process list:
//
//   litellm-key mint      -> writes the minted key to stdout, diagnostics to stderr
//   litellm-key revoke    -> revokes $LITELLM_REVOKE_KEY
//
// Env (shared): LITELLM_ADMIN_URL, LITELLM_MASTER_KEY
//               LITELLM_TRACE_ID (optional) — stamped on the admin calls as
//               x-litellm-trace-id, so the mint and the revoke appear in the
//               proxy's request log as part of the run they belong to
//      mint:    LITELLM_KEY_ALIAS, LITELLM_KEY_BUDGET, LITELLM_KEY_DURATION,
//               LITELLM_KEY_MODELS (comma-separated),
//               LITELLM_KEY_SOURCE (optional) — metadata.source on the minted
//               key, default "agent-runner"
//      revoke:  LITELLM_REVOKE_KEY

const die = (msg) => {
  process.stderr.write(`litellm-key: ${msg}\n`);
  process.exit(1);
};

const env = (name) => {
  const value = process.env[name];
  if (!value) die(`${name} is not set`);
  return value;
};

// One place that knows how to talk to the admin API, so mint and revoke cannot
// drift on timeout, auth header or error reporting. The body is returned on a
// non-2xx rather than thrown away: "which field did LiteLLM reject" is the only
// question worth answering when a mint fails, and a bare status code does not
// answer it.
async function admin(path, body, timeoutMs) {
  const base = env('LITELLM_ADMIN_URL').replace(/\/+$/, '');
  const headers = {
    authorization: `Bearer ${env('LITELLM_MASTER_KEY')}`,
    'content-type': 'application/json',
  };
  // The same trace id the run stamps on its completions; with it, the mint and
  // the revoke are attributable to the run rather than being anonymous admin
  // traffic.
  if (process.env.LITELLM_TRACE_ID) headers['x-litellm-trace-id'] = process.env.LITELLM_TRACE_ID;
  let response;
  try {
    response = await fetch(`${base}${path}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (err) {
    // A DNS failure, a refused connection and a timeout all land here, and the
    // three have very different fixes. undici reports every one of them as a
    // bare `TypeError: fetch failed` and puts the actual reason (ENOTFOUND,
    // ECONNREFUSED, …) in `.cause`, so unwrapping it is the difference between
    // a log line worth reading and one that is not.
    const cause = err.cause ? ` (${err.cause.code ?? err.cause.name}: ${err.cause.message})` : '';
    die(`POST ${base}${path} failed: ${err.name}: ${err.message}${cause}`);
  }
  const text = await response.text();
  if (!response.ok) die(`POST ${base}${path} returned HTTP ${response.status}: ${text}`);
  return text;
}

const command = process.argv[2];

if (command === 'mint') {
  // The proxy in this estate sets key_generation_settings.required_params:
  // ["key_alias"], so a mint WITHOUT an alias is rejected with a 400. The alias
  // is also the trace id that joins this run to its spend rows in the ledger.
  const models = env('LITELLM_KEY_MODELS')
    .split(',')
    .map((m) => m.trim())
    .filter(Boolean);
  if (models.length === 0) die('LITELLM_KEY_MODELS resolved to an empty model list');

  // NaN would serialize to null, and a null max_budget is an UNBUDGETED key —
  // the exact thing this helper exists to prevent. Refuse it before the call.
  const budget = Number(env('LITELLM_KEY_BUDGET'));
  if (Number.isNaN(budget)) die(`LITELLM_KEY_BUDGET is not a number: ${env('LITELLM_KEY_BUDGET')}`);

  const alias = env('LITELLM_KEY_ALIAS');
  const text = await admin(
    '/key/generate',
    {
      key_alias: alias,
      max_budget: budget,
      duration: env('LITELLM_KEY_DURATION'),
      models,
      // Attribution beyond the alias: every ledger row for a completion made
      // with this key carries which runner minted it and for which run.
      metadata: {
        source: process.env.LITELLM_KEY_SOURCE || 'agent-runner',
        trace_id: alias,
      },
    },
    30_000,
  );

  let key;
  try {
    key = JSON.parse(text).key;
  } catch {
    die(`key mint returned a body that is not JSON: ${text}`);
  }
  // Fail here rather than later. Without a key the agent would start, fail every
  // completion, and burn the ticket's whole lease looking like a model problem
  // rather than an auth one.
  if (!key) die(`key mint returned no key. Response: ${text}`);
  process.stdout.write(key);
} else if (command === 'revoke') {
  await admin('/key/delete', { keys: [env('LITELLM_REVOKE_KEY')] }, 15_000);
} else {
  die(`unknown command ${command ?? '(none)'} — expected "mint" or "revoke"`);
}
