# Supply Chain Security: Keyless Image Signing, SBOM Attestation, and SLSA Provenance

* Status: accepted
* Deciders: WebGrip Ops Team, Infrastructure Contributors
* Date: 2024-12-01
* Supersedes: N/A
* Related to: [ADR-0001](0001-docker-image-architecture.md) — Docker Image Architecture

## Context and Problem Statement

WebGrip builds and distributes container images used in production Kubernetes workloads. Until now, there has been no way for the cluster to verify that a running image was actually built by our CI pipeline and has not been tampered with between build and deployment.

This creates a specific class of risks:

- **Tag mutation attacks**: An attacker with write access to GHCR could overwrite a tag (e.g., `latest`) after CI pushed a verified image, causing the cluster to pull a malicious image with no indication of tampering.
- **Compromised registry**: If GHCR were compromised, there would be no mechanism to detect that images had been replaced.
- **Dependency confusion / typosquatting**: Base image layers could be swapped in a registry mirror without any integrity check.
- **Regulatory exposure**: EU Cyber Resilience Act (CRA), NIST SSDF (SP 800-218), and SLSA requirements increasingly mandate software supply chain traceability for components used in production systems.

We needed a solution that:
1. Does not require managing long-lived signing keys (operationally complex, security risk).
2. Produces machine-verifiable artifacts that can be checked by the cluster's admission controller.
3. Generates an auditable software bill of materials for every released image.
4. Integrates with existing GitHub Actions workflows with minimal changes.

## Decision Drivers

* **Zero stored secrets**: The signing infrastructure must not require creating or managing private keys in GitHub Secrets or a KMS.
* **Standards compliance**: Must satisfy SLSA Build Level 2 minimum requirements and NIST SSDF PW.4 (verify third-party software).
* **Cluster enforcement**: The cluster's admission controller must be able to reject unsigned images at deploy time.
* **Auditability**: Every image publication must produce a tamper-evident record linking the artifact to its source commit, workflow, and build environment.
* **Operational simplicity**: Adding signing to a new image should require only adding the composite action call — no per-image key management.

## Considered Options

* **Option 1**: Cosign with a static key pair stored in GitHub Secrets
* **Option 2**: Cosign keyless signing with GitHub OIDC (Sigstore)
* **Option 3**: Notary v2 (notation) with a CA-managed certificate
* **Option 4**: Docker Content Trust (DCT) with Notary v1
* **Option 5**: No signing (status quo)

## Decision Outcome

Chosen option: **Option 2 — Cosign keyless signing with GitHub OIDC**, because it eliminates the operational burden of key management while providing cryptographically stronger guarantees: the signing certificate is bound to the exact GitHub Actions workflow invocation, not just to a key that could be exfiltrated and used outside CI.

Additionally:
- **Syft** generates CycloneDX + SPDX SBOMs from each released image, attached as signed in-toto attestations.
- **GitHub native attestations** (`actions/attest-build-provenance`) record SLSA v1.0 Build Provenance in GitHub's attestation store.
- **Trivy** scans each image and publishes results to the GitHub Security tab via SARIF.
- **Kyverno** in the homelab cluster enforces signature + SBOM attestation presence at admission time.

### Positive Consequences

* No long-lived signing keys to rotate, audit, or accidentally leak.
* Signatures are publicly verifiable by anyone using `cosign verify` — no access to our infrastructure required.
* The Rekor transparency log provides an append-only audit trail of every image signature ever created.
* SBOM attestations enable downstream consumers (GUAC, Dependency-Track) to ingest component data automatically.
* Tag-pinning via Kyverno (`mutateDigest: true`) eliminates tag mutation as an attack vector in the cluster.
* NTIA minimum element compliance is met by the generated SBOMs.
* GitHub Security tab provides a vulnerability dashboard populated automatically by Trivy.

### Negative Consequences

* Keyless signing requires `id-token: write` permission on the signing job. Teams must be aware of this when reviewing workflow permissions.
* The Rekor transparency log is public — the fact that we signed an image is public information (though image contents remain private).
* Pre-existing images (before this ADR) are not signed. A migration strategy is needed before switching Kyverno policies to `Enforce` mode.
* If `token.actions.githubusercontent.com` is unavailable during a release, signing will fail. This is mitigated by Rekor's built-in retry logic and the fact that signing is a post-build step (the image is already distributed).

## Pros and Cons of the Options

