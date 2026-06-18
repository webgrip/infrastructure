# Image Signing with cosign

## Overview

All container images published from this repository are signed using [cosign](https://docs.sigstore.dev/cosign/overview/) via Sigstore's **keyless** signing flow. This means:

- No private keys are stored in GitHub Secrets or any KMS.
- Signatures are cryptographically bound to the exact GitHub Actions workflow that produced them.
- All signatures are publicly logged in [Rekor](https://rekor.sigstore.dev), an append-only transparency log.

## How the signing works

### 1. GitHub OIDC token

When the `release-sign-and-attest` job runs with `id-token: write` permission, GitHub issues an OIDC JWT for the workflow invocation.

### 2. Fulcio certificate

cosign exchanges the OIDC token with [Fulcio](https://docs.sigstore.dev/fulcio/overview/), Sigstore's CA. Fulcio issues a short-lived X.509 certificate (10-minute TTL) where the Subject Alternative Name (SAN) is:

```
https://github.com/webgrip/infrastructure/.github/workflows/on_release_published.yml@refs/tags/<tag>
```

This SAN is the **cryptographic identity** of the signer. It encodes: which organization, which repository, which workflow file, and which Git ref signed this image. Forging this requires compromising GitHub's OIDC infrastructure.

### 3. Signature stored in OCI registry

The signature and certificate are stored as an OCI artifact in GHCR alongside the image, using the cosign OCI layout. When you pull an image, you can also pull its signature:

```bash
cosign download signature ghcr.io/webgrip/<image>@sha256:<digest>
```

### 4. Rekor transparency log entry

Every signature is also submitted to [Rekor](https://rekor.sigstore.dev), creating a timestamped, tamper-evident log entry. This entry can be independently verified even if the OCI registry is unavailable.

## Verifying a signature

### Basic verification

```bash
# Verify that the image was signed by the webgrip/infrastructure release workflow
cosign verify \
  --certificate-identity \
    'https://github.com/webgrip/infrastructure/.github/workflows/on_release_published.yml@refs/tags/<tag>' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/webgrip/<image>@sha256:<digest>
```

Expected output:
```json
[{
  "critical": {
    "identity": {"docker-reference": "ghcr.io/webgrip/<image>"},
    "image": {"docker-manifest-digest": "sha256:<digest>"},
    "type": "cosign container image signature"
  },
  "optional": {
    "Issuer": "https://token.actions.githubusercontent.com",
    "Subject": "https://github.com/webgrip/infrastructure/.github/workflows/on_release_published.yml@refs/tags/<tag>"
  }
}]
```

### Verify with regex subject (all releases)

```bash
cosign verify \
  --certificate-identity-regexp \
    'https://github.com/webgrip/infrastructure/.github/workflows/on_release_published.yml@refs/tags/.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/webgrip/<image>:latest
```

### Search Rekor for all signatures of an image

```bash
# List all Rekor entries for this image
cosign search tlog --artifact-type image \
  ghcr.io/webgrip/<image>@sha256:<digest>

# Inspect a specific Rekor log entry by log index
rekor-cli get --log-index <index> --format json | jq
```

### Verify SLSA provenance via GitHub CLI

```bash
# Verify GitHub native SLSA attestation
gh attestation verify oci://ghcr.io/webgrip/<image>@sha256:<digest> \
  --owner webgrip
```

## What Kyverno checks

In the homelab cluster, the `verify-webgrip-images` Kyverno ClusterPolicy:

1. **Intercepts** every Pod admission request containing a `ghcr.io/webgrip/*` image.
2. **Resolves** the tag to its digest (obtaining the immutable image reference).
3. **Verifies** the cosign signature against the expected subject and issuer.
4. **Verifies** the CycloneDX SBOM attestation is present and signed by the same identity.
5. **Mutates** the Pod spec to use the digest reference, preventing tag-mutation attacks on running workloads.
6. **Rejects** (when in `Enforce` mode) any Pod whose images fail verification.

## Troubleshooting

### `MANIFEST_UNKNOWN` or `404 Not Found` when verifying

The image reference must include the full registry hostname. GHCR requires authentication even for public images when verifying signatures:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin
cosign verify ... ghcr.io/webgrip/<image>@sha256:<digest>
```

### `no signatures found`

The image was published before this signing pipeline was introduced. Re-release the image (create a new GitHub Release) to trigger signing.

### Certificate subject does not match

This happens if:
- The workflow file was renamed after signing
- A prerelease image is checked against a tag-only policy
- The image was built from a fork

Check the actual subject with:
```bash
cosign verify ... 2>&1 | jq '.[0].optional.Subject'
```
