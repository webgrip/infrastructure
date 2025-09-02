# Rust CI Runner

The Rust CI Runner provides a complete, optimized environment for Rust development, testing, and continuous integration workflows.

## Purpose

This image serves as the primary development and CI environment for Rust projects at WebGrip, providing:

- ✅ **Complete Rust toolchain** with stable and nightly versions
- ✅ **Essential Rust CLI tools** for quality assurance and testing
- ✅ **Optimized build environment** with caching and minimal overhead
- ✅ **Security-focused tooling** for dependency auditing

## Image Details

| Property | Value |
|----------|-------|
| **Base Image** | `rust:1.87.0-slim-bookworm` → `debian:bookworm-slim` |
| **Architecture** | Multi-platform (AMD64, ARM64) |
| **Size** | ~800MB (optimized via multi-stage build) |
| **Registry** | `webgrip/rust-ci-runner` |
| **Dockerfile** | [`ops/docker/rust-ci-runner/Dockerfile`](../../../ops/docker/rust-ci-runner/Dockerfile) |

## Installed Tools

### Core Rust Toolchain

- **Rust Stable**: Version 1.87.0 (configurable via build arg)
- **Rust Nightly**: Latest nightly toolchain
- **Cargo**: Package manager and build tool
- **Rustfmt**: Code formatting tool
- **Clippy**: Linting and static analysis

### Quality Assurance Tools

