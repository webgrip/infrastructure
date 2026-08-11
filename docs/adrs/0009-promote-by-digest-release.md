# Releases promote the verified candidate by digest instead of rebuilding it

* Status: proposed
* Deciders: WebGrip Ops Team
* Date: 2026-08-11
* Related to: [ADR-0004](0004-supply-chain-on-forgejo-harbor-openbao.md), [ADR-0007](0007-shared-per-node-buildkit-daemon.md), [ADR-0008](0008-cve-gate-runs-as-a-step.md)

## Context and Problem Statement

Every image release builds the image **twice**:

1. On push to main, semantic-release's `dockerVerifyGate()` builds the image
   (`--output=type=cacheonly`) to prove the tag it is about to cut names something that compiles.
2. The tag fires the `release` event, and `on_release_published` builds the same source **again**,
   this time pushing to Harbor.

Measured on 2026-08-09: rust-releaser spent 14m43s in the push run and 21m45s in the release run —
**~36 minutes of wall clock for one change**, most of it the same compilation twice. Registry
cache blunts this for cache-friendly images (ci-runner: 2m59s + 7m38s) but a cold Rust or
browser-image build pays nearly full price both times.

The naive fix — folding both workflows into one — saves almost nothing (the two *builds* are the
cost, not the two *workflows*) and worsens the failure mode: `on_source_change` runs under a
concurrency group that cancels on every push to main, and a cancel mid-push/sign is exactly how
the estate got unsigned tags on 2026-08-08. The release-event pipeline being separate is what
makes it re-runnable per tag and immune to push-cancellation.

## Decision Drivers

* Release wall-clock: the double build is the single largest avoidable cost in the pipeline.
* The signature contract must not weaken: a tag may only ever exist for an artifact that passed
  verification, and only signed digests are admitted (ADR-0004).
* Per-tag re-runnability and push-cancel immunity of the release pipeline must survive.
* Forgejo flattens reusable-workflow jobs and does **not** apply the caller's `if:` to them —
  any conditional skip must live at *step* level, not around a reusable call.
* No new binaries on the runner: retagging must work with what ci-runner already ships.

## Considered Options

* **Option 1**: Verify build pushes a candidate; the release **promotes it by digest** (chosen)
* **Option 2**: Fold release creation and build/publish into one workflow
* **Option 3**: Status quo — two builds, mitigated by registry cache

## Decision Outcome

Chosen option: **Option 1 — promote by digest**, because it removes the second build entirely
while *strengthening* the guarantee: the bytes that were verified are byte-for-byte the bytes
that get tagged, signed and admitted — today's rebuild only promises the same *source* built
twice, not the same artifact.

Mechanics, in the order they execute:

1. **The verify build becomes the release build.** When the environment provides
   `BUILD_CANDIDATE_REF`, `dockerVerifyGate()` (in `@webgrip/semantic-release-config`) builds
   with the release pipeline's exact flags — `--provenance=mode=max`, `--sbom=generator=<pinned>`
   (via `BUILD_SBOM_GENERATOR`), `IMAGE_VERSION=${nextRelease.version}` (the exec plugin templates
   the command after the version is known), `IMAGE_REVISION`, `IMAGE_CREATED` — and pushes the
   result as `webgrip/<image>:cand-<git-sha>`. Without `BUILD_CANDIDATE_REF` it behaves exactly
   as before (`cacheonly`), so other consumers of the config are untouched.
2. **The composite exports the contract.** `semantic-release-monorepo/action.yml` exports
   `BUILD_CANDIDATE_REF` and `BUILD_SBOM_GENERATOR` next to the existing `BUILD_CACHE_REF`.
3. **The release pipeline promotes instead of building.** `on_release_published`'s Distribute job
   resolves the released tag to its commit, asks Harbor for `cand-<sha>`, and if present re-tags
   the manifest **by digest** to `:<version>` (and `:latest` for finals) through the registry API —
   a byte-exact PUT of the same manifest bytes, milliseconds, no data movement. BuildKit's
   provenance and SBOM attestations live inside the pushed index, so they travel with the digest.
   The candidate tag is deleted afterwards (fail-soft).
4. **No candidate → build as today.** The same `docker-build-push-registry-fast` composite the
   reusable wrapped runs inline as a fallback step. This is also the rollout path: the promote
   logic can land before any candidate exists and the pipeline behaves exactly as before.

The Distribute job stops calling the `docker-build-and-push-harbor-fast` reusable and runs the
composite directly. That is forced by the driver above: Forgejo would run the reusable's flattened
inner jobs even when the caller's `if:` says skip — a conditional around a reusable is a no-op.
Side effect: two nested wrapper jobs disappear from every release run.

### Consequences

* Good, because a cold release halves its wall clock (rust-releaser ~36m → ~16m; every image
  saves one full build).
* Good, because the signed artifact is the verified artifact — identity, not similarity.
* Good, because prerelease/final logic, re-runs, and push-cancel immunity are untouched.
* Good, because the fallback keeps the pipeline whole with zero candidates in Harbor.
* Bad, because `cand-*` tags accumulate in Harbor between verify and promote (or forever, when a
  verified push never releases). Mitigated by fail-soft deletion after promotion; a Harbor
  retention rule for `cand-*` (homelab-cluster's harbor-proxy-config job) is the durable answer.
* Bad, because the verify build now needs push rights — it already has them (it writes `:cache`).
* Bad, because `IMAGE_CREATED` is stamped at verify time, not at release-publish time. The label
  now records when the artifact was built, which is arguably *more* honest.
* Neutral, because verify builds on non-releasing pushes never run (`verifyReleaseCmd` executes
  only after commit analysis decides a release happens), so candidates are only pushed for
  commits that actually tag.

### Confirmation

```bash
# A promoted release's digest equals its candidate's digest (run log prints both), and the
# Distribute job of a promoted release finishes in seconds, not minutes:
#   "promoted <image>@sha256:… to :<version> (byte-exact)"
# The fallback still works: delete the cand tag before the release event fires and the same
# job builds+pushes as before.
# The signature verifies against the promoted digest:
cosign verify --key <openbao-pub> harbor.webgrip.dev/webgrip/<image>:<version>
```

## Pros and Cons of the Options

### Option 1: promote by digest (chosen)

* Good, because it eliminates the duplicate build rather than hiding it behind cache.
* Good, because verification and release converge on one artifact.
* Bad, because the candidate lifecycle (push, promote, delete, retention) is new machinery.

### Option 2: one coupled workflow

* Good, because it is conceptually simpler — one run per change.
* Bad, because it saves almost nothing: the duplicate build is the cost, and it remains.
* Bad, because push-to-main cancellation would then be able to kill a wave mid-push/sign —
  the exact mechanism that shipped unsigned tags on 2026-08-08.
* Bad, because per-tag re-runs (the recovery tool for everything above) disappear.

### Option 3: status quo

* Good, because zero change.
* Bad, because every cold release pays for two builds, and the estate's slowest images are
  exactly the cache-hostile ones.

## More Information

* Technical story: measured 2026-08-09 during the pin-train releases (runs 318/319 vs 332/333).
* 2026-08-11 — proposed; implementation in `@webgrip/semantic-release-config` (candidate push)
  and this repo (composite exports, Distribute promotes with inline fallback).
