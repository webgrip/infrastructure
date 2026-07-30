# semantic-release toolchain images

The toolchain every webgrip release job runs in. Three INDEPENDENT images — none builds `FROM`
another:

| Image | Adds | Consumed by |
| ----- | ---- | ----------- |
| `harbor.webgrip.dev/webgrip/semantic-release` | semantic-release 25, `@webgrip/semantic-release-config`, the plugin set, `semantic-release-helm3`, node, git, yq | `webgrip/workflows` → `semantic-release.yml` |
| `…/semantic-release-monorepo` | `semantic-release-monorepo` | `semantic-release-monorepo.yml` |
| `…/semantic-release-rust` | cargo (rustup), `semantic-release-cargo` | the `rust-semantic-release` composite |

They were briefly chained (`monorepo`/`rust` building `FROM` `semantic-release`), and that made a
sibling's *published* artifact a build dependency: run 167's base image build was killed on the
shared runner pool, so `0.1.0` existed as a release with no image and both variants failed for two
more runs on a `FROM` that could never resolve. Independent images cannot fail that way. The price
is a runtime block repeated in all three Dockerfiles — change it in one, change it in all three. It
costs text, not bytes:
identical instructions on an identical base produce identical layer digests, so Harbor stores them
once and a runner pulls them once.

Rationale, and the reason these are not built in `webgrip/workflows`:
[webgrip/workflows ADR-0005](https://forgejo.webgrip.dev/webgrip/workflows/src/branch/main/docs/adrs/0005-semantic-release-toolchain-image.md).

## The contract

Each image exports **`SEMREL_PREBAKED`** — the path to an installed `node_modules` — plus `PATH`
and `NODE_PATH` into it. That is the entire interface: the composite actions find the toolchain and
run, and install nothing. `NODE_PATH` is not decoration; a consumer's `.releaserc.cjs` does a bare
`require('@webgrip/semantic-release-config')` from its own checkout, which resolves against that
workspace only unless `NODE_PATH` says otherwise.

Unlike every other image here, the npm dependency set is **locked** (`npm ci` against a committed
`package-lock.json`). That is the whole point: the thing that decides version numbers must not be
re-resolved from the network on every release.

Each directory's `package.json` is **both** things at once, which is unusual enough to say plainly:

- the **release manifest** for this image's train — its `name` is the tag prefix, its `version` is
  bumped by `@semantic-release/git` — same as every other image dir here, and
- the **toolchain manifest**, whose `dependencies` + `package-lock.json` are what `npm ci` bakes in.

npm does not mind either collision this creates. It tolerates a root `version` ahead of the
lockfile's, which is the state every release leaves behind (verified: build with `package.json` at
9.9.9 against a 0.0.0 lock succeeds). And it accepts a package that depends on its own name, which
`semantic-release-monorepo` and `semantic-release-rust` both do, since each image's name is also a
package name. Renovate owns the dependencies; semantic-release owns the version.

## Changing the toolchain

Edit the `dependencies` in the image dir's `package.json`, regenerate the lockfile, commit both:

```bash
cd ops/docker/semantic-release
docker run --rm -v "$PWD:/w" -w /w docker.io/library/node:24-bookworm-slim \
  bash -c 'npm install --package-lock-only --omit=dev --no-audit --no-fund'
```

Renovate does this for you and groups all three directories into one PR. A **major** bump of
semantic-release is *expected to fail the build*: each Dockerfile asserts the major that
`webgrip/workflows`' composites target, so moving to 26 has to be a deliberate change to these
images, their consumers and their tags — not something that arrives while nobody is looking.

Keep the three lockfiles on the same semantic-release version: each image installs its tree whole
(one resolution root — semantic-release resolves plugins relative to its own install and the cwd,
not via `NODE_PATH`), so a mismatch would mean a repo's toolchain silently depends on which
reusable workflow it calls. Renovate groups them into one PR for exactly this reason.

## Building locally

Each image builds on its own, in any order:

```bash
docker build -t sr ops/docker/semantic-release
docker build -t sr-monorepo ops/docker/semantic-release-monorepo
docker run --rm sr-monorepo -c 'cd /tmp && node -p "require(\"semantic-release/package.json\").version"'
```

## Releasing

Standard for this repo: a conventional commit under `ops/docker/<image>/` cuts
`<image>-v<version>`, and the release event builds and pushes to Harbor. The three images version
independently — nothing to sequence, and a killed distribute run affects only its own image.