| Tool | Purpose | Installation Method |
|------|---------|-------------------|
| [`cargo-audit`](https://github.com/RustSec/rustsec/tree/main/cargo-audit) | Security vulnerability scanning | cargo-binstall |
| [`cargo-deny`](https://github.com/EmbarkStudios/cargo-deny) | Dependency validation and licensing | cargo-binstall |
| [`cargo-outdated`](https://github.com/kbknapp/cargo-outdated) | Dependency update checking | cargo-binstall |
| [`cargo-udeps`](https://github.com/est31/cargo-udeps) | Unused dependency detection | cargo-binstall |
| [`cargo-msrv`](https://github.com/foresterre/cargo-msrv) | Minimum Supported Rust Version checking | cargo-binstall |
| [`cargo-nextest`](https://nexte.st/) | Next-generation test runner | cargo-binstall |
| [`cargo-tarpaulin`](https://github.com/xd009642/tarpaulin) | Code coverage analysis | cargo-binstall |
| [`cargo-sort`](https://github.com/DevinR528/cargo-sort) | Cargo.toml dependency sorting | Source build |

### System Dependencies

- **Build tools**: `gcc`, `make`, `pkg-config`
- **SSL/TLS**: `libssl-dev`, `libssl3`
- **Networking**: `ca-certificates`, `curl`

## Architecture

### Multi-Stage Build Process

```mermaid
flowchart TD
    subgraph "Build Stage"
        BUILD[rust:1.87.0-slim-bookworm]
        BUILD --> INSTALL[Install cargo-binstall]
        INSTALL --> TOOLS[Install Rust CLI tools]
        TOOLS --> SORT[Build cargo-sort from source]
        SORT --> NIGHTLY[Install nightly toolchain]
        NIGHTLY --> COMPONENTS[Add rustfmt + clippy]
    end
    
    subgraph "Runtime Stage"
        RUNTIME[debian:bookworm-slim]
        RUNTIME --> DEPS[Install runtime dependencies]
        DEPS --> COPY[Copy toolchains from build stage]
        COPY --> ENV[Set environment variables]
    end
    
    BUILD -.->|Multi-stage copy| RUNTIME
```

**Benefits of this approach**:
- **Smaller final image**: Build dependencies not included in runtime
- **Layer caching**: Rust tools cached independently of project code
- **Security**: Minimal attack surface with only runtime dependencies

## Usage Examples

### Basic Development

```bash
# Start interactive development environment
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  webgrip/rust-ci-runner:latest \
  bash

# Inside container - full Rust development workflow
cargo new my-project
cd my-project
cargo build
cargo test
cargo clippy
cargo fmt --check
```

### CI/CD Integration

```yaml
# .github/workflows/rust-ci.yml
name: Rust CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    container: webgrip/rust-ci-runner:latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run tests
        run: |
          cargo test --all-features
          cargo nextest run --all-features
          
      - name: Check code quality
        run: |
          cargo clippy -- -D warnings
          cargo fmt --check
          cargo audit
          cargo deny check
          
      - name: Generate coverage
        run: cargo tarpaulin --out xml
```

### Quality Assurance Workflow

```bash
# Complete quality check pipeline
docker run --rm -v $(pwd):/workspace -w /workspace \
  webgrip/rust-ci-runner:latest \
  bash -c "
    echo '🔍 Checking code format...'
    cargo fmt --check
    
    echo '📎 Running clippy...'  
    cargo clippy -- -D warnings
    
    echo '🔒 Auditing dependencies...'
    cargo audit
    
    echo '📦 Checking for unused deps...'
    cargo +nightly udeps
    
    echo '📊 Generating coverage...'
    cargo tarpaulin --out html
  "
```

## Configuration

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CARGO_HOME` | `/usr/local/cargo` | Cargo installation directory |
| `RUSTUP_HOME` | `/usr/local/rustup` | Rustup installation directory |
| `PATH` | Includes cargo bin | Tool discovery |

### Build Arguments

```dockerfile
# Customize Rust version during build
ARG RUST_VERSION=1.87.0
```

Build with custom Rust version:
```bash
docker build --build-arg RUST_VERSION=1.86.0 \
  -t my-rust-ci ops/docker/rust-ci-runner/
```

## Best Practices

### Performance Optimization

1. **Use cargo workspaces** for monorepos:
   ```bash
   # Mount workspace root
   docker run -v $(pwd):/workspace -w /workspace \
     webgrip/rust-ci-runner cargo build --workspace
   ```

2. **Cache dependencies** between runs:
   ```bash
   # Create named volume for cargo cache
   docker volume create cargo-cache
   docker run -v cargo-cache:/usr/local/cargo/registry \
     -v $(pwd):/workspace -w /workspace \
     webgrip/rust-ci-runner cargo build
   ```

3. **Parallel testing** with nextest:
   ```bash
   docker run --rm -v $(pwd):/workspace -w /workspace \
     webgrip/rust-ci-runner \
     cargo nextest run --jobs $(nproc)
   ```

### Security Considerations

1. **Regular dependency audits**:
   ```bash
   # Include in CI pipeline
   cargo audit --deny warnings
   cargo deny check
   ```

2. **MSRV compliance**:
   ```bash
   # Verify minimum supported Rust version
   cargo msrv
   ```

3. **Dependency management**:
   ```bash
   # Check for outdated dependencies
   cargo outdated
   # Remove unused dependencies  
   cargo +nightly udeps
   ```

## Troubleshooting

### Common Issues

**Build failures due to missing system dependencies**
```bash
# Check if additional system packages needed
apt list --installed | grep -E 'ssl|pkg-config|build'
```

**Permission errors with mounted volumes**
```bash
# Fix ownership after container operations
docker run --rm -v $(pwd):/workspace -w /workspace \
  webgrip/rust-ci-runner:latest \
  chown -R $(id -u):$(id -g) target/
```

**Tool not found errors**
```bash
# Verify tools are in PATH
docker run --rm webgrip/rust-ci-runner:latest which cargo-audit
docker run --rm webgrip/rust-ci-runner:latest cargo --list
```

### Performance Issues

**Slow builds**
- Use cargo cache volumes
- Enable incremental compilation: `CARGO_INCREMENTAL=1`
- Use faster linker: Install `lld` in derived images

**Large image size**
- Image is already optimized via multi-stage build
- For smaller images, consider cargo-chef pattern for layer caching

## Customization

### Extending the Image

```dockerfile
# Dockerfile.custom
FROM webgrip/rust-ci-runner:latest

# Add project-specific tools
RUN cargo binstall --no-confirm cargo-watch cargo-expand

# Add system dependencies
USER root
RUN apt-get update && apt-get install -y postgresql-client
USER rust

# Set project-specific environment
ENV DATABASE_URL=postgresql://test:test@localhost/test
```

### Adding Custom Tools

```bash
# Run container and install additional tools
docker run -it --name rust-dev webgrip/rust-ci-runner:latest bash

# Inside container
cargo install cargo-watch
cargo binstall --no-confirm cargo-expand

# Commit changes to new image
docker commit rust-dev my-custom-rust-ci
docker rm rust-dev
```

## Related Documentation

- [Architecture Overview](../overview/architecture.md) - How this fits into our infrastructure
- [CI/CD Pipeline](../cicd/automated-building.md) - Automated building of this image
- [Contributing Images](../operations/contributing-images.md) - How to improve this image
- [Quick Start Guide](../overview/quick-start.md) - Get started quickly

## Maintenance

### Update Schedule

- **Rust versions**: Updated monthly following Rust release schedule
- **CLI tools**: Updated quarterly or when security issues discovered
- **Base image**: Updated when new Debian security releases available

### Version Policy

- `latest`: Latest stable Rust version
- `<rust-version>`: Specific Rust version (e.g., `1.87.0`)
- `<git-sha>`: Specific build commit for reproducibility

> **Assumption**: Teams primarily use stable Rust toolchain. Nightly toolchain available but not default. Validation needed: Confirm if any projects require nightly-specific features.

---

**Maintainer**: [WebGrip Ops Team](https://github.com/orgs/webgrip/teams/ops)  
**Source**: [`ops/docker/rust-ci-runner/Dockerfile`](../../../ops/docker/rust-ci-runner/Dockerfile)  
**Registry**: [webgrip/rust-ci-runner](https://hub.docker.com/r/webgrip/rust-ci-runner)