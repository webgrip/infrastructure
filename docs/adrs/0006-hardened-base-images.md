# Docker Hardened Images as the default base, with named structural exceptions

* Status: proposed
* Deciders: WebGrip Ops Team
* Date: 2026-07-31
* Related to: [ADR-0001](0001-docker-image-architecture.md), [ADR-0005](0005-openvex-and-cve-budgets.md)

## Context and Problem Statement

[ADR-0005](0005-openvex-and-cve-budgets.md) stops the CVE count getting worse. It does not make it
better. Driving the number down is almost entirely a question of what each image is built `FROM`:

| Base | Images built on it |
| --- | --- |
| `node:24-bookworm-slim` | `semantic-release`, `semantic-release-monorepo`, `semantic-release-rust`, `rust-releaser`, `agent-runner` |
| `node:24-alpine` | `node-ci-runner` |
| `alpine:3.23.4` | `act-runner`, `helm-deploy` |
| `python:3.12-slim-bookworm` | `agent-runner` |
| `php:8.5-cli` + `composer:2` | `php-ci-runner` |
| `rust:slim-bookworm` → `debian` | `rust-ci-runner` → `tauri-ci-runner` |
| `node` + `python` + `eclipse-temurin:11.0.31-jre-jammy` | `techdocs-builder` → `techdocs-runner`, `mkdocs-runner` |
| `mcr.microsoft.com/playwright` | `playwright-runner` |
| `ghcr.io/actions/actions-runner` | `ci-runner` |

Fourteen of the seventeen images sit on stock Docker Hub bases. Those bases are maintained, but they
are built for compatibility, not for minimal attack surface: they carry a full package manager, a
shell, and a default-root user.

The hardened-image market changed materially in December 2025. **Docker released its entire Hardened
Images catalog — 1000+ images — under Apache 2.0 at `dhi.io`**, free, with no paywalled tier for the
catalog itself. That removes the constraint that previously made this decision awkward: the leading
alternative, Chainguard, offers five images on its free tier, restricted to `latest`, which is
incompatible with a repository that pins every base to a digest and lets Renovate move it.

A second thing changed locally: `ci-runner` installs the **GitHub CLI**, from a third-party apt
source, in an organisation that no longer uses GitHub. Some of the attack surface here is not a base
image problem at all — it is unremoved dead weight.

## Decision Drivers

* **Digest pinning must survive.** Every base in this repo is pinned by digest and moved by Renovate;
  a provider that only publishes `latest` for free is unusable regardless of image quality.
* **No new distro.** A musl or non-glibc migration would break compiled toolchains (`rust-ci-runner`,
  PHP extensions) in ways that cost more than the CVEs are worth.
* **Advisory quality over minimalism.** The value is in a provider that rebuilds continuously and
  publishes advisories scanners consume — not merely in a smaller image.
* **Honest scope.** Any decision must state up front which images it cannot help.
* **No per-seat licensing** for what is fundamentally a homelab.

## Considered Options

* **Option 1**: Docker Hardened Images (`dhi.io`) as the default base (chosen)
* **Option 2**: Chainguard Images
* **Option 3**: Self-hosted Wolfi with `apko` + `melange`
* **Option 4**: Stay on stock Docker Hub bases, rely on Renovate cadence alone
* **Option 5**: A commercial hardening service (RapidFort, Minimus, Echo)

## Decision Outcome

Chosen option: **Option 1 — Docker Hardened Images as the default base where a mapping exists**,
because it is the only option that is free, digest-pinnable, and built on the same Debian and Alpine
lineages already in use, so the migration carries no libc or toolchain risk.

**Access is via Harbor, not via CI credentials.** DHI is free but not anonymous
(`GET https://dhi.io/v2/` → `401`), which would ordinarily mean putting a registry credential in the
build path. It does not, because `dhi.io` advertises `service="registry.docker.io"` — the same Docker
identity service as Docker Hub — so a `dhi` pull-through proxy project reuses the Docker Hub
credential Harbor already holds, and builds reference
`--build-arg REGISTRY_DHI=harbor.webgrip.dev/dhi` exactly as they already do for
`REGISTRY_DOCKERHUB`/`REGISTRY_GHCR`/`REGISTRY_MCR`. No new account, no builder login, and the LAN
gets a layer cache. Provisioned in `webgrip/homelab-cluster`
(`kubernetes/apps/harbor/harbor/app/harbor-proxy-config.configmap.yaml`; ADR-0023 amended
2026-07-31). **This proxy is a prerequisite for the whole migration** — no image can move to a DHI
base before it exists.

