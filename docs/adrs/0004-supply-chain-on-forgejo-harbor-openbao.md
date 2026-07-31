# Signing, SBOM and attestation on self-hosted Forgejo, Harbor and OpenBao

* Status: accepted
* Deciders: WebGrip Ops Team
* Date: 2026-07-31
* Supersedes: [ADR-0002](0002-supply-chain-security.md) — Supply Chain Security: Keyless Image Signing, SBOM Attestation, and SLSA Provenance
* Related to: [ADR-0001](0001-docker-image-architecture.md), [ADR-0005](0005-openvex-and-cve-budgets.md)

## Context and Problem Statement

[ADR-0002](0002-supply-chain-security.md) chose cosign **keyless** signing with GitHub OIDC: an
ephemeral Fulcio certificate bound to a workflow identity, logged in the public Rekor transparency
log, with SLSA provenance from `actions/attest-build-provenance` and Trivy SARIF uploaded to the
GitHub Security tab. Every one of those mechanisms is GitHub-shaped.

The platform then moved off GitHub. Source lives in self-hosted Forgejo, images in self-hosted
Harbor, secrets in self-hosted OpenBao. The keyless model does not survive the move intact:

- **There is no Fulcio for Forgejo.** Fulcio issues certificates against a fixed set of OIDC
  issuers. A self-hosted Forgejo is not one of them, so a keyless signature would either be
  impossible or would require exposing our identity provider to the public Sigstore infrastructure.
- **Rekor is public and external.** Keyless verification requires a transparency-log lookup, which
  means every release publishes our image digests and build timestamps to a world-readable
  append-only log, and every admission decision in the cluster depends on reaching the internet.
  For a homelab whose entire point is that the supply chain runs on infrastructure we own, that is
  the wrong dependency in the wrong direction.
- **The GitHub-only steps have no analog.** `actions/attest-build-provenance` and the SARIF upload
  to the GitHub Security tab do not exist on Forgejo.

The migration happened incrementally and the decision record did not keep up. ADR-0002 described a
pipeline that no longer ran, and this repository carried a `ops/kyverno/cluster-policies/verify-webgrip-images.yaml`
that still matched `ghcr.io/webgrip/*` against a Fulcio identity — a policy that could never match a
Harbor image nor verify an OpenBao-signed one. It was dead code that read as a live guarantee.

The question this record answers: **what replaces keyless signing when the identity provider,
registry and key store are all self-hosted, and what is knowingly given up?**

## Decision Drivers

* **No long-lived private key on disk or in CI secrets.** The original driver from ADR-0002 survives
  the migration unchanged and is non-negotiable.
* **No dependency on public Sigstore infrastructure** at sign time or at admission time.
* **Signing authority must be bound to the pipeline, not to a person or a shared runner.** A runner
  compromise must not yield a reusable signing capability.
* **Verifiable by the cluster** — Kyverno must be able to check signature and attestation at
  admission without an internet round-trip.
* **Image digests must not be published externally.** A homelab's release cadence and internal image
  inventory are not information we wish to broadcast.

## Considered Options

* **Option 1**: cosign with an OpenBao Transit key, Forgejo OIDC → OpenBao JWT auth (chosen)
* **Option 2**: cosign keyless against public Fulcio/Rekor, using Forgejo as the OIDC issuer
* **Option 3**: cosign with a static key pair stored in Forgejo Actions secrets
* **Option 4**: Notary v2 (notation) with a self-managed CA

## Decision Outcome

Chosen option: **Option 1 — cosign signing through an OpenBao Transit key, with the signing
capability granted per-job via Forgejo OIDC**, because it preserves the "no exfiltratable key"
property that motivated keyless signing while removing every external dependency.

The mechanism, as implemented in
[`.forgejo/actions/cosign-sign-attest/action.yml`](../../.forgejo/actions/cosign-sign-attest/action.yml):

1. The signing job requests a per-job OIDC token from Forgejo (`enable-openid-connect: true`).
2. That token is exchanged at OpenBao's `auth/forgejo` JWT backend for a short-lived token whose
   role (`cosign-signer`) is bound to this repository and to `event_name` — so only this
   repository's release workflow can obtain signing capability.
3. `cosign sign --key hashivault://cosign-webgrip` signs the image. **The private key never leaves
   OpenBao**; cosign calls the Transit sign API over the network and receives a signature back.
4. Syft generates a CycloneDX SBOM, attested with the same key.
5. `--tlog-upload=false` on both operations: with a static key there is no need for a transparency
   log, and verification is key-only.

Cluster-side verification is the `image-verify-harbor-audit` ClusterPolicy in
`webgrip/homelab-cluster`, which reads the Transit **public** key from the `cosign-webgrip-pub`
ConfigMap in the `security` namespace and sets `rekor.ignoreTlog: true` to match. That policy — not
a copy in this repository — is the single source of truth for admission. The stale copy here was
deleted; a security policy duplicated across two repositories is a policy that will disagree with
itself, and this one already had.

### Positive Consequences

* The private key is generated inside OpenBao and is not extractable — strictly stronger than a key
  in CI secrets, and equivalent to keyless in the property that mattered.
* Signing capability is bound to a Forgejo OIDC claim set, so it expires with the job and cannot be
  replayed from a developer machine or another repository.
* No internet dependency at sign time or at admission time. A Sigstore outage cannot stop a release
  or an admission decision.