### Option 1: Cosign with a static key pair

* Good, because simpler conceptual model (private key = identity).
* Good, because works in air-gapped environments.
* Bad, because the private key must be stored in GitHub Secrets — an exfiltrated key can sign arbitrary images indefinitely without detection.
* Bad, because key rotation is manual and operationally risky.
* Bad, because no binding between the key and the specific CI run that performed the signing.

### Option 2: Cosign keyless signing with GitHub OIDC (chosen)

* Good, because no long-lived secrets — each signature uses a fresh ephemeral certificate.
* Good, because the certificate is bound to the exact workflow file path and Git ref — forgery requires compromising GitHub's OIDC service.
* Good, because all signatures are publicly logged in Rekor, enabling independent verification and anomaly detection.
* Good, because integrates natively with GitHub Actions using the existing OIDC mechanism.
* Bad, because requires internet access to Fulcio and Rekor during signing (mitigated: these are HA public services).
* Bad, because transparency log is public (feature, not bug, for most use cases).

### Option 3: Notary v2 (notation)

* Good, because OCI-native, strong enterprise adoption.
* Good, because supports pluggable CA backends (AWS Signer, Azure Key Vault, etc.).
* Bad, because requires managing a CA or cloud signing service — more operational complexity.
* Bad, because Kyverno's `verifyImages` is better integrated with cosign than with notation.
* Bad, because not yet as mature in the GitHub Actions ecosystem as cosign.

### Option 4: Docker Content Trust (DCT)

* Bad, because Notary v1 is deprecated.
* Bad, because poor ecosystem support — most modern tooling (Kyverno, Tekton Chains, etc.) has dropped DCT support.
* Bad, because requires Notary infrastructure.

### Option 5: No signing (status quo)

* Bad, because no integrity guarantee for deployed images.
* Bad, because increasing regulatory exposure (CRA, NIST SSDF).
* Bad, because no SBOM — no visibility into what software is actually running.

## Implementation Details

### Architecture

```
GitHub Release
     │
     ▼
[release-distribute-ghcr]         Builds and pushes image to GHCR
     │                            (existing reusable workflow)
     ▼
[release-sign-and-attest]         New job in on_release_published.yml
     ├── cosign sign               Signs image digest → Rekor log entry
     ├── syft (CycloneDX)         Generates SBOM inventory
     ├── cosign attest            Attaches SBOM as in-toto attestation
     ├── attest-build-provenance  Records SLSA provenance in GitHub store
     └── trivy                    Scans for CVEs → GitHub Security tab
```

### Key files

| File | Purpose |
|------|---------|
| `.github/actions/cosign-sign-attest/action.yml` | Reusable composite action implementing the full signing pipeline |
| `.github/workflows/on_release_published.yml` | Updated to invoke the composite action after each image push |
| `ops/kyverno/cluster-policies/verify-webgrip-images.yaml` | Kyverno ClusterPolicy for cluster-side enforcement |

### Rollout strategy

1. Merge this PR — all future releases will be signed automatically.
2. Re-release (or retag) existing images to get them signed.
3. Apply Kyverno policy in `Audit` mode — monitor PolicyReports.
4. Once all running webgrip images are signed, switch to `Enforce`.

### Verification

```bash
# Verify a cosign signature
cosign verify \
  --certificate-identity 'https://github.com/webgrip/infrastructure/.github/workflows/on_release_published.yml@refs/tags/<tag>' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/webgrip/<image>@sha256:<digest>

# Inspect the attested SBOM
cosign download attestation ghcr.io/webgrip/<image>@sha256:<digest> \
  | jq -r 'select(.payload) | .payload' | base64 -d | jq '.predicate'

# Verify SLSA provenance via GitHub CLI
gh attestation verify oci://ghcr.io/webgrip/<image>@sha256:<digest> --owner webgrip
```

## Links

* [Sigstore / cosign documentation](https://docs.sigstore.dev)
* [SLSA framework](https://slsa.dev)
* [NIST SSDF (SP 800-218)](https://csrc.nist.gov/publications/detail/sp/800-218/final)
* [NTIA Minimum Elements for an SBOM](https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom)
* [Kyverno verifyImages documentation](https://kyverno.io/docs/writing-policies/verify-images/)
* [CycloneDX specification](https://cyclonedx.org/specification/overview/)
* [Supply Chain Security documentation](../techdocs/docs/security/supply-chain-security.md)
