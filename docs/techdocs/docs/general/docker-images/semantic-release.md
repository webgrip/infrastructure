# semantic-release Toolchain

The release toolchain every webgrip release job runs in: three independent images, each with a
**locked** semantic-release dependency set baked in.

## Purpose

Release jobs used to build their own toolchain. Every release, in every repo, resolved ~430 npm
packages from the network on the critical path — unlocked, so two runs of the same commit could cut
the release with different plugin versions. `ploeg` run 122 spent **2m + 21s** on npm for ~25s of
releasing, printed an `npm audit` summary nobody reads, and downloaded and checksum-verified `yq`
on the way.

These images move all of that to build time, once:

- **Reproducible** — `npm ci` against a committed `package-lock.json`. The thing that decides
  version numbers is itself versioned.
- **Fast** — release setup goes from ~3m45s to ~0.
- **Off the network critical path** — a registry outage stops being an outage of *releasing*.
- **Deliberately upgraded** — Renovate opens one PR against the lockfiles; nothing floats.

Full rationale, and why these are built here rather than in the repo whose workflows consume them:
[webgrip/workflows ADR-0005](https://forgejo.webgrip.dev/webgrip/workflows/src/branch/main/docs/adrs/0005-semantic-release-toolchain-image.md).

## The family

| Image | Contents | Consumed by |
|-------|----------|-------------|
| `webgrip/semantic-release` | semantic-release 25, `@webgrip/semantic-release-config`, plugin set, `semantic-release-helm3`, node, git, yq | `webgrip/workflows` → `semantic-release.yml` |
| `webgrip/semantic-release-monorepo` | the same, plus `semantic-release-monorepo` | `semantic-release-monorepo.yml` |
| `webgrip/semantic-release-rust` | the same, plus cargo (rustup) and `semantic-release-cargo` | the `rust-semantic-release` composite |

**None of them builds `FROM` another.** They were chained once, and it made a sibling's *published*
artifact a build dependency: a killed distribute run left `semantic-release:0.1.0` as a release with
no image, and both variants then failed for two runs on a `FROM` that could never resolve. The
runtime block is instead repeated in all three Dockerfiles, and must be kept in step by hand.
Identical instructions on an identical base produce identical layer digests, so the duplication
costs Dockerfile text, not registry or pull bytes.

## Image details

| Property | Value |
|----------|-------|
| **Base image** | `node:24-bookworm-slim` (all three) |
| **Size** | ~600MB base; the rust variant adds a minimal cargo toolchain |
| **Architecture** | AMD64 (the in-cluster build is amd64-only; see homelab-cluster ADR-0036) |
| **Registry** | `harbor.webgrip.dev/webgrip/semantic-release*` |
| **Dockerfile** | [`ops/docker/semantic-release/Dockerfile`](../../../../../ops/docker/semantic-release/Dockerfile) |

### Release automation stack

| Tool | Version | Why pinned here |
|------|---------|-----------------|
| **semantic-release** | 25.0.8 | The major the composites target; asserted at build time |
| **@webgrip/semantic-release-config** | 1.1.0 | The shared config, so no consumer resolves it at release time |
| **semantic-release-helm3** | 2.10.0 | Inline configs still reference it; the shared config does not depend on it |
| **semantic-release-monorepo** | 8.0.2 | *monorepo image only* — un-bundled from the shared config on purpose |
| **semantic-release-cargo** | 2.4.2 | *rust image only* |
| **yq** | v4.44.3 | Chart.yaml version/appVersion bumps; checksum-verified at build |
| **node** | 24 | semantic-release 25 requires `^22.14 \|\| >=24.10` |

Contrast with [Rust Releaser](rust-releaser.md), which installs `semantic-release … latest`
globally and unpinned. That image is a cross-compilation build farm that happens to release; these
are release toolchains. A repo needing both can build `FROM rust-releaser` and copy `/opt/semrel`
out of `semantic-release-rust`.

## The contract: `SEMREL_PREBAKED`

Each image exports:

```dockerfile
ENV SEMREL_PREBAKED=/opt/semrel/node_modules \
    NODE_PATH=/opt/semrel/node_modules \
    PATH=/opt/semrel/node_modules/.bin:$PATH
```

That is the entire interface. The composite actions in `webgrip/workflows` look for
`SEMREL_PREBAKED`, run the binary it provides, and install nothing. `NODE_PATH` is load-bearing: a
consumer's `.releaserc.cjs` does a bare `require('@webgrip/semantic-release-config')` from its own
checkout, which resolves against that workspace only unless `NODE_PATH` says otherwise.

A job run **outside** these images still releases — the composites fall back to an unlocked install
and emit a `::warning::` saying so. Visible, not fatal.

## Usage

Consumers do not reference these images directly; the reusable workflows do, via a
`toolchain-image` input:

```yaml
jobs:
  release:
    uses: webgrip/workflows/.forgejo/workflows/semantic-release.yml@main
    secrets:
      CI_TOKEN: ${{ secrets.WEBGRIP_CI_TOKEN }}
    # toolchain-image defaults to harbor.webgrip.dev/webgrip/semantic-release:<major line>
```

Need something the image lacks — a `prepareCmd` shelling out to `helm`, `php` or the docker CLI?
Build your own `FROM` it and pass the result:

```dockerfile
FROM harbor.webgrip.dev/webgrip/semantic-release:1
RUN apt-get update && apt-get install -y --no-install-recommends helm \
    && rm -rf /var/lib/apt/lists/*
```

That keeps environment needs in an image instead of in ad-hoc job steps.

## Maintenance

Each image dir's `package.json` is both the release manifest for that image's train (its `name` is
the tag prefix, its `version` is bumped by semantic-release) and the toolchain manifest whose
`dependencies` are baked in. npm tolerates both collisions that creates — a root version ahead of
the lockfile's, and a package depending on its own name. See
[`ops/docker/semantic-release/README.md`](../../../../../ops/docker/semantic-release/README.md) for
how to regenerate a lockfile.

Renovate groups all three toolchains into one PR and they must stay on the same semantic-release
version. The three images version and release independently — there is nothing to sequence. A **major** bump is expected to fail the build: each Dockerfile asserts the major that
`webgrip/workflows`' composites target, so moving to 26 is a deliberate, coordinated change rather
than something that arrives while nobody is looking.