* Image digests and release timestamps stay inside the LAN.
* The same key signs the SBOM and (per [ADR-0005](0005-openvex-and-cve-budgets.md)) the OpenVEX
  document, so one public key verifies the whole evidence chain.

### Negative Consequences

* **No public transparency log.** With keyless, a third party could detect a forged signature by
  auditing Rekor. Here, an OpenBao compromise combined with registry write access would be
  undetectable from outside. Mitigation is OpenBao's own audit log — which is a weaker guarantee,
  and this record states so plainly rather than claiming parity.
* **No SLSA build provenance attestation.** `actions/attest-build-provenance` has no Forgejo analog,
  so the SLSA Build Level 2 claim in ADR-0002 is **not currently met**. The signature proves *who*
  built the image; nothing currently proves *how*. This is the largest single regression from the
  migration and is tracked as remediation work, not quietly dropped.
* **No SARIF to a security dashboard.** Replaced by the in-pipeline CVE budget gate
  ([ADR-0005](0005-openvex-and-cve-budgets.md)) plus Harbor's own scanner and the in-cluster Trivy
  Operator, which is arguably better placed but is a different artifact with a different audience.
* Verification requires distributing the public key to every verifier, which keyless avoided.
* OpenBao becomes a release-critical dependency: if it is down, releases cannot be signed.

### Confirmation

The decision is implemented if all four of these hold:

```bash
# 1. A released image carries a signature verifiable by the Transit public key alone
#    (no Rekor lookup, no Fulcio cert).
kubectl -n security get configmap cosign-webgrip-pub -o jsonpath='{.data.cosign\.pub}' > /tmp/cosign.pub
cosign verify --key /tmp/cosign.pub --insecure-ignore-tlog=true \
  harbor.webgrip.dev/webgrip/semantic-release@sha256:<digest>

# 2. The CycloneDX SBOM attestation is present and parses at spec 1.6
cosign download attestation --predicate-type=https://cyclonedx.org/bom \
  harbor.webgrip.dev/webgrip/semantic-release@sha256:<digest> \
  | jq -r '.payload' | base64 -d | jq -r '.predicate.specVersion'   # => 1.6

# 3. Admission verification is live and passing, not merely installed
kubectl get polr -A -o json | jq -r \
  '.items[].results[]? | select(.policy=="image-verify-harbor-audit") | .result' | sort | uniq -c

# 4. No signing key material exists outside OpenBao
kubectl -n security get secrets -o name | grep -i cosign   # => public key ConfigMap only
```

Check 3 currently reports both `pass` and `fail` results; the failures are `missing digest` on
workloads deployed by tag, which is a *consumer* defect (see More Information), not a signing defect.

## Pros and Cons of the Options

### Option 1: OpenBao Transit key with Forgejo OIDC (chosen)

* Good, because the private key is non-extractable by construction.
* Good, because signing capability is short-lived and bound to a pipeline identity.
* Good, because it has no external network dependency in either direction.
* Neutral, because it requires distributing a public key — a small, well-understood operational task.
* Bad, because it forfeits public transparency-log auditability.
* Bad, because OpenBao availability becomes a release dependency.

### Option 2: Keyless against public Fulcio/Rekor with Forgejo as issuer

* Good, because it would preserve the ADR-0002 model unchanged, including Rekor auditability.
* Bad, because Fulcio does not accept arbitrary self-hosted OIDC issuers — this is close to
  impossible rather than merely difficult.
* Bad, because it would publish our internal image inventory to a public log.
* Bad, because it makes both releases and admission decisions depend on internet reachability.

### Option 3: Static key pair in Forgejo Actions secrets

* Good, because it is trivial to implement and has no new infrastructure.
* Bad, because an exfiltrated key signs arbitrary images indefinitely, undetectably — the exact
  risk ADR-0002 rejected. Moving registries does not make it acceptable.
* Bad, because key rotation is manual and touches every verifier.

### Option 4: Notary v2 / notation with a self-managed CA

* Good, because it is OCI-native and Harbor supports it directly.
* Bad, because running a CA is more operational surface than running a Transit key.
* Bad, because Kyverno's `verifyImages` support for notation is less mature than for cosign, and
  the cluster's other policies are already cosign-shaped.

## More Information

* Technical story: migration from GitHub Actions/GHCR to self-hosted Forgejo/Harbor, tracked across
  `webgrip/homelab-cluster` ADR-0036 (amd64-only Harbor publish) and the Harbor RFC.
* 2024-12-01 — original keyless decision recorded ([ADR-0002](0002-supply-chain-security.md), `001fc74`)
* 2026-06-17 — `image-verify-harbor-audit` ClusterPolicy created in `webgrip/homelab-cluster`,
  establishing key-based Harbor verification alongside the legacy GHCR keyless policy
* 2026-07-19 — syft bumped v1.21.0 → v1.48.0 (`5da16be`), silently moving SBOM output to
  CycloneDX 1.7 and breaking Dependency-Track ingestion until 2026-07-31
* 2026-07-31 — GHCR publishing confirmed removed; stale `ops/kyverno/cluster-policies/` deleted;
  SBOM spec pinned to 1.6; this record supersedes ADR-0002
* Supported by: [ADR-0005](0005-openvex-and-cve-budgets.md) — the gate that gives the signature its
  meaning
* Open remediation: SLSA build provenance has no Forgejo analog; see the hardening roadmap in
  [`docs/techdocs/docs/general/security/hardening-roadmap.md`](../techdocs/docs/general/security/hardening-roadmap.md)
