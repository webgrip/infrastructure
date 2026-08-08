# Handoff — making Harbor honour our VEX statements

**Status:** research complete, no code written yet.
**Date:** 2026-08-08.
**Audience:** whoever picks up the upstream work — a future session, or a human.

This document exists because the pipeline publishes a signed OpenVEX attestation on every image and
Harbor's UI still shows every suppressed CVE as unlisted. It records what was actually measured,
corrects two claims this repo made in comments and docs, and names the three upstream changes that
close the gap — ranked, because only one of them is blocking.

---

## The correction first

Two things written in this repo are wrong, and anything built on them will be built wrong.

`.forgejo/actions/cosign-sign-attest/action.yml` says, in the comment above the cve-budget
attestation:

> Harbor cannot: it has no VEX support (goharbor/harbor#22720)

Both halves are wrong.

**Harbor's Trivy adapter has passed `--vex` since 2025-08-28.** It is in
`pkg/trivy/wrapper.go:222` on `main` and in every adapter release from `v0.34.2` onward:

```go
if w.config.VEXSource != "" {
    args = append(args, "--vex", w.config.VEXSource)
}

if w.config.SkipVEXRepoUpdate {
    args = append(args, "--skip-vex-repo-update")
}
```

driven by `pkg/etc/config.go:42-43`:

```go
VEXSource           string `env:"SCANNER_TRIVY_VEX_SOURCE"`
SkipVEXRepoUpdate   bool   `env:"SCANNER_TRIVY_SKIP_VEX_REPO_UPDATE" envDefault:"false"`
```

**And the Harbor we are running already ships it.** `goharbor/harbor` at tag `v2.15.2` pins
`TRIVYADAPTERVERSION=v0.38.0` and `TRIVYVERSION=v0.72.0` in its `Makefile`. Our HelmRelease
(`homelab-cluster/kubernetes/apps/harbor/harbor/app/helmrelease.yaml`) runs
`goharbor/trivy-adapter-photon:v2.15.2`. The capability is installed and switched off.

**`goharbor/harbor#22720` is a different issue.** It is titled *"OpenVEX format
(application/vnd.openvex+json) is not recognized by Harbor"*, opened 2026-01-09, and it is about
Harbor's **UI not displaying** a VEX artifact attached with `oras attach`. It is not about the
scanner ignoring VEX, and citing it as the reason Harbor "has no VEX support" is a miscitation.
Fix the comment when the config change lands.

---

## What we publish, and what Trivy wants

These match exactly. Trivy's own documentation example is, character for character, the command
already in `cosign-sign-attest/action.yml:320-321`:

| | |
|---|---|
| Trivy docs example | `cosign attest --predicate oci.openvex.json --type openvex <IMAGE>` |
| What we run | `cosign attest --yes --tlog-upload=false --key hashivault://... --predicate vex.openvex.json --type openvex "$IMAGE"` |

So there is nothing to change on our side of the wire. The document is the right format, attached
the right way, at the right predicate type.

---

## The immediate unblock is config, not a PR

`harbor-helm` does not template `SCANNER_TRIVY_VEX_SOURCE`, but it does have a passthrough — and
our chart version already has it. `templates/trivy/trivy-sts.yaml:140` at chart tag `v1.19.1`:

```yaml
{{- with .Values.trivy.extraEnvVars }}
{{- toYaml . | nindent 12 }}
{{- end }}
```

So in `helmrelease.yaml`, under the existing `trivy:` block:

```yaml
    trivy:
      # ... existing keys ...
      extraEnvVars:
        - name: SCANNER_TRIVY_VEX_SOURCE
          value: "oci"
```

**Do not do this blind.** Read the blocker below first — on current upstream code this is expected
to fail against our private Harbor, and the point of trying it is to find out *how* it fails, which
is the evidence the upstream issue needs.

---

## The blocker: `--vex oci` drops registry credentials

This is the finding that matters, and it is why nobody appears to be running `--vex oci` against a
private registry.

`aquasecurity/trivy` at `v0.72.0`, `pkg/vex/oci.go:35-43`, hands the whole job to the
`openvex/discovery` library with no options at all:

```go
func RetrieveVEXAttestation(p *purl.PackageURL) (*OpenVEX, error) {
    // ...
    vexDocuments, err := discovery.NewAgent().ProbePurl(p.String())
```

And `openvex/discovery`, `pkg/probers/oci/prober.go:147-151`, declines to pass any:

```go
ociremoteOpts := []ociremote.Option{}

// TODO(puerco): Support relevant registry options
// o := options.RegistryOptions{}
// ociremoteOpts := []ociremote.Option{ociremote.WithRemoteOptions(o.GetRegistryClientOpts(ctx)...)}
```

With no `remote.Option`, cosign falls back to its package default —
`sigstore/cosign`, `pkg/oci/remote/options.go:52-54`:

```go
var defaultOptions = []remote.Option{
    remote.WithAuthFromKeychain(authn.DefaultKeychain),
}
```

`authn.DefaultKeychain` reads a **Docker config file**. The Harbor Trivy adapter authenticates by
setting `TRIVY_USERNAME`/`TRIVY_PASSWORD`/`TRIVY_REGISTRY_TOKEN` in the child process environment
(`pkg/trivy/wrapper.go`, the `switch target.Auth()` block) — Trivy-specific variables that
`authn.DefaultKeychain` has never heard of. There is no Docker config in that container.

**So the referrer probe goes out anonymous.** Ours is a private registry; anonymous is refused:

```
$ curl -o /dev/null -w '%{http_code}' https://harbor.webgrip.dev/v2/
401
$ curl -o /dev/null -w '%{http_code}' https://harbor.webgrip.dev/v2/webgrip/cve-gate/manifests/0.3.4
401
```

!!! warning "This chain is read from source, not observed"
    Every link above is quoted from the code at a pinned version, but the end-to-end failure has
    **not been reproduced**. Reproduce it before filing anything upstream — a maintainer's first
    question will be "what did it actually do", and "I read the code" is not an answer. The
    reproduction is in the next section and takes one command.

---

## Reproduce it in one command

You need a Harbor robot credential with pull on `webgrip`. Do not paste it into a shell history:

```bash
read -rs HARBOR_TOKEN            # robot password, not echoed
export TRIVY_USERNAME='robot$webgrip+...'
export TRIVY_PASSWORD="$HARBOR_TOKEN"

# Control: the scan itself authenticates fine.
trivy image --severity HIGH,CRITICAL \
  harbor.webgrip.dev/webgrip/cve-gate:0.3.4

# The test: same scan, VEX discovery on, debug so the vex prefix logs.
trivy image --severity HIGH,CRITICAL --vex oci --debug \
  harbor.webgrip.dev/webgrip/cve-gate:0.3.4 2>&1 | grep -i vex
```

`cve-gate:0.3.4` is the right target — it is the first image that both signed and carries a VEX
attestation, and its statement suppresses exactly one finding (`CVE-2026-34040` /
`GHSA-x744-4wpc-v9h2`), so the result is unambiguous.

Three outcomes, three different pieces of work:

| Observed | Means | Next |
|---|---|---|
| `UNAUTHORIZED` / `401` from the probe | the credential gap above is real | file the `openvex/discovery` issue; it is the blocking bug |
| `No VEX attestations found` | probe authenticated but found nothing | check the referrer actually exists: `cosign tree harbor.webgrip.dev/webgrip/cve-gate:0.3.4`. If it does, the mismatch is in the discovery library's referrer filter, not auth |
| the finding is suppressed | **there is no blocker** | skip to item 3; set `extraEnvVars` and you are done |

The third outcome is genuinely possible — `authn.DefaultKeychain` also honours `DOCKER_CONFIG`, and
if anything in the adapter image happens to write one, this all works today. Measure before
assuming.

---

## The three upstream items, ranked

### 1. `openvex/discovery` — thread registry auth through (blocking)

**Repo:** `github.com/openvex/discovery`
**File:** `pkg/probers/oci/prober.go`, `ResolveImageReference`, ~line 147
**Shape:** the fix is already written as a comment by the maintainer (`TODO(puerco)`). Add
credentials to `options.Options`, plumb them into `ociremote.WithRemoteOptions(...)`, and pass them
from `ProbePurl`'s caller.

This is a small, maintainer-sanctioned change with a TODO marking the exact spot. **Open an issue
with the reproduction before writing the patch** — the API shape for carrying credentials is the
maintainer's call, and guessing it wastes the PR.

Nothing downstream works until this lands. It is the only item on this list that is blocking.

### 2. `aquasecurity/trivy` — pass its own registry options to the probe

**Repo:** `github.com/aquasecurity/trivy`
**File:** `pkg/vex/oci.go`, `RetrieveVEXAttestation`
**Depends on:** item 1. Cannot be written before the discovery API exists.

Trivy already knows the credentials — it just authenticated to pull the image. It calls
`discovery.NewAgent().ProbePurl(...)` without them. Once item 1 gives it somewhere to put them,
this is a few lines.

Two more things worth raising in the same issue, both visible in the code above:

- **No signature verification.** `RetrieveVEXAttestation` fetches the attestation and parses the
  predicate. It never verifies who signed it. Anyone with push access to a repository can attach an
  `openvex` attestation and have Trivy honour it. That is worth stating plainly upstream — and it
  is worth us knowing, because it means Harbor honouring our VEX is *not* equivalent to Harbor
  trusting our key. Our own gate does better: `cve-gate` reads statements from a reviewed directory
  in git, and the cve-budget attestation is signed with the OpenBao Transit key.
- **First document wins.** `logger.Debug("VEX attestation found, taking the first one")` — with
  more than one VEX attestation, the rest are silently discarded, and referrer ordering is not
  something a registry guarantees.

### 3. `goharbor/harbor-helm` — first-class the setting (small, independent)

**Repo:** `github.com/goharbor/harbor-helm`
**Files:** `values.yaml` (the `trivy:` block, ~line 931) and `templates/trivy/trivy-sts.yaml`
(the `SCANNER_TRIVY_*` env block, lines 82-114).

Fifteen `SCANNER_TRIVY_*` variables are templated; these two are not. The change follows the
established pattern exactly:

```yaml
            - name: "SCANNER_TRIVY_VEX_SOURCE"
              value: {{ .Values.trivy.vexSource | default "" | quote }}
            - name: "SCANNER_TRIVY_SKIP_VEX_REPO_UPDATE"
              value: {{ .Values.trivy.skipVEXRepoUpdate | default false | quote }}
```

plus documented defaults in `values.yaml` matching the surrounding comment style.

I searched `goharbor/harbor-helm` for issues and PRs mentioning VEX: **zero results**. Nobody has
asked. That is a clean field and a genuinely easy first contribution — but note it is *cosmetic*
while item 1 is open, because `extraEnvVars` already does the same job. Land it because the setting
deserves to be discoverable, not because it unblocks anything.

---

## What this does not fix

Even with all three landed, Harbor's **UI** still will not show a VEX-suppressed CVE as
"Listed in Allowlist" — that column reads Harbor's per-project `cve_allowlist`, which is a
different mechanism. Trivy applying VEX means the finding is **absent from the report** entirely,
not flagged as allowlisted. The vulnerability tab gets shorter; no row changes colour.

If the goal is specifically that column, that is `goharbor/harbor#22720` territory (Harbor
understanding VEX as a first-class artifact), which carries `needs/design` and no assignee. That is
a design conversation, not a patch.

And it stays true that Harbor's allowlist is **per-project** while our statements are **per-image**:
allowlisting `CVE-2026-34040` for `webgrip` exempts it for every image in the project, including
ones where the code genuinely is reachable. Syncing VEX into the allowlist would make the UI green
by making the claim weaker. Do not do it unless `prevent_vul` is turned on and blocking pulls.

---

## Evidence index

Every claim above, and where it came from. All fetched 2026-08-08.

| Claim | Source |
|---|---|
| adapter passes `--vex` | `goharbor/harbor-scanner-trivy@main:pkg/trivy/wrapper.go:222-228` |
| env var names | `goharbor/harbor-scanner-trivy@main:pkg/etc/config.go:42-43` |
| present in `v0.34.2`+, absent in `v0.33.0` | fetched `pkg/etc/config.go` at each tag |
| VEX support added 2025-08-28; Helm values 2025-12-19 | commit history of `pkg/etc/config.go` |
| Harbor 2.15.2 ships adapter v0.38.0 / Trivy v0.72.0 | `goharbor/harbor@v2.15.2:Makefile` |
| our adapter is v2.15.2 | `homelab-cluster/.../harbor/app/helmrelease.yaml` |
| chart v1.19.1 has `trivy.extraEnvVars` | `goharbor/harbor-helm@v1.19.1:templates/trivy/trivy-sts.yaml:140` |
| discovery drops registry options | `openvex/discovery@main:pkg/probers/oci/prober.go:147-151` |
| Trivy passes no options | `aquasecurity/trivy@v0.72.0:pkg/vex/oci.go:35-43` |
| cosign defaults to `DefaultKeychain` | `sigstore/cosign@main:pkg/oci/remote/options.go:52-54` |
| our Harbor refuses anonymous | `curl https://harbor.webgrip.dev/v2/` → `401` |
| no VEX issues/PRs on harbor-helm | GitHub search, `total_count: 0` |
| #22720 is about the UI | issue page, opened 2026-01-09, `needs/design` |
| what we attest | `.forgejo/actions/cosign-sign-attest/action.yml:320-321` |

Unverified, and flagged as such above: the end-to-end failure of `--vex oci` against our Harbor.

## Related

- [Hardening roadmap](hardening-roadmap.md)
- [SBOM & attestations](sbom-attestations.md)
- ADR-0005 (OpenVEX + CVE budgets)
