# semantic-release Toolchain

This repository no longer builds a release toolchain image. `harbor.webgrip.dev/webgrip/semantic-release`
comes from [webgrip/semantic-release-config](https://forgejo.webgrip.dev/webgrip/semantic-release-config),
tagged with the config version it carries: `semantic-release:2.5.0` holds
`@webgrip/semantic-release-config` 2.5.0, its locked plugin set and the `webgrip-release` command.
Its build, contents and contract are in that repository's
[`image/README.md`](https://forgejo.webgrip.dev/webgrip/semantic-release-config/src/branch/main/image/README.md).

## What changed and why

Until 2026-11-01 two producers wrote to the same image name. This repository built
`semantic-release` and `semantic-release-monorepo` on its own 0.x version line, from
`ops/docker/semantic-release*`. semantic-release-config built the 1.x and 2.x tags. A consumer
pinned to one line could not move to the other with a normal Renovate update, and a toolchain fix
had to land twice.

The 0.x images are retired:

- Every image in this repository releases with `webgrip-release`, which the repo-root
  `package.json` installs with `npm ci` (see `AGENTS.md`, "The release path"). Nothing here runs
  inside a release image any more.
- The last consumer, the policy tests in `webgrip/workflows`, moved to a Node image with their own
  `yaml` dependency ([workflows #108](https://forgejo.webgrip.dev/webgrip/workflows/pulls/108)).
- `semantic-release-monorepo` has no successor: config 2.x builds monorepo trains itself.

The 0.x tags stay in Harbor until its retention removes them. Nothing new is pushed to them.

## Changing the release toolchain here

The repo-root `package.json` and `package-lock.json` are the release toolchain for every image.
Renovate groups their updates into one PR ("semantic-release toolchain"). Their `overrides` must
match `@webgrip/semantic-release-config`'s own; the release step fails when the notes-generator
pair resolves to anything else.
