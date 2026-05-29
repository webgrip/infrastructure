# Infrastructure

This is where stuff goes that doesn't fit anywhere else

## Docker images

### Helm Deploy
This image is used to deploy helm charts to a kubernetes cluster.

### Github Actions Runner
This image is used to run github actions. It is based on the `actions/runner` image and has the helm binary installed.

## Local GitHub Actions validation with ACT

```bash
# smoke-test the supply-chain composite action locally (no OIDC signing / no registry mutation)
act workflow_dispatch -W .github/workflows/act_supply_chain_smoke.yml

# simulate release payload execution locally
act release -W .github/workflows/on_release_published.yml -e .github/act/release-published.event.json
```
