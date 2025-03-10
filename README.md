# Infrastructure

This is where stuff goes that doesn't fit anywhere else

## Docker images

### Helm Deploy
This image is used to deploy helm charts to a kubernetes cluster. It is based on the `lachlanevenson/k8s-kubectl` image and has the helm binary installed.

### Github Actions Runner
This image is used to run github actions. It is based on the `actions/runner` image and has the helm binary installed.