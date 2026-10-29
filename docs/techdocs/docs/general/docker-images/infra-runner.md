# Infra Runner

The toolchain image for infrastructure jobs that hold production credentials: OpenTofu, age and
etcd, preinstalled and checksum-verified, on a Docker Hardened Image base, running as a non-root
user.

## Purpose

`webgrip/unfold-cluster` used to download OpenTofu, age and etcd in a CI step on every run. That
put three network fetches, and three chances for a tampered binary, in front of the jobs that read
the Hetzner tokens, the state passphrase and the etcd backup keys from OpenBao. This image moves
those downloads to build time, where each one is pinned and verified once, and the signed image
digest is what the runner pool pins.

The image serves three ways:

- **Host mode**, as the main container of the `unfold-infra` runner pool (homelab-cluster
  `kubernetes/apps/forgejo/forgejo-runner/app/infra`). The `runner-bin` init container injects
  `forgejo-runner` at `/dist`, and every step runs inside this image.
- **Job container**, as `container:` for the secret-free pull-request `check` job on the shared
  `docker` pool.
- **Host mode outside the homelab**, as the main container of unfold-cluster's `unfold-check`
  runner pool. That cluster cannot reach Harbor, so it pulls the copy on `forgejo.webgrip.dev`,
  which the release workflow's `release-copy-forgejo` job makes and checks byte for byte.
  `copy_image_to_forgejo.yml` copies an earlier release by hand.

Both need `node` on `PATH`, because JavaScript actions such as `actions/checkout` run with it.

## Image details

| Property | Value |
| --- | --- |
| **Base** | `dhi.io/node:24.22.1-alpine3.24-dev` through the Harbor `dhi` proxy, digest-pinned |
| **User** | `runner`, uid and gid `1000`, `USER 1000` |
| **Home** | `/home/runner`, owned by `runner`, also the working directory |
| **Default command** | `bash` |
| **Registry** | `harbor.webgrip.dev/webgrip/infra-runner`; releases are also copied, signature and attestations included, to `forgejo.webgrip.dev/webgrip/infra-runner` |
| **Dockerfile** | [`ops/docker/infra-runner/Dockerfile`](../../../../../ops/docker/infra-runner/Dockerfile) |

## Tools

| Tool | Version | Source | Verified against |
| --- | --- | --- | --- |
| `tofu` | 1.13.2 | `opentofu/opentofu` release archive | `tofu_1.13.2_SHA256SUMS` from the same release |
| `age`, `age-keygen` | 1.3.2 | `FiloSottile/age` release archive | the asset digest GitHub publishes for the release; age ships no checksum file |
| `etcd`, `etcdctl`, `etcdutl` | 3.7.3 | `etcd-io/etcd` release archive | `SHA256SUMS` from the same release |
| `node` | 24 | the base image | the base image digest |

From apk: `bash`, `ca-certificates`, `coreutils`, `curl`, `git`, `jq`, `openssh-client` and `tar`. GNU coreutils is
there because the workflows rely on it: `date -u -d` on an RFC 3339 timestamp, which busybox
`date` rejects, and `od`, `base64`, `stat -c`, `dd`, `mktemp`, `seq` and `sha256sum` behaving the
way the scripts expect.

`openssh-client` is there for unfold-cluster's apply, which reads the tailnet keys from its Headscale
server over SSH with `StrictHostKeyChecking=yes` against a host key OpenTofu pinned; the image
holds no SSH key of its own.

The base image's `npm`, `yarn` and `corepack` are removed, and so is its `node` user, whose uid
`1000` the `runner` user takes over.

## What is deliberately absent

No Docker CLI, no compilers, no package manager usable at runtime (the image runs as uid 1000) and
no language toolchain beyond `node`. Each tool in this image is reachable by the credentials a job
reads, so the list stays as short as the infra workflows allow. A job that needs more belongs on a
different image, not in this one.

## Version pins and checksums

Every downloaded tool has a `# renovate:` line above its version `ARG` and its sha256 in a second
`ARG` beside it. The build checks the archive with `sha256sum -c` before it unpacks anything.

Renovate moves the version and does not move the checksum. **A version bump without its new
checksum fails the build** instead of shipping an unverified binary: whoever reviews the Renovate
pull request takes the new sha256 from the release's published checksum file (for age, the asset
digest on the release page) and adds it to the same pull request. This is the same convention
`helm-deploy` and `ci-runner` follow.

The last build step prints the version of every tool and checks that it runs as `1000:1000` with
a writable home, so a broken install fails the build rather than the first job that uses it.

## Running it in the runner pod

The pod spec the `unfold-infra` pool inherits from the base ScaledJob works with this image as it
is:

- The pod's `fsGroup: 1000` matches the image's gid, so the shared volumes stay writable.
- `forgejo-runner` in host mode puts its work directory under `$HOME/.cache/act`, and
  `/home/runner` is writable by uid 1000.
- The runner command only needs `bash`, `cat` and `sleep`, and its `node` check finds
  `/usr/bin/node`.

The base pod spec probes the shared dind daemon before it starts the runner. This image has no
Docker CLI, so `DOCKER_HOST` does nothing here; the probe only costs a few seconds.

## Usage

As a job container:

```yaml
jobs:
  check:
    runs-on: docker
    container:
      image: harbor.webgrip.dev/webgrip/infra-runner:<version>@sha256:<digest>
    steps:
      - uses: actions/checkout@<sha>
      - run: tofu fmt -check -recursive
```

Locally:

```bash
docker build -t infra-runner:local ops/docker/infra-runner
docker run --rm -v "$PWD:/work" -w /work infra-runner:local tofu version
```

## Vulnerability budget

The image starts in `warn` mode in `ops/security/cve-budgets.yaml`, at the numbers its first
scan found: 1 critical and 6 high. One high is curl in the OS layer, which has no fix yet. The
rest is `golang.org/x/net` and `google.golang.org/grpc` compiled into the upstream `tofu`
binary; they go down when OpenTofu ships a release with newer modules and Renovate brings it in.
Moving from tofu 1.13.1 and etcd 3.7.2 to 1.13.2 and 3.7.3 took the image from 8 critical and
44 high to these numbers, because both were rebuilt with a patched Go.
