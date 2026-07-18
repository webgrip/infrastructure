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

**Release-skip race:** the Release job checks out the *pushed* sha, but semantic-release
refuses to publish when that sha is behind the remote branch tip — and exits **green**
("local branch is behind the remote one", a skip, not a failure). With a busy runner queue
(runs can wait 15+ min) any concurrent push to `main` silently eats the release: job success,
no tag. Fix: land another commit touching this directory to re-run the release from the new
tip — the analyzer still picks up every unreleased commit since the last tag.

**Transient release-job failures:** action resolution clones `actions/*` from
`data.forgejo.org` at job start; a WAN hiccup there kills the job in under a minute
(e.g. v1.0.2 attempt 1 died at 43s on action resolution; attempt 2 hit the in-cluster
Harbor mid-rollout while pulling its proxied base image -- wait for the harbor HelmRelease
to be Ready before re-triggering). Re-trigger
with any commit touching this directory — unreleased fix commits are picked up cumulatively.
