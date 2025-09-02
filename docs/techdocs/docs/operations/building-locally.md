# Building Locally

Guide for building and testing Docker images locally during development and maintenance.

## Overview

Local building capabilities enable:

- ✅ **Development iteration** without pushing to GitHub
- ✅ **Testing changes** before committing to version control
- ✅ **Debugging build issues** with full access to build context
- ✅ **Custom image variants** for specific use cases
- ✅ **Offline development** when internet connectivity is limited

## Prerequisites

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Docker** | Container building and runtime | [Install Docker](https://docs.docker.com/get-docker/) |
| **Docker Compose** | Multi-container orchestration | Included with Docker Desktop |
| **Git** | Source code management | [Install Git](https://git-scm.com/downloads) |
| **Make** (optional) | Build automation | `sudo apt install make` (Linux) |

### System Requirements

- **CPU**: 2+ cores recommended for parallel builds
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 20GB free space for Docker images and build cache
- **Network**: Reliable internet for base image downloads

## Repository Setup

### Clone Repository

```bash
# Clone the infrastructure repository
git clone https://github.com/webgrip/infrastructure.git
cd infrastructure

# Verify directory structure
ls -la ops/docker/
```

### Environment Setup

```bash
# Create local environment file (optional)
cat > .env.local << EOF
DOCKER_REGISTRY=localhost:5000
BUILD_ARGS="--no-cache"
PARALLEL_BUILDS=4
EOF

# Source environment
source .env.local
```

## Basic Building

### Single Image Build

```bash
# Build specific image
docker build -t webgrip/rust-ci-runner:local ops/docker/rust-ci-runner/

# Build with specific tag
docker build -t my-rust-ci:test ops/docker/rust-ci-runner/

# Build with build arguments
docker build \
  --build-arg RUST_VERSION=1.86.0 \
  -t webgrip/rust-ci-runner:1.86 \
  ops/docker/rust-ci-runner/
```

### Using Docker Compose

```bash
# Build all images defined in docker-compose.yml
docker-compose build

# Build specific service
docker-compose build rust-ci-runner

# Build with no cache
docker-compose build --no-cache

# Build in parallel
docker-compose build --parallel
```

### Build Context Verification

```bash
# Check build context size
du -sh ops/docker/rust-ci-runner/

# List files in build context
find ops/docker/rust-ci-runner/ -type f

# Verify Dockerfile syntax
docker build --dry-run ops/docker/rust-ci-runner/
```

## Advanced Building

### Multi-stage Build Optimization

```dockerfile
# Example optimization for development
FROM rust:1.87.0-slim-bookworm AS development
# Add development-specific tools
RUN apt-get update && apt-get install -y \
    gdb lldb strace valgrind

FROM rust:1.87.0-slim-bookworm AS production
# Production optimizations
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*
```

```bash
# Build specific stage
docker build --target development -t rust-ci:dev ops/docker/rust-ci-runner/
docker build --target production -t rust-ci:prod ops/docker/rust-ci-runner/
```

### Build Arguments and Customization

```bash
# Common build arguments
docker build \
  --build-arg RUST_VERSION=1.87.0 \
  --build-arg NODE_VERSION=20 \
  --build-arg DEBIAN_FRONTEND=noninteractive \
  -t webgrip/rust-ci-runner:custom \
  ops/docker/rust-ci-runner/

# Development build with debug symbols
docker build \
  --build-arg BUILD_TYPE=debug \
  --build-arg OPTIMIZATION_LEVEL=0 \
  -t webgrip/rust-ci-runner:debug \
  ops/docker/rust-ci-runner/
```

### Build Cache Management

```bash
# Build with cache from registry
docker build \
  --cache-from webgrip/rust-ci-runner:latest \
  -t webgrip/rust-ci-runner:local \
  ops/docker/rust-ci-runner/

# Use BuildKit for advanced caching
export DOCKER_BUILDKIT=1
docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t webgrip/rust-ci-runner:cached \
  ops/docker/rust-ci-runner/

# Clean build cache
docker builder prune
docker system prune -a
```

## Build Automation

### Makefile for Build Automation

```makefile
# Makefile for local building
IMAGES := rust-ci-runner github-runner helm-deploy playwright-runner act-runner rust-releaser
REGISTRY := webgrip
TAG := local

.PHONY: all build-% clean test-% push-% help

# Build all images
all: $(addprefix build-,$(IMAGES))

# Build specific image
build-%:
	@echo "Building $* image..."
	docker build -t $(REGISTRY)/$*:$(TAG) ops/docker/$*/
	@echo "✅ Built $(REGISTRY)/$*:$(TAG)"

# Test specific image
test-%: build-%
	@echo "Testing $* image..."
	docker run --rm $(REGISTRY)/$*:$(TAG) --version || echo "✅ $* image works"

# Push to local registry
push-%: build-%
	docker push $(REGISTRY)/$*:$(TAG)

# Clean up local images
clean:
	docker images | grep "$(REGISTRY)" | grep "$(TAG)" | awk '{print $$3}' | xargs -r docker rmi

# Build with custom tag
tag:
	$(eval TAG := $(shell git rev-parse --short HEAD))
	@echo "Building with tag: $(TAG)"

# Help target
help:
	@echo "Available targets:"
	@echo "  all              - Build all images"
	@echo "  build-<image>    - Build specific image"
	@echo "  test-<image>     - Test specific image"
	@echo "  push-<image>     - Push to registry"
	@echo "  clean            - Clean up local images"
	@echo "  tag              - Build with git SHA tag"
	@echo ""
	@echo "Available images: $(IMAGES)"
	@echo ""
	@echo "Examples:"
	@echo "  make build-rust-ci-runner"
	@echo "  make test-playwright-runner"
	@echo "  make TAG=dev build-helm-deploy"

# Usage examples
build-dev: TAG=dev
build-dev: all

build-test: TAG=test
build-test: all
```

Usage:
```bash
# Build all images
make all

# Build specific image
make build-rust-ci-runner

# Build and test
make test-playwright-runner

# Build with custom tag
make TAG=dev build-helm-deploy

# Clean up
make clean
```

### Build Script Automation

```bash
#!/bin/bash
# scripts/build-local.sh - Automated local building

set -euo pipefail

# Configuration
REGISTRY="${DOCKER_REGISTRY:-webgrip}"
TAG="${BUILD_TAG:-local}"
PARALLEL="${PARALLEL_BUILDS:-2}"
BUILD_ARGS="${BUILD_ARGS:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Image definitions
declare -A IMAGES=(
    ["rust-ci-runner"]="ops/docker/rust-ci-runner"
    ["github-runner"]="ops/docker/github-runner"
    ["helm-deploy"]="ops/docker/helm-deploy"
    ["playwright-runner"]="ops/docker/playwright-runner"
    ["act-runner"]="ops/docker/act-runner"
    ["rust-releaser"]="ops/docker/rust-releaser"
)

# Build single image
build_image() {
    local name=$1
    local path=$2
    local full_tag="${REGISTRY}/${name}:${TAG}"
    
    log_info "Building $name -> $full_tag"
    
    if docker build $BUILD_ARGS -t "$full_tag" "$path"; then
        log_info "✅ Successfully built $full_tag"
        return 0
    else
        log_error "❌ Failed to build $full_tag"
        return 1
    fi
}

# Test image
test_image() {
    local name=$1
    local full_tag="${REGISTRY}/${name}:${TAG}"
    
    log_info "Testing $full_tag"
    
    case $name in
        "rust-ci-runner")
            docker run --rm "$full_tag" rustc --version >/dev/null
            ;;
        "github-runner")
            docker run --rm "$full_tag" php --version >/dev/null
            ;;
        "helm-deploy")
            docker run --rm "$full_tag" helm version >/dev/null
            ;;
        "playwright-runner")
            docker run --rm "$full_tag" npx playwright --version >/dev/null
            ;;
        "act-runner")
            docker run --rm "$full_tag" act --version >/dev/null
            ;;
        "rust-releaser")
            docker run --rm "$full_tag" node --version >/dev/null
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_info "✅ $full_tag passed basic test"
        return 0
    else
        log_error "❌ $full_tag failed basic test"
        return 1
    fi
}

# Main function
main() {
    local target_images=()
    local test_after_build=false
    local clean_before_build=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test)
                test_after_build=true
                shift
                ;;
            --clean)
                clean_before_build=true
                shift
                ;;
            --parallel)
                PARALLEL="$2"
                shift 2
                ;;
            --tag)
                TAG="$2"
                shift 2
                ;;
            --all)
                target_images=(${!IMAGES[@]})
                shift
                ;;
            *)
                if [[ -n "${IMAGES[$1]:-}" ]]; then
                    target_images+=("$1")
                else
                    log_error "Unknown image: $1"
                    log_info "Available images: ${!IMAGES[*]}"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to all images if none specified
    if [[ ${#target_images[@]} -eq 0 ]]; then
        target_images=(${!IMAGES[@]})
    fi
    
    log_info "Building images: ${target_images[*]}"
    log_info "Registry: $REGISTRY"
    log_info "Tag: $TAG"
    
    # Clean if requested
    if [[ "$clean_before_build" == "true" ]]; then
        log_info "Cleaning Docker cache..."
        docker system prune -f
    fi
    
    # Build images
    local failed_builds=()
    for image in "${target_images[@]}"; do
        if ! build_image "$image" "${IMAGES[$image]}"; then
            failed_builds+=("$image")
        fi
        
        # Test if requested
        if [[ "$test_after_build" == "true" ]]; then
            test_image "$image" || failed_builds+=("$image-test")
        fi
    done
    
    # Report results
    if [[ ${#failed_builds[@]} -eq 0 ]]; then
        log_info "🎉 All builds completed successfully!"
    else
        log_error "❌ Failed builds: ${failed_builds[*]}"
        exit 1
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [IMAGES...]

Build Docker images locally.

OPTIONS:
    --test              Test images after building
    --clean             Clean Docker cache before building
    --parallel N        Number of parallel builds (default: $PARALLEL)
    --tag TAG           Tag for built images (default: $TAG)
    --all               Build all images

IMAGES:
    ${!IMAGES[*]}

EXAMPLES:
    $0 --all --test                     # Build and test all images
    $0 rust-ci-runner playwright-runner # Build specific images
    $0 --tag dev --clean helm-deploy    # Build with custom tag and clean cache
    
ENVIRONMENT VARIABLES:
    DOCKER_REGISTRY     Docker registry (default: webgrip)
    BUILD_TAG           Default tag (default: local)
    PARALLEL_BUILDS     Parallel builds (default: 2)
    BUILD_ARGS          Additional docker build args
EOF
}

# Handle help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"
```

Usage:
```bash
# Make script executable
chmod +x scripts/build-local.sh

# Build all images
./scripts/build-local.sh --all

# Build and test specific images
./scripts/build-local.sh --test rust-ci-runner playwright-runner

# Build with custom tag and clean cache
./scripts/build-local.sh --tag dev --clean helm-deploy

# Build all with custom configuration
BUILD_TAG=dev PARALLEL_BUILDS=4 ./scripts/build-local.sh --all --test
```

## Testing Built Images

### Basic Functionality Testing

```bash
# Test Rust CI Runner
docker run --rm webgrip/rust-ci-runner:local rustc --version
docker run --rm webgrip/rust-ci-runner:local cargo --version
docker run --rm webgrip/rust-ci-runner:local cargo audit --version

# Test Playwright Runner
docker run --rm webgrip/playwright-runner:local npx playwright --version
docker run --rm webgrip/playwright-runner:local php --version

# Test Helm Deploy
docker run --rm webgrip/helm-deploy:local helm version
docker run --rm webgrip/helm-deploy:local kubectl version --client

# Test ACT Runner
docker run --rm webgrip/act-runner:local act --version

# Test GitHub Runner (requires setup)
docker run --rm webgrip/github-runner:local php --version
docker run --rm webgrip/github-runner:local composer --version

# Test Rust Releaser
docker run --rm webgrip/rust-releaser:local node --version
docker run --rm webgrip/rust-releaser:local npx semantic-release --version
```

### Integration Testing

```bash
# Test volume mounting
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  webgrip/rust-ci-runner:local \
  bash -c "ls -la && rustc --version"

# Test network connectivity
docker run --rm webgrip/rust-ci-runner:local \
  bash -c "curl -s https://crates.io | head -5"

# Test build functionality
mkdir -p /tmp/test-rust-project
cd /tmp/test-rust-project
cargo init --name test-app

docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  webgrip/rust-ci-runner:local \
  bash -c "cargo build && cargo test"
```

### Performance Testing

```bash
# Measure build time
time docker build -t test-build ops/docker/rust-ci-runner/

# Measure image size
docker images | grep rust-ci-runner

# Test container startup time
time docker run --rm webgrip/rust-ci-runner:local echo "Hello World"

# Memory usage test
docker run --rm \
  --memory=1g \
  webgrip/rust-ci-runner:local \
  bash -c "echo 'Memory test passed'"
```

## Troubleshooting

### Build Failures

**Out of disk space**
```bash
# Check disk usage
df -h
docker system df

# Clean up
docker system prune -a --volumes
docker builder prune --all
```

**Network timeouts**
```bash
# Use build args for proxy
docker build \
  --build-arg HTTP_PROXY=http://proxy:8080 \
  --build-arg HTTPS_PROXY=http://proxy:8080 \
  -t webgrip/rust-ci-runner:local \
  ops/docker/rust-ci-runner/
```

**Permission errors**
```bash
# Check Docker daemon access
docker info

# Fix permissions (Linux)
sudo usermod -aG docker $USER
newgrp docker
```

**Base image pull failures**
```bash
# Pre-pull base images
docker pull rust:1.87.0-slim-bookworm
docker pull alpine:3.22.1
docker pull mcr.microsoft.com/playwright:v1.51.0-noble

# Use local registry mirror
docker build --pull=false -t local-build ops/docker/rust-ci-runner/
```

### Runtime Issues

**Container won't start**
```bash
# Debug container
docker run -it --entrypoint=/bin/bash webgrip/rust-ci-runner:local

# Check logs
docker logs <container-id>

# Inspect image
docker inspect webgrip/rust-ci-runner:local
```

**Tool not found**
```bash
# Verify PATH
docker run --rm webgrip/rust-ci-runner:local echo $PATH

# Check installed tools
docker run --rm webgrip/rust-ci-runner:local which cargo rustc

# Debug package installation
docker run --rm webgrip/rust-ci-runner:local dpkg -l | grep rust
```

### Build Performance Issues

**Slow builds**
```bash
# Use BuildKit
export DOCKER_BUILDKIT=1

# Parallel builds
docker-compose build --parallel

# Use build cache
docker build --cache-from webgrip/rust-ci-runner:latest
```

**Layer cache misses**
```bash
# Optimize Dockerfile layer order
# Place frequently changing content at the end

# Use .dockerignore
echo "target/" >> ops/docker/rust-ci-runner/.dockerignore
echo "*.log" >> ops/docker/rust-ci-runner/.dockerignore
```

## Best Practices

### Development Workflow

1. **Small, incremental changes**: Test each change incrementally
2. **Use development tags**: Tag images with descriptive names (`dev`, `test`, `feature-x`)
3. **Clean up regularly**: Remove unused images and containers
4. **Use build cache**: Leverage Docker's layer caching for faster builds

### Security Considerations

```bash
# Scan images for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image webgrip/rust-ci-runner:local

# Check for secrets in images
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive webgrip/rust-ci-runner:local
```

### Resource Management

```bash
# Monitor resource usage
docker stats

# Set resource limits
docker run --memory=2g --cpus=1 webgrip/rust-ci-runner:local

# Use multi-stage builds to reduce image size
# Optimize package installation order
```

## Integration with Development Tools

### VS Code Integration

```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build Rust CI Runner",
      "type": "shell",
      "command": "docker",
      "args": [
        "build",
        "-t", "webgrip/rust-ci-runner:dev",
        "ops/docker/rust-ci-runner/"
      ],
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Test Built Image",
      "type": "shell",
      "command": "docker",
      "args": [
        "run", "--rm",
        "webgrip/rust-ci-runner:dev",
        "rustc", "--version"
      ],
      "dependsOn": "Build Rust CI Runner",
      "group": "test"
    }
  ]
}
```

### IDE Docker Plugin

Most IDEs support Docker plugins for:
- Building images directly from IDE
- Running containers with debugging
- Viewing container logs
- Managing Docker resources

## Related Documentation

- [Contributing Images](contributing-images.md) - How to contribute new images
- [Maintenance](maintenance.md) - Ongoing maintenance procedures
- [Docker Images](../docker-images/) - Individual image documentation
- [CI/CD Pipeline](../cicd/automated-building.md) - Automated building process

---

> **Assumption**: Developers have local Docker installations and sufficient system resources for building container images. Network connectivity requirements may vary based on base image sizes and dependencies. Validation needed: Confirm local development environment standards and resource requirements.

**Maintainer**: [WebGrip Ops Team](https://github.com/orgs/webgrip/teams/ops)  
**Scripts**: Available in repository `scripts/` directory  
**Support**: [GitHub Issues](https://github.com/webgrip/infrastructure/issues)