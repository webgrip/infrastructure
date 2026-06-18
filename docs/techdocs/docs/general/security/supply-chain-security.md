# Supply Chain Security

## What is software supply chain security?

A software supply chain encompasses every component, tool, process, and person involved in producing and delivering software: source code, dependencies, build systems, CI pipelines, container registries, deployment infrastructure, and the humans who operate them.

Supply chain attacks target the *weakest link in this chain* — often the build system or artifact registry rather than the application itself — because compromising infrastructure that many products depend on produces a much higher attack return than targeting individual applications. The SolarWinds breach (2020), the XZ Utils backdoor (2024), and the PyPI malicious package campaigns are all examples of supply chain attacks at different layers.

## The SLSA framework

[SLSA (Supply chain Levels for Software Artifacts)](https://slsa.dev) is an industry-standard framework that defines progressively stronger guarantees about how software is built.

| Level | Requirement | What it protects against |
|-------|-------------|---------------------------|
| Build L1 | Provenance exists | Basic documentation of build origin |
| Build L2 | Provenance is signed; build uses a hosted build service | Tampering with provenance after the fact |
| Build L3 | Builds are hermetic and non-falsifiable | Compromised build environment |

This repository implements **SLSA Build Level 2**: build provenance is cryptographically signed by GitHub's OIDC service, and the signing is performed on GitHub-hosted infrastructure.

## Our threat model

The threats we specifically address:

### 1. Tampered image after CI push (tag mutation)

**Scenario**: An attacker with write access to GHCR (via a compromised token) overwrites `ghcr.io/webgrip/github-runner:latest` with a backdoored image after CI has already signed and pushed the legitimate version.

**Mitigation**: The cosign signature is anchored to the image *digest* (SHA-256 of the manifest), not the tag. If the tag is reassigned to a different image, the digest changes and the signature no longer verifies. Additionally, Kyverno pins tags to digests at admission time, so Kubernetes always runs the exact image that was signed.

### 2. Build system compromise

**Scenario**: An attacker compromises the GitHub Actions runner or the build workflow, producing a malicious image that is pushed to GHCR.

**Mitigation**: The cosign OIDC certificate is bound to the *exact workflow file path and Git ref* (e.g., `.github/workflows/on_release_published.yml@refs/tags/github-runner-v1.2.3`). An image built by a different workflow or from a different branch will produce a certificate with a different subject — the Kyverno policy will reject it. The Rekor transparency log also provides an append-only audit trail: any signature produced during a compromise would be permanently recorded and detectable.

### 3. Unknown software components

**Scenario**: A base image layer silently introduces a vulnerable library. Without an SBOM, we don't know which components are running in production.

**Mitigation**: Syft generates a CycloneDX SBOM from every released image, enumerating OS packages, language dependencies, and metadata. This SBOM is attested (signed) alongside the image, making it tamper-evident. Tools like GUAC and Dependency-Track can ingest these SBOMs to maintain a live inventory of all components across the fleet.

### 4. Vulnerability blindspot

**Scenario**: A CVE is published for a library included in one of our images. Without automated scanning, we may not learn about it until after exploitation.

**Mitigation**: Trivy scans every image on release and uploads results to GitHub's Security tab in SARIF format. Security findings are visible immediately and can be triaged as GitHub security advisories.

## The signing flow in detail

### GitHub OIDC — no stored keys

Traditional code signing requires managing a private key — generating it, storing it securely, rotating it, and ensuring it's never exfiltrated. GitHub OIDC eliminates this entirely.

When a GitHub Actions workflow runs with `id-token: write` permission, GitHub's OIDC service issues a short-lived JWT that cryptographically proves:

- This token was issued by `https://token.actions.githubusercontent.com`
- The workflow is running in the `webgrip/infrastructure` repository
- The workflow file is `.github/workflows/on_release_published.yml`
- The Git ref is `refs/tags/github-runner-v1.2.3`
- The trigger was a `release` event

### cosign exchanges OIDC token for a signing certificate

cosign presents this OIDC token to Fulcio, Sigstore's certificate authority. Fulcio verifies the token against GitHub's OIDC discovery endpoint, then issues a **short-lived X.509 certificate** (valid for 10 minutes) whose Subject Alternative Name (SAN) encodes the workflow identity.

This certificate is used to sign the image digest. Both the certificate and the signature are recorded in **Rekor**, an append-only transparency log.

```
GitHub OIDC → Fulcio CA → signing certificate
                              ↓
           image digest → cosign sign → Rekor entry
                                           ↓
                                    OCI registry (alongside image)
```

### Why this is strong

Forging a cosign signature for an image requires:

1. Getting GitHub to issue an OIDC token claiming to be `webgrip/infrastructure` `.github/workflows/on_release_published.yml`
2. This requires either compromising GitHub's OIDC service (a Tier-1 attack) or having write access to the repository
3. Any such forgery would be recorded in Rekor and detectable by anomaly detection tools

Compare to a static key: an exfiltrated private key can be used indefinitely, silently, with no entry in any transparency log.

## Framework compliance map

### NIST SSDF (SP 800-218)

| Practice | Task | Our implementation |
|----------|------|-------------------|
| PW.4 | Reuse existing, well-secured software | Trivy CVE scanning on all base images |
| PW.4.1 | Verify third-party software is still secure | Scheduled Trivy scans (via Dependabot / Renovate) |
| RV.1 | Identify and confirm vulnerabilities | Trivy → GitHub Security tab |
| RV.1.3 | Analyze discovered vulnerabilities | SBOM enables precise component identification |
| DS.1 | Store all code and other components | Git; SBOM attested in OCI |
| DS.2.1 | Sign release artifacts | cosign keyless signing |
| DS.6.1 | Provide SBOM for released software | CycloneDX + SPDX SBOM attested in registry |

### CIS Software Supply Chain Security Guide

| Control | Our implementation |
|---------|-------------------|
| 2.3.1 Ensure all artifacts are signed | cosign signatures on all releases |
| 2.3.3 Ensure signing keys are secured | No stored keys — OIDC ephemeral certs |
| 2.4.1 Ensure SBOMs are generated | Syft CycloneDX + SPDX per release |
| 3.2.2 Ensure the build pipeline cannot be altered | Workflow files are branch-protected |
| 4.1.1 Ensure only secure, approved base images are used | Trivy + Renovate automated updates |
