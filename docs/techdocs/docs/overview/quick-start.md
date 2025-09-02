# Quick Start Guide

Get up and running with WebGrip Infrastructure in minutes, not hours.

## Prerequisites

Before you begin, ensure you have:

- [Docker](https://docs.docker.com/get-docker/) installed and running
- [Git](https://git-scm.com/downloads) for cloning repositories
- Access to the WebGrip organization on GitHub

## Option 1: Using Pre-built Images (Recommended)

The fastest way to get started is using our pre-built images from Docker Hub.

### 🦀 Rust Development

```bash
# Pull the latest Rust CI image
docker pull webgrip/rust-ci-runner:latest

# Start a Rust development environment
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  webgrip/rust-ci-runner:latest \
  bash

# Inside the container, you now have access to:
# - Rust toolchain (latest stable)
# - cargo-audit, cargo-tarpaulin
# - Common build tools
```

### 🎭 End-to-End Testing

```bash
# Pull the Playwright testing image
docker pull webgrip/playwright-runner:latest

# Run in your project directory with tests
docker run -it --rm \
  -v $(pwd):/app \
  -w /app \
  webgrip/playwright-runner:latest \
  npx playwright test
```

### ⚙️ Local GitHub Actions Testing

```bash
# Pull the ACT runner image
docker pull webgrip/act-runner:latest

# Test your GitHub Actions workflows locally
docker run -it --rm \
  -v $(pwd):/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -w /workspace \
  webgrip/act-runner:latest \
  act
```

### ☸️ Kubernetes Deployment

```bash
# Pull the Helm deployment image  
docker pull webgrip/helm-deploy:latest

# Deploy to Kubernetes (requires kubectl config)
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.kube:/root/.kube \
  -w /workspace \
  webgrip/helm-deploy:latest \
  helm upgrade --install myapp ./charts/myapp
```

## Option 2: Building Locally

If you need to modify images or test local changes:

### Clone the Repository

```bash
git clone https://github.com/webgrip/infrastructure.git
cd infrastructure
```

### Build Specific Images

```bash
# Build all images
docker-compose build

# Or build specific images
docker build -t my-rust-ci ops/docker/rust-ci-runner/
docker build -t my-playwright ops/docker/playwright-runner/
docker build -t my-helm-deploy ops/docker/helm-deploy/
```

### Verify Local Builds

```bash
# Test the Rust CI runner
docker run --rm my-rust-ci rustc --version

# Test the Playwright runner  
docker run --rm my-playwright npx playwright --version

# Test the Helm deploy image
docker run --rm my-helm-deploy helm version
```

## Common Use Cases

### 🔄 Setting Up CI/CD for a New Project

1. **Choose the appropriate images** for your technology stack:
   ```yaml
   # .github/workflows/ci.yml
   jobs:
     test:
       runs-on: ubuntu-latest
       container: webgrip/rust-ci-runner:latest
       steps:
         - uses: actions/checkout@v4
         - run: cargo test
   
     e2e-test:
       runs-on: ubuntu-latest  
       container: webgrip/playwright-runner:latest
       steps:
         - uses: actions/checkout@v4
         - run: npx playwright test
   ```

2. **Configure deployment** using the Helm image:
   ```yaml
   deploy:
     needs: [test, e2e-test]
     runs-on: ubuntu-latest
     container: webgrip/helm-deploy:latest
     steps:
       - uses: actions/checkout@v4
       - run: helm upgrade --install myapp ./charts/myapp
   ```

### 🧪 Local Development Workflow

1. **Start your development environment**:
   ```bash
   # For Rust projects
   docker run -it --rm -v $(pwd):/workspace -w /workspace \
     webgrip/rust-ci-runner:latest bash
   ```

2. **Test your changes locally** before pushing:
   ```bash
   # Test GitHub Actions workflows
   docker run -it --rm -v $(pwd):/workspace -w /workspace \
     -v /var/run/docker.sock:/var/run/docker.sock \
     webgrip/act-runner:latest act
   ```

3. **Run end-to-end tests**:
   ```bash
   docker run -it --rm -v $(pwd):/app -w /app \
     webgrip/playwright-runner:latest npx playwright test
   ```

### 🚀 Release Process

For Rust projects, use our release automation:

```bash
# Pull the release image
docker pull webgrip/rust-releaser:latest

# Run release process (configure via environment variables)
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  -e GITHUB_TOKEN=$GITHUB_TOKEN \
  webgrip/rust-releaser:latest \
  ./release-script.sh
```

## Environment-Specific Configurations

### Development Environment

```bash
# Use latest images for development
export IMAGE_TAG=latest

# Enable verbose logging
export RUST_LOG=debug
export PLAYWRIGHT_DEBUG=1
```

### Production Environment

```bash
# Use specific SHA tags for production
export IMAGE_TAG=${{ github.sha }}

# Optimize for production
export RUST_LOG=info
export NODE_ENV=production
```

## Troubleshooting

### Common Issues

**"Permission denied" errors**
```bash
# Fix file permissions
docker run --rm -v $(pwd):/workspace -w /workspace \
  webgrip/rust-ci-runner:latest \
  chown -R $(id -u):$(id -g) .
```

**Image not found**
```bash
# Verify image exists
docker images | grep webgrip

# Pull latest version
docker pull webgrip/rust-ci-runner:latest
```

**Container exits immediately**
```bash
# Check container logs
docker logs <container-id>

# Run with interactive shell for debugging
docker run -it --entrypoint=/bin/bash webgrip/rust-ci-runner:latest
```

### Getting Help

1. **Check the logs** first:
   ```bash
   docker logs -f <container-name>
   ```

2. **Verify image integrity**:
   ```bash
   docker inspect webgrip/rust-ci-runner:latest
   ```

3. **Test with minimal setup**:
   ```bash
   docker run --rm webgrip/rust-ci-runner:latest rustc --version
   ```

## Next Steps

Now that you're up and running:

1. **Explore individual images**: Check out detailed documentation for each [Docker image](../docker-images/)
2. **Understand the CI/CD pipeline**: Learn about our [automated building process](../cicd/automated-building.md)
3. **Contribute improvements**: Read our [contributing guide](../operations/contributing-images.md)
4. **Set up testing**: Configure [Playwright testing](../testing/playwright-setup.md) for your projects

## Quick Reference

### Image Quick Reference

| Need | Use This Image | Quick Command |
|------|----------------|---------------|
| Rust development | `webgrip/rust-ci-runner` | `docker run -it --rm -v $(pwd):/workspace webgrip/rust-ci-runner bash` |
| E2E testing | `webgrip/playwright-runner` | `docker run --rm -v $(pwd):/app webgrip/playwright-runner npx playwright test` |
| K8s deployment | `webgrip/helm-deploy` | `docker run --rm -v $(pwd):/workspace webgrip/helm-deploy helm version` |
| Local Actions testing | `webgrip/act-runner` | `docker run --rm -v $(pwd):/workspace webgrip/act-runner act` |
| GitHub Actions runner | `webgrip/github-runner` | See [GitHub Runner docs](../docker-images/github-runner.md) |
| Release automation | `webgrip/rust-releaser` | See [Rust Releaser docs](../docker-images/rust-releaser.md) |

### Resource Links

- 📖 **[Architecture Overview](architecture.md)** - Understanding the big picture
- 🛠️ **[Operations Guide](../operations/building-locally.md)** - Building and maintaining images
- 🐛 **[Issue Tracker](https://github.com/webgrip/infrastructure/issues)** - Report problems or request features
- 💬 **[Team Contact](https://github.com/orgs/webgrip/teams/ops)** - Get help from the ops team