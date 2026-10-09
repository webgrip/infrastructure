# Agent Runner

The image an unattended agent Run executes in. Glide's Ploeg workers start it (as
`executor.runnerImage`), and the pod runs it as uid 65532 with no network beyond the model
gateway. This page covers the agent tools baked into it. The reasons behind the rest of the
Dockerfile (DHI Alpine base, no language toolchains, no docker client) are in
[ADR-0006](https://forgejo.webgrip.dev/webgrip/infrastructure/src/branch/main/docs/adrs/0006-hardened-base-images.md) and homelab-cluster ADR-0053.

| Property | Value |
|----------|-------|
| **Base image** | `dhi.io/python:3.12.13-alpine3.24-dev`, through the Harbor `dhi` proxy |
| **Architecture** | `linux/amd64` (the Goose stage also resolves for `linux/arm64`) |
| **Registry** | `harbor.webgrip.dev/webgrip/agent-runner` |
| **Dockerfile** | [`ops/docker/agent-runner/Dockerfile`](../../../../../ops/docker/agent-runner/Dockerfile) |

## Agent tools

| Tool | Version | Source | Started as |
|------|---------|--------|------------|
| OpenHands CLI | 1.16.0 | PyPI via `uv tool install` | `openhands` (the entrypoint) |
| OpenSpec | 1.6.0 | npm `@fission-ai/openspec` | `openspec instructions apply …`, `openspec validate … --strict` |
| Qwen Code | 0.24.6 | npm `@qwen-code/qwen-code` | `qwen --acp --auth-type=openai` |
| Goose | 1.52.0 | GitHub release `goose-<arch>-unknown-linux-musl.tar.gz` | `goose acp` |
| moon | 2.4.4 | npm `@moonrepo/cli` | `moon` |
| Node.js | 24.19.0 | copied from `dhi.io/node` | runtime for the npm tools |

Qwen Code and Goose are the agents behind Ploeg's `qwen-code` and `goose` ACP profiles. The
command lines and environment each profile sets are in Glide's
`apps/ploeg/docs/contracts/acp-profiles.md`. Ploeg does not install agents, so a profile only
works in an image that has its binary on `PATH`.

Every tool gets its own version check during the build: `qwen --version` has to print exactly
`QWEN_CODE_VERSION`, and `goose --version` has to contain `GOOSE_VERSION`. A release that
renames or breaks a binary therefore fails the build, and a Run never sees it.

### Pinning and bumping

- The npm tools are pinned with an exact version in an `ARG`, each with a `# renovate:`
  annotation.
- Goose is a downloaded archive, so it has a SHA-256 per architecture as well as the version.
  BuildKit's `ADD --checksum` verifies the archive before any later stage can read it. Renovate
  bumps `GOOSE_VERSION` but not the checksums. A Renovate PR for Goose therefore fails its build
  until someone copies the new digests from the release page (GitHub publishes one per asset)
  into `GOOSE_SHA256_AMD64` and `GOOSE_SHA256_ARM64`. It fails closed, the same way the
  act-runner download does.
- Qwen Code ships a new release every few days. Bump it on purpose, and run Glide's
  `mise run harness-conformance` against the new image before a Team relies on it.

### What the Qwen Code install contains, and what the build removes

`npm install -g` ignores `--omit=optional` for this package, so the global install brings its
optional native modules: `sharp` with the musl build of libvips, `@lydell/node-pty`, a clipboard
module and `@qwen-code/audio-capture`. npm 11 does not run the audio-capture install script,
because the package is not on its allow-list.

**The build deletes `@lydell/node-pty`.** Its only Linux prebuild is linked against glibc. On this
musl base it still loads, but the first `spawn` kills the whole process with SIGSEGV. Qwen Code
uses a PTY for its shell tool by default in ACP mode, so every Run would die on its first shell
command (measured: `qwen` exit -11). Without the module, Qwen Code's `getPty()` returns nothing
and the shell tool runs commands as plain child processes. The step after the delete fails the
build if `@lydell/node-pty` or `node-pty` still resolves from Qwen Code's install directory. An
upstream release that moves the module therefore cannot bring the crash back unnoticed.

The package also vendors ripgrep for five platforms, about 24 MB of its roughly 135 MB.

## No calls home

A Run has no internet access beyond the model gateway, so any tool that phones home only burns
time on timeouts. The image switches the tools' telemetry off globally with environment
defaults, which a pod can still override:

| Variable | Tool |
|----------|------|
| `OPENSPEC_TELEMETRY=0`, `DO_NOT_TRACK=1` | OpenSpec (Ploeg's worker sets both again for its own calls) |
| `QWEN_USAGE_STATISTICS_ENABLED=false` | Qwen Code's usage statistics |
| `GOOSE_TELEMETRY_OFF=1` | Goose's PostHog telemetry |
| `LITELLM_LOCAL_MODEL_COST_MAP=True` | OpenHands' LiteLLM cost map |

The remaining per-Run switches (Qwen Code's auto-update and web search, Goose's session naming,
the agents' home directories) are set by the Ploeg profile, not by this image. They depend on a
per-Run directory or on the Run's permission mode.

## Before a Team switches to Qwen Code or Goose

Both agents read configuration from the repository they work on. The image cannot switch that
off, so Ploeg has to neutralise it before either profile is used for real work (Glide ticket
#1278):

- **Goose 1.52.0 enables MCP servers from `<working directory>/.agents/plugins/`.** Plugin
  discovery (`crates/goose/src/plugins/discovery.rs`) adds every directory it finds there to the
  `plugins` map in `config.yaml` with `enabled: true`, and the ACP server starts their MCP
  servers. Disabling works per plugin path, and the repository's own
  `.config/goose/settings.json` and `settings.local.json` can list plugins as enabled. Goose has
  no global "no project plugins" setting, and `GOOSE_PATH_ROOT` does not cover that directory. A
  target repository can therefore start processes inside the Run.
- **Qwen Code 0.24.6 loads the first `.env` it finds walking up from the working directory**
  (`packages/cli/src/config/environment.ts`), for variables the environment does not already
  set. It also merges the repository's `.qwen/settings.json` below the system settings that Ploeg
  passes in `QWEN_CODE_SYSTEM_SETTINGS_PATH`. Workspace `.env` files are skipped only when the
  workspace is untrusted, and with folder trust off (the upstream default) every workspace is
  trusted. Enabling `security.folderTrust` in the Ploeg-written system settings would close the
  `.env` path, but untrusted workspaces change other behaviour as well. That is a profile design
  decision, and it has not been tested here.
