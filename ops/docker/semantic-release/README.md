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
`package-lock.json` in `toolchain/`). That is the whole point: the thing that decides version
numbers must not be re-resolved from the network on every release.

Note the two `package.json` files per directory and don't confuse them:

- `package.json` — the **release manifest** for this image's own train (name → tag prefix, version
  bumped by `@semantic-release/git`). Same as every other image dir here.
- `toolchain/package.json` + `toolchain/package-lock.json` — the **toolchain** baked into the image.

## Changing the toolchain

Edit `toolchain/package.json`, regenerate the lockfile, commit both:

```bash
cd ops/docker/semantic-release/toolchain
docker run --rm -v "$PWD:/w" -w /w docker.io/library/node:24-bookworm-slim \
  bash -c 'NPM_CONFIG_USERCONFIG=/w/.npmrc npm install --package-lock-only --omit=dev --no-audit --no-fund'
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

## A subdirectory here is only safe because of `max-level: 1`

These are the only image dirs with a nested directory, and that nesting cut a bogus **root** release
the first time it ran (`v2.2.0`, run 166). `on_source_change.yml` calls
`determine-changed-directories` with `max-level: 1` so one image is one immediate child of
`ops/docker`; the reusable's default of `2` turns a file in `ops/docker/<image>/<subdir>/` into a
phantom image dir, which — having no `.releaserc.cjs` — falls through to semantic-release's default
`v${version}` tagFormat. Do not remove that input.

## Releasing

Standard for this repo: a conventional commit under `ops/docker/<image>/` cuts
`<image>-v<version>`, and the release event builds and pushes to Harbor. The three images version
independently — nothing to sequence, and a killed distribute run affects only its own image.