Adoption is **staged by risk, not applied wholesale**:

**Stage 1 — near drop-in.** `semantic-release`, `semantic-release-monorepo`, `semantic-release-rust`,
`rust-releaser`, `node-ci-runner`. These are the most frequently executed images in the estate and
the least complex. DHI publishes `node` on both Debian and Alpine lineages.

**Stage 2 — verify then move.** `agent-runner` (python), `rust-ci-runner` (rust + debian),
`act-runner` and `helm-deploy` (alpine), `php-ci-runner` (php, availability of 8.5 to be confirmed),
`techdocs-builder` (node + python + a JRE).

**Stage 3 — structural exceptions, explicitly not migrating.**

* `ci-runner` — based on `ghcr.io/actions/actions-runner`, which Microsoft maintains and for which no
  hardened equivalent exists. This is the worst image in the estate (8 critical / 136 high) and the
  most privileged. The remediation is **not** a base swap; it is [RFC: container runtime
  isolation](../techdocs/docs/general/security/hardening-roadmap.md) plus removing what it does not
  need — starting with the GitHub CLI and its third-party apt source.
* `playwright-runner` — ships Chromium, Firefox and WebKit. Irreducible by construction.

`techdocs-builder`'s `eclipse-temurin:11.0.31-jre-jammy` deserves separate mention: Java 11 on Jammy
is the oldest surface in the repository. If a DHI JRE at a supported major is viable, that is a
larger win than several Stage 1 migrations combined.

Each migration lands as its own PR with the before/after budget numbers from
[ADR-0005](0005-openvex-and-cve-budgets.md)'s gate in the description, and lowers that image's
budget ceiling in the same commit.

### Positive Consequences

* Free and Apache 2.0 — no per-seat cost, no tier that can be withdrawn, no corporate-email gate.
* Same Debian/Alpine lineages, so glibc, `apt`/`apk` and compiled extensions behave as they do today.
* DHI ships SBOMs, SLSA Build Level 3 provenance, OpenVEX exploitability data and signatures — the
  provenance we cannot currently generate ourselves ([ADR-0004](0004-supply-chain-on-forgejo-harbor-openbao.md)'s
  known regression) arrives attached to the base.
* DHI's own OpenVEX data composes with [ADR-0005](0005-openvex-and-cve-budgets.md)'s gate.
* Staging by risk means the two images that cannot move do not block the twelve that can.

### Negative Consequences

* **Docker is a single vendor with a history of moving free functionality behind paywalls.** Apache 2.0
  on the catalog materially limits that risk — a licence cannot be revoked for artifacts already
  published — but the *ongoing rebuild cadence* is a service, and services can change terms.
  Mitigation: images are pulled through Harbor's proxy cache, so a licence change strands us on the
  last good digest rather than breaking builds immediately.
* **DHI cannot be pulled anonymously**, unlike every stock base we use today. `GET https://dhi.io/v2/`
  returns `401`; the Community tier is free but still requires a Docker account. This does not reach
  CI — builders authenticate to nothing, and the credential lives only in Harbor's `dhi` proxy
  endpoint (`webgrip/homelab-cluster` ADR-0023, amended 2026-07-31) — but it does mean **a Docker
  account becomes a hard dependency of building any migrated image**, where previously the base
  registry was optional-credential at worst. If that account is ever suspended or the free tier is
  withdrawn, every Stage 1/2 image stops building until it falls back to a stock base.
* DHI covers Debian and Alpine only. An image needing a different lineage gets no help.
* Runtime variants ship no shell and no package manager and run as non-root by default. For CI
  runner images that is often the *wrong* variant, so most of these will use `-dev` variants and
  therefore capture less of the theoretical benefit than a production service would.
