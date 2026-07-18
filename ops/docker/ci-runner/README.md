# ci-runner

WebGrip's shared CI runner toolchain. **Forge-neutral by design** — it is consumed by two
different systems, which is why it is not called `github-runner` (its former, misleading name).

| Consumer | How it is used |
| --- | --- |
| **GitHub Actions (ARC)** | Runs as a genuine self-hosted runner. The Actions runner agent from the `actions/actions-runner` base image is the process that executes. Consumed by the `gha-runner-scale-set` / `-heavy` scale sets in `arc-systems`. |
| **Forgejo (in-cluster)** | Used **only as the toolchain**. The KEDA runner pod injects the `forgejo-runner` binary alongside it via an init container, and because the runner advertises `docker:host`, workflow steps execute *inside this image*. |

## Why host-mode makes this image matter

A Forgejo job that declares its own `container:` makes the ephemeral DinD pull and extract that
image **on every job**. On a node whose disk saturates under load that costs minutes of "Set up
job" before a single step runs. Host-mode jobs instead reuse *this* image straight from the
node's containerd cache — the kubelet pulls it once per node — so there is no per-job extraction.

That is the tradeoff to keep in mind when adding tooling here: **image size is not a per-job
cost**, so baking a tool in is usually cheaper than installing it in every workflow run.

## What's inside

- Docker CLI + buildx plugin (talks to the DinD sidecar via `DOCKER_HOST`)
- git, gh, jq, curl, rsync, unzip, patch
- `envsubst` (gettext-base) — `sigstore/cosign-installer` v4+ shells out to it unconditionally, so
  without it every signing job dies with exit 127 before cosign is installed
- PHP 8.3 + Composer
- .NET 9
- CodeQL bundle
- **Node 24** on `PATH` (`node`/`npm`/`npx`) — the actions-runner base only bundles node under
  `externals/` for JS actions, which is a runner internal and not on `PATH`
- **Python 3 + PyYAML**
- **Claude Code CLI** (`claude plugin validate`), pinned via the `CLAUDE_CODE_VERSION` build arg

## Publishing

Released by the monorepo pipeline as `ci-runner-v<x.y.z>` and pushed to both
`harbor.webgrip.dev/webgrip/ci-runner` (in-cluster, LAN) and `ghcr.io/webgrip/ci-runner`.
Cluster workloads pull the **Harbor** copy: it is LAN-local, survives a WAN outage, and avoids
ghcr package-visibility surprises. Consumers pin by digest.
