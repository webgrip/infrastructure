# SBOM & Attestations

## What is an SBOM?

A **Software Bill of Materials (SBOM)** is a structured inventory of every software component that makes up an artifact — similar to an ingredients list on food packaging. For a container image, the SBOM enumerates:

- OS packages (Debian/Ubuntu dpkg, Alpine apk, etc.)
- Language-level packages (npm, pip, cargo, composer, gem, etc.)
- Binaries detected by file content analysis
- Metadata: component name, version, supplier, license, package URL (purl)

SBOMs are the foundation of modern vulnerability management: without knowing what's in your software, you cannot know whether a newly published CVE affects you.

## Formats

We generate SBOMs in two standard formats per image release:

### CycloneDX JSON (primary)

[CycloneDX](https://cyclonedx.org) is designed for security use cases. Features:

- Rich component metadata including PURL, CPE, and license expressions
- Native support for VEX (Vulnerability Exploitability eXchange) documents
- Supported by Dependency-Track, GUAC, Grype, and most vulnerability management platforms
- The format used for cosign attestation (predicate type `https://cyclonedx.org/bom`)

### SPDX JSON (secondary)

[SPDX](https://spdx.dev) is the ISO 5962:2021 standard. Features:

- Strong license compliance tooling
- NTIA minimum-element compliant
- Supported by the Linux Foundation's tools, OSS Review Toolkit, and FOSSA

## What is an attestation?

An **attestation** is a signed statement about an artifact. In the OCI ecosystem, attestations are stored alongside the image as additional OCI artifacts in the registry.

An attestation consists of:

1. **Statement** (in-toto format): who is making the claim, about what artifact, using what predicate type
2. **Predicate**: the actual content of the claim (e.g., the CycloneDX SBOM JSON)
3. **Signature**: a cosign signature over the statement, tied to the same OIDC identity used for image signing

### in-toto Statement structure

```json
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "predicateType": "https://cyclonedx.org/bom",
  "subject": [{
    "name": "ghcr.io/webgrip/github-runner",
    "digest": {"sha256": "<digest>"}
  }],
  "predicate": { /* CycloneDX SBOM content */ }
}
```

This statement says: "I (the cosign identity) certify that the artifact `ghcr.io/webgrip/github-runner@sha256:<digest>` has the following SBOM."

## Attestation types we generate

| Predicate type | Tool | Storage | Verification |
|----------------|------|---------|-------------|
| `https://cyclonedx.org/bom` | cosign + Syft | OCI registry (GHCR) | `cosign verify-attestation --type cyclonedx` |
| `https://slsa.dev/provenance/v1` | `actions/attest-build-provenance` | OCI registry + GitHub Attestation store | `gh attestation verify` |

## Inspecting attestations

### Download and inspect the SBOM

```bash
# Download raw attestation bundle
cosign download attestation ghcr.io/webgrip/<image>@sha256:<digest>

# Extract and pretty-print the CycloneDX SBOM
cosign download attestation ghcr.io/webgrip/<image>@sha256:<digest> \
  | jq -r 'select(.payload) | .payload' \
  | base64 -d \
  | jq '.predicate'

# List all component names and versions
cosign download attestation ghcr.io/webgrip/<image>@sha256:<digest> \
  | jq -r 'select(.payload) | .payload' \
  | base64 -d \
  | jq -r '.predicate.components[] | "\(.name) \(.version)"'
```

### Verify the SBOM attestation (signature check)

```bash
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity \
    'https://github.com/webgrip/infrastructure/.github/workflows/on_release_published.yml@refs/tags/<tag>' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/webgrip/<image>@sha256:<digest> \
  | jq '.payload | @base64d | fromjson | .predicate.metadata'
```

### Inspect SLSA provenance

```bash
# Via GitHub CLI (verifies against GitHub's attestation store)
gh attestation verify oci://ghcr.io/webgrip/<image>@sha256:<digest> \
  --owner webgrip \
  --format json \
  | jq '.[0].verificationResult.statement.predicate'

# Verify fields of interest
gh attestation verify oci://ghcr.io/webgrip/<image>@sha256:<digest> \
  --owner webgrip \
  --format json \
  | jq '.[0].verificationResult.statement.predicate | {
      builder: .builder.id,
      source: .buildDefinition.externalParameters.workflow.ref,
      runId: .runDetails.metadata.invocationId
    }'
```

## Integration with Dependency-Track and GUAC

The generated CycloneDX SBOMs can be automatically ingested into the cluster's SBOM analysis tools.

### Dependency-Track

```bash
# Download the SBOM and upload to Dependency-Track
cosign download attestation ghcr.io/webgrip/<image>@sha256:<digest> \
  | jq -r 'select(.payload) | .payload' | base64 -d \
  | jq -c '.predicate' > sbom.cdx.json

curl -X PUT \
  -H "X-Api-Key: ${DT_API_KEY}" \
  -H "Content-Type: multipart/form-data" \
  -F "project=${DT_PROJECT_UUID}" \
  -F "bom=@sbom.cdx.json" \
  https://dependency-track.your-cluster/api/v1/bom
```

### GUAC

GUAC (Graph for Understanding Artifact Composition) can ingest OCI attestations directly from the registry using its `oci` collector. Configure the collector with the GHCR endpoint to continuously harvest SBOMs and build a dependency graph across all images.

## Workflow artifact download

SBOM files are also uploaded as GitHub Actions workflow artifacts with a 90-day retention period. Access them from:

**GitHub UI**: Repository → Actions → Select the release workflow run → Artifacts

**GitHub CLI**:
```bash
gh run download <run-id> --name sbom-<image>-<version>.cdx.json
```