* The two worst images in the estate are both exceptions. This decision does not touch the majority
  of the actual finding count — it improves the many small images while the one large problem is
  addressed elsewhere. That is worth stating plainly.
* Migration is 12 PRs of real verification work, not a find-and-replace.

### Confirmation

```bash
# 1. Every migrated image's base resolves to dhi.io and is digest-pinned
grep -h '^ARG.*IMAGE=' ops/docker/*/Dockerfile | grep -c 'dhi.io.*@sha256:'

# 2. The gate's numbers actually moved — compare the budget file against the
#    step-summary table of the release that followed each migration
git log -p --follow ops/security/cve-budgets.yaml

# 3. No image claims a DHI base while still pulling a stock one
grep -l 'dhi.io' ops/docker/*/Dockerfile | xargs grep -L 'library/node\|library/python\|library/rust'

# 4. The named exceptions are still named — this file and cve-budgets.yaml agree on
#    which images are structural exceptions
yq -r '.images | to_entries[] | select(.value.note) | .key' ops/security/cve-budgets.yaml
```

## Pros and Cons of the Options

### Option 1: Docker Hardened Images (chosen)

* Good, because the full catalog is Apache 2.0 and free, with no tier restriction.
* Good, because Debian/Alpine lineages match what is already in use — low migration risk.
* Good, because it ships SLSA L3 provenance and OpenVEX, filling a gap we cannot currently fill.
* Neutral, because runtime variants are stricter than CI images can use; `-dev` variants are the
  realistic target.
* Bad, because it is a single vendor with a paywall track record.
* Bad, because it does not cover the two images that carry most of the findings.

### Option 2: Chainguard Images

* Good, because Wolfi's advisory feed and nightly rebuild cadence are the benchmark the market is
  measured against.
* Good, because glibc-based, so compatibility is comparable to DHI.
* Bad, because the free tier is five images restricted to `latest` — structurally incompatible with
  digest pinning and Renovate, which is how every base in this repo is managed.
* Bad, because paid catalog pricing is enterprise-scale for a homelab.

### Option 3: Self-hosted Wolfi with apko + melange

* Good, because it is free, fully reproducible, and produces an SBOM at build time where every byte
  has a package name and an advisory-feed entry.
* Good, because it removes vendor dependency entirely.
* Neutral, because Harbor could host the resulting APK repository.
* Bad, because it means owning a package build system — every toolchain in these images becomes a
  `melange` definition we maintain.
* Bad, because the effort is disproportionate to a 17-image estate where two images dominate the
  findings.

### Option 4: Stock bases + Renovate cadence

* Good, because it is the status quo and costs nothing.
* Good, because Renovate already moves digests promptly.
* Bad, because it produced the current numbers. Cadence alone does not reduce the size of the
  package set, and the package set is the problem.

### Option 5: Commercial hardening service

* Good, because vendors like RapidFort profile actual runtime usage and strip unused packages, which
  in principle could help even `ci-runner`.
* Bad, because per-seat or per-image licensing for a homelab is not proportionate.
* Bad, because it introduces a build-time dependency on a third party for every image.

## More Information

* Technical story: hardened-image provider survey, 2026-07-31.
* 2026-07-31 — recorded as **proposed**; no migration has landed yet. Promote to `accepted` when
  Stage 1 completes and the measured budgets in
  [`ops/security/cve-budgets.yaml`](../../ops/security/cve-budgets.yaml) drop.
* 2026-08-05 — `cve-gate` remains the worked example, but is no longer on the release hot path;
  the gate's binaries are baked into `ci-runner` instead. The standard this ADR sets is unaffected
  — what changed is that demonstrating it and enforcing it are no longer the same artifact. See
  [ADR-0008](0008-cve-gate-runs-as-a-step.md).
* Refines: [ADR-0005](0005-openvex-and-cve-budgets.md) — this is how the budgets come down
* Refined by: [ADR-0008](0008-cve-gate-runs-as-a-step.md) — the example leaves the hot path
* External: [Docker Hardened Images catalog](https://github.com/docker-hardened-images/catalog)
