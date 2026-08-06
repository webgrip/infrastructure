# A shared per-node BuildKit daemon instead of a builder per job

* Status: accepted
* Deciders: WebGrip Ops Team
* Date: 2026-08-05
* Related to: [ADR-0001](0001-docker-image-architecture.md), [ADR-0004](0004-supply-chain-on-forgejo-harbor-openbao.md)

## Context and Problem Statement

Every CI build created its own BuildKit with `docker buildx create --driver docker-container`, used
it once, and destroyed it. Three costs, paid on every build:

1. The buildkit image is pulled and the container created and bootstrapped before any build work
   starts.
2. **BuildKit's local cache lives in that container, so it is empty every time.** Every build was
   locally cache-cold and leaned entirely on `cache-from type=registry` — a network round-trip per
   layer against Harbor for what should be a disk read.
3. The builder had to be removed explicitly afterwards, because it runs on the shared per-node dind
   daemon rather than in the job pod and would otherwise outlive the job.

Point 2 is the expensive one; point 1 is merely the visible one. Measured on `ci-runner` (run 234):
the base image alone cost **355s** to resolve, pull and extract, on an image whose layers were
already in Harbor.

The load this generates is not free elsewhere either. Harbor returned `502 Bad Gateway` three times
in one day (runs 234, 235, 240) under concurrent release traffic, twice failing a release outright.
A cache that avoids the fetch is a bigger lever on that than any retry.

## Considered Options

* A shared per-node BuildKit daemon (DaemonSet, node-local disk), reached with `--driver remote`
* A single cluster-wide BuildKit Deployment on a PVC
* Keep the per-job builder and raise the registry cache hit rate
* `--driver kubernetes`, letting buildx manage BuildKit pods

## Decision Outcome

Chosen option: **a shared per-node BuildKit daemon**, because it is the only option that gives a
build a warm *local* cache without putting that cache on network storage.

`forgejo-buildkitd` runs as a DaemonSet in `kubernetes/apps/forgejo/forgejo-buildkitd/`, state on a
node hostPath at `/var/lib/forgejo-buildkitd`, fronted by a Service with
`internalTrafficPolicy: Local` so each runner reaches its own node's daemon. Builders connect with
`--driver remote`, which creates nothing remotely and therefore needs no teardown.

**Every build path probes it and falls back to the previous throwaway builder when it does not
answer.** The fallback is load-bearing: this DaemonSet is deliberately *not* a dependency of the
runner pool, so CI keeps working when it is absent, draining, or not yet rolled out.

GC is configured rather than defaulted — three ordered policies with a 30 GB per-node ceiling.
Unlike the throwaway builders it replaces, nothing here is discarded automatically, so an unbounded
cache would fill the node disk and fail every build on it.

Registry credentials are deliberately absent from `buildkitd.toml`: with the remote driver buildx
forwards the *client's* credentials over the build session, so buildkitd pulls and pushes as the job
that asked it to. A static credential there would grant every build on the node standing push access
to Harbor.

### Positive Consequences

* `ci-runner` build + push went from **~22m27s to 6m12s** (runs 234 → 238) with no Dockerfile change.
  The 355s base-image resolve disappeared entirely.
* Substantially less Harbor traffic per build, which is the actual mitigation for the 502s.
* The teardown step disappears on the remote path — there is no remote resource to remove.

### Negative Consequences

* **The cache is per-node, not cluster-wide.** A job on worker-1 does not benefit from worker-2's
  cache. `cache-from type=registry` remains the cross-node layer, so this is still strictly better
  than before, and it is the same trade already accepted for the dind image store.
* **Jobs on a node share a build cache.** A poisoned entry from one build is visible to the next.
  That exposure already existed through the shared `:cache` registry tag; it is now also local.
  Branch builds use `cache-from` only and never `cache-to`, which is what stops a branch writing
  into what main reads.
* Runs privileged, like `forgejo-dind`. The rootless variant is tighter and needs its own OverlayFS
  and security-profile work; it is deferred rather than assumed.
* A new stateful component whose disk must be watched. GC bounds it; nothing alerts on it yet.

### Confirmation

`kubectl -n forgejo exec ds/forgejo-buildkitd -- buildctl debug workers` reports a worker, and a
release job's log names the driver it selected (`buildx builder … ready (remote: …)`). A build whose
base-image `FROM` no longer appears among the slowest graph nodes is the cache doing its job.

## Pros and Cons of the Options

### A shared per-node BuildKit daemon

* Good, because the cache is on local disk and survives the job.
* Good, because it mirrors `forgejo-dind`, which already made this exact trade for the image store.
* Bad, because the cache is per-node and shared between jobs on that node.

### A single cluster-wide Deployment on a PVC

* Good, because one cache serves every node.
* Bad, because the PVC would be Longhorn, and the Longhorn read path is precisely what makes Forgejo
  serve git at ~3 MB/s in this cluster. A build cache on network storage is not obviously faster
  than the registry cache it replaces.

### Keep the per-job builder, improve registry caching

* Good, because it changes no infrastructure.
* Bad, because it cannot fix the bootstrap cost, and a registry cache is a network fetch by
  definition — it is the thing being avoided.

### `--driver kubernetes`

* Good, because buildx manages the pods.
* Bad, because it still creates and destroys BuildKit per build, keeping the cold-cache problem that
  motivates the change.

## Links

* 2026-08-05 — DaemonSet landed unwired so it could be observed idle before anything depended on it
* 2026-08-05 — build composite and `build-check` switched to `--driver remote` with fallback
* 2026-08-05 — semantic-release's `verifyRelease` gate switched via `BUILDX_BUILDER`; it was the last
  cold build in the pipeline and had been rebuilding the image in full seconds before the release
  workflow built it again
