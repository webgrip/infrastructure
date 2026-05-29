# Kyverno Enforcement

## Overview

The homelab cluster uses [Kyverno](https://kyverno.io) to enforce supply chain security policies at admission time. When a Pod is submitted to the Kubernetes API, Kyverno intercepts the request and verifies that any `ghcr.io/webgrip/*` images are:

1. Signed by the `webgrip/infrastructure` release workflow via cosign
2. Accompanied by an attested CycloneDX SBOM

If verification fails in `Enforce` mode, the Pod is rejected before any containers are started.

## The policy

The policy is defined in `ops/kyverno/cluster-policies/verify-webgrip-images.yaml` in this repository. Apply it to the cluster:

```bash
# Apply directly
kubectl apply -f ops/kyverno/cluster-policies/verify-webgrip-images.yaml

# Or add to the homelab-cluster GitOps repo:
# copy to kubernetes/apps/security/kyverno-policies/verify-webgrip-images.yaml
# and add to kustomization.yaml
```

## Rollout strategy

The policy ships in `Audit` mode. Switch to `Enforce` only after verifying all running webgrip images are signed.

### Step 1: Apply in Audit mode and monitor

```bash
# Apply the policy
kubectl apply -f ops/kyverno/cluster-policies/verify-webgrip-images.yaml

# Monitor PolicyReport for violations
kubectl get policyreport -A
kubectl get clusterpolicyreport

# List all failing resources
kubectl get policyreport -A -o json \
  | jq '.items[].results[] | select(.result == "fail")'
```

### Step 2: Sign existing images

For any image that was published before this signing pipeline, create a new GitHub Release to trigger the signing workflow. Alternatively, re-sign an existing image manually:

```bash
# Sign an existing image manually (requires id-token from a GitHub Actions context,
# or use a local key for one-off signing during migration)
cosign sign \
  --key cosign.key \
  ghcr.io/webgrip/<image>@sha256:<digest>
```

### Step 3: Switch to Enforce

Once PolicyReport shows no violations:

```bash
# Edit the policy
kubectl patch clusterpolicy verify-webgrip-images \
  --type='json' \
  -p '[{"op": "replace", "path": "/spec/validationFailureAction", "value": "Enforce"}]'

# Or update the YAML and re-apply
```

## Understanding the policy rules

### `mutateDigest: true`

When Kyverno admits a Pod, it rewrites any image tag to include the resolved digest:

```
ghcr.io/webgrip/github-runner:1.2.3
  → ghcr.io/webgrip/github-runner@sha256:abc123...
```

This means the container runtime always pulls the exact image that was signed — tag reassignment after signing has no effect on running workloads.

### `required: true`

Pods containing `ghcr.io/webgrip/*` images without a valid signature are blocked (in `Enforce` mode) or generate a PolicyReport violation (in `Audit` mode). Images from other registries are not affected.

### Namespace exclusions

The policy excludes system namespaces by default:

```yaml
exclude:
  any:
    - resources:
        namespaces:
          - kube-system
          - flux-system
          - cert-manager
          - security
          - monitoring
          - network
          - storage
```

Expand or reduce this list to match your cluster's structure.

## Viewing Kyverno reports

```bash
# All policy reports (namespace-scoped)
kubectl get policyreport -A

# Cluster-wide policy report summary
kubectl get clusterpolicyreport

# Detailed violations for a namespace
kubectl get policyreport -n <namespace> -o json \
  | jq '.results[] | select(.result == "fail") | {resource: .resources[0].name, message: .message}'
```

In the homelab cluster, policy-reporter aggregates these reports and exposes them in Grafana dashboards.

## Testing the policy

```bash
# Test with an unsigned image (should fail in Enforce mode)
kubectl run test-unsigned \
  --image=ghcr.io/webgrip/github-runner:latest \
  --dry-run=server

# Test with a signed image (should succeed)
# First verify the signature manually:
cosign verify \
  --certificate-identity-regexp 'https://github.com/webgrip/infrastructure/.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/webgrip/<image>@sha256:<digest>

# Then apply a test pod manifest
kubectl apply --dry-run=server -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-signed
  namespace: default
spec:
  containers:
    - name: runner
      image: ghcr.io/webgrip/<image>@sha256:<digest>
  restartPolicy: Never
EOF
```

## Kyverno + GUAC integration

For advanced supply chain governance, GUAC (running in the `security` namespace) can be used as a policy information point: query GUAC's GraphQL API to determine whether a given image has known vulnerabilities before admitting it. This requires a custom Kyverno `generate` or `validate` rule with an external data source call to the GUAC API.
