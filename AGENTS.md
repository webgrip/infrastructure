# AGENTS.md — webgrip/infrastructure

The images and the local ACT commands are in [`README.md`](README.md). This file carries the
release mechanics and the traps that a single workflow file does not reveal.

## What is here

`ops/docker/<image>/` is the unit of release — around twenty runner, releaser and tooling
images (`agent-runner`, `ci-runner`, `semantic-release*`, `techdocs-*`, the language `*-ci-runner`
family, `static-site-ci-runner`, `helm-deploy`, `cve-gate`, `vikunja-mcp`). Alongside them:
`ops/scripts/`, `ops/security/`, `ops/vex/`.

**`.forgejo/` is the only workflow tree.** There is no `.github/` any more — the README's ACT
snippets still name `.github/workflows/...` and the workflow headers still describe themselves
as "Forgejo mirror of `.github/workflows/...`". That prose is stale; the Forgejo files are the
originals now. Do not resurrect a `.github/` tree to satisfy a doc.

## The release path

`on_source_change.yml` (push) cuts per-image releases → `on_release_published.yml` (release)
builds and pushes to the in-cluster Harbor.

- **The matrix is push-diff.** `changed-images` derives its entries from the files a push
  touched. When a release job fails, no tag is cut and the commit is already on `main`, so no
  later push touches that image and **it is never retried** — it sits unreleased until someone
  re-runs the job by hand. That is how `ci-runner` was stranded when run 240 died on Harbor 502s.
- **`workflow_dispatch` takes an `image` input that forces one matrix entry** regardless of the
  diff. This is the scriptable recovery route (the re-run button is not reachable from a
  script). It skips nothing: the same verify build gate runs and semantic-release still decides
  from commit history, so dispatching an image with nothing to release is a no-op, not a forced
  bump.
- Tags are `<image>-v<version>`; `on_release_published.yml` parses the image and version back
  out of the tag with that regex, so a tag in any other shape fails the parse job.
- **Since ADR-0009 a release promotes, it does not rebuild.** The verify build on `main` already
  pushed `:cand-<sha>`; the release promotes that manifest by digest so the verified bytes and
  the released bytes are the same bytes. BuildKit's provenance and SBOM attestations live inside
  the pushed index and travel with the digest. The fallback build only runs when no candidate
  exists (config lag, dispatch of an old tag, GC'd cand tag).
- **The promotion is step-level `if:`, not a conditional `uses:`.** Forgejo flattens a reusable
  workflow's inner jobs into the caller's graph and does not apply the caller job's `if:` to
  them — a "skipped" reusable still ran its build. That bug raced two builds onto one Harbor
  tag; keep conditionals at step level.

## Supply chain

cosign signs and attests through **OpenBao Transit** — the key never leaves OpenBao and the
runner authenticates with its Kubernetes ServiceAccount. There is no GitHub OIDC and no Fulcio
on this path, and the GitHub-only pieces (SLSA build provenance, Trivy SARIF into the Security
tab) have no Forgejo analog and are deliberately absent. SBOMs go to Dependency-Track. The local
composite is `.forgejo/actions/cosign-sign-attest`.

## Traps

- **Harbor is LAN-only.** Anything that pushes to `harbor.webgrip.dev` must be
  `runs-on: docker` — the in-cluster ephemeral runner pool is the only thing that reaches it.
- **`WEBGRIP_CI_TOKEN`, never `secrets.FORGEJO_TOKEN`.** The latter resolves to the built-in
  per-job token, which attributes releases to Ghost and suppresses the native `release` event
  that `on_release_published.yml` waits for.
- **`actions/checkout@v5` is the default pin; `@v6`/`@v7` work too.** The old "v6 is broken on
  non-GitHub runners" rule was disproven on 2026-09-18 by a canary on the real Forgejo runner
  ([homelab-cluster run 1710](https://forgejo.webgrip.dev/webgrip/homelab-cluster/actions/runs/1710)):
  checkout v6 and v7 and setup-node v5, v6 and v7 all pass. Bump deliberately, never on automerge.
- **`uses:` must be the `org/repo/path@sha` shorthand**, never a full `https://` URL: Forgejo
  resolves the called workflow's `runs-on` server-side, and a full URL leaves the job queued
  forever with an empty label list.
- The release toolchain is a **committed manifest** installed with `npm ci`, not an ad-hoc
  install. Adding a plugin means updating the manifest.

## Repo rules

- **Comments are NOT allowed.** Always communicate intent with code: a precise name, a type, a
  smaller function, a test that states the case. A comment is a failure. This holds for every
  language in the repo, prose in YAML and TOML included. Machine-read directives stay, because the
  toolchain acts on them as syntax: `// @ts-check`, `eslint-disable`, `<!-- prettier-ignore -->`,
  `# syntax=`, `# renovate:`, `# yaml-language-server:`, and shebangs. Doc-comment forms the
  toolchain itself reads are not comments either and stay: godoc directly above an exported
  identifier, rustdoc `///` and `//!`, and PHPDoc blocks carrying type tags. Anything that outlives
  a single expression belongs in `docs/` or an ADR, where it gets reviewed, linked and kept
  current. The estate decision is
  [ADR 0006](https://forgejo.webgrip.dev/webgrip/workflows/src/branch/main/docs/adrs/0006-no-comments-in-code.md).
