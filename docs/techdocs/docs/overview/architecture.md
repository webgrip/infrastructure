# Architecture Overview

## System Architecture

The WebGrip Infrastructure follows a **service-oriented architecture** where each Docker image serves as a specialized microservice for different aspects of our CI/CD pipeline.

```mermaid
flowchart TB
    subgraph "Development"
        DEV[Developer] --> LOCAL[Local Development]
        LOCAL --> ACT[ACT Runner<br/>Local Testing]
        LOCAL --> RUST_CI[Rust CI Runner<br/>Development Environment]
    end
    
    subgraph "CI/CD Pipeline"
        GH[GitHub Repository] --> ACTIONS[GitHub Actions]
        ACTIONS --> GH_RUNNER[GitHub Runner<br/>Self-hosted]
        ACTIONS --> PLAYWRIGHT[Playwright Runner<br/>E2E Testing]
        ACTIONS --> RUST_REL[Rust Releaser<br/>Release Automation]
    end
    
    subgraph "Deployment"
        ACTIONS --> HELM[Helm Deploy<br/>K8s Deployment]
        HELM --> K8S[Kubernetes Cluster]
    end
    
    subgraph "Image Registry"
        DOCKER[Docker Registry] --> GH_RUNNER
        DOCKER --> PLAYWRIGHT
        DOCKER --> HELM
        DOCKER --> RUST_CI
        DOCKER --> ACT
        DOCKER --> RUST_REL
    end
    
    GH_RUNNER --> DOCKER
    PLAYWRIGHT --> DOCKER
    RUST_REL --> DOCKER
    HELM --> DOCKER
    RUST_CI --> DOCKER
    ACT --> DOCKER
```

## Component Architecture

### Docker Image Services

Each Docker image is designed as a self-contained service with specific responsibilities:

```mermaid
flowchart LR
    subgraph "Base Images"
        ALPINE[Alpine Linux]
        RUST[Rust Official]
        NODE[Node.js]
        PLAYWRIGHT_BASE[Playwright Base]
        ACTIONS_BASE[Actions Runner Base]
    end
    
    subgraph "Our Images"
        RUST_CI[Rust CI Runner]
        GH_RUNNER[GitHub Runner]
        HELM[Helm Deploy]
        PLAYWRIGHT[Playwright Runner]
        ACT[ACT Runner]
        RUST_REL[Rust Releaser]
    end
    
    ALPINE --> HELM
    ALPINE --> ACT
    RUST --> RUST_CI
    NODE --> RUST_REL
    PLAYWRIGHT_BASE --> PLAYWRIGHT
    ACTIONS_BASE --> GH_RUNNER
```

### Automation Architecture

Our automation follows an **event-driven pattern** triggered by repository changes:

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant Actions as GitHub Actions
    participant Registry as Docker Registry
    participant K8s as Kubernetes

    Dev->>GH: Push Dockerfile changes
    GH->>Actions: Trigger workflow
    Actions->>Actions: Determine changed directories
    Actions->>Actions: Build changed images
    Actions->>Registry: Push new images
    Note over Registry: Images available for use
    
    Dev->>GH: Push application code
    GH->>Actions: Trigger deployment
    Actions->>Registry: Pull deployment image
    Actions->>K8s: Deploy using Helm
```

## Design Principles

### 🎯 **Single Responsibility**
Each Docker image has one primary purpose and contains only the tools necessary for that specific function.

**Example**: The Helm Deploy image contains only Alpine Linux + Helm + kubectl, not development tools or testing frameworks.

### 🔧 **Composability**
Images can be used independently or combined in workflows to create more complex automation pipelines.

**Example**: A typical deployment workflow uses:
1. `rust-ci-runner` for building
2. `playwright-runner` for testing  
3. `helm-deploy` for deployment

### 📦 **Immutability**
Images are versioned and immutable. Changes result in new image versions rather than modifying existing ones.

**Implementation**: Each image is tagged with both `:latest` and `:${{ github.sha }}` for different use cases.

### 🚀 **Performance**
Images are optimized for fast startup and minimal resource usage in CI/CD environments.

**Techniques**:
- Multi-stage builds to reduce final image size
- Layer caching optimization
- Minimal base images where possible

## Data Flow

### Build Pipeline Data Flow

```mermaid
flowchart TD
    SOURCE[Source Code] --> DETECT[Change Detection]
    DETECT --> BUILD[Image Build]
    BUILD --> TEST[Image Testing]
    TEST --> PUSH[Registry Push]
    PUSH --> TAG[Version Tagging]
    TAG --> NOTIFY[Availability Notification]
```

### Usage Data Flow

```mermaid
flowchart TD
    TRIGGER[Workflow Trigger] --> PULL[Pull Image]
    PULL --> RUN[Execute Container]
    RUN --> PROCESS[Process Artifacts]
    PROCESS --> OUTPUT[Generate Output]
    OUTPUT --> CLEANUP[Container Cleanup]
```

## Technology Stack

### Core Technologies

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Container Runtime** | Docker | Container orchestration and execution |
| **CI/CD Platform** | GitHub Actions | Automation workflows and triggering |
| **Image Registry** | Docker Hub | Image storage and distribution |
| **Documentation** | MkDocs + Backstage | Technical documentation platform |
| **Orchestration** | Kubernetes + Helm | Production deployment platform |

### Per-Image Technology Stack

| Image | Base | Primary Tools | Purpose |
|-------|------|---------------|---------|
| **Rust CI Runner** | `rust:slim-bookworm` | Rust toolchain, cargo-audit, cargo-tarpaulin | Rust development and CI |
| **GitHub Runner** | `actions/actions-runner` | GitHub Actions runner, Helm | Self-hosted Actions execution |
| **Helm Deploy** | `alpine:3.21.3` | Helm, kubectl, git | Kubernetes deployment |
| **Playwright Runner** | `mcr.microsoft.com/playwright` | Playwright, Node.js | End-to-end browser testing |
| **ACT Runner** | `alpine:3.22.1` | ACT, Docker, git | Local GitHub Actions testing |
| **Rust Releaser** | `node:22-bookworm-slim` | Node.js, Rust, cross-compilation tools | Release automation |

## Security Architecture

### Container Security

```mermaid
flowchart TD
    BASE[Base Image Security] --> SCAN[Vulnerability Scanning]
    SCAN --> MINIMAL[Minimal Attack Surface]
    MINIMAL --> USER[Non-root User]
    USER --> SECRETS[Secret Management]
    SECRETS --> NETWORK[Network Isolation]
```

**Security Measures**:
- Regular base image updates
- Minimal package installation
- Non-root user execution where possible
- No secrets baked into images
- Security scanning in CI pipeline

### Access Control

- **Registry Access**: Controlled via Docker Hub credentials
- **GitHub Actions**: Uses repository-level secrets and permissions
- **Kubernetes**: RBAC-controlled deployment permissions

## Scalability Considerations

### Horizontal Scaling
- Multiple runner instances can use the same images
- Registry caching reduces download times
- Parallel workflow execution supported

### Vertical Scaling  
- Images designed for various resource profiles
- Configurable resource limits in Kubernetes
- Efficient memory and CPU usage patterns

## Integration Points

### External Dependencies

```mermaid
flowchart LR
    REPO[This Repository] --> DOCKER_HUB[Docker Hub Registry]
    REPO --> GH_ACTIONS[GitHub Actions Platform]
    REPO --> WORKFLOWS[webgrip/workflows Repository]
    REPO --> K8S[Kubernetes Clusters]
    REPO --> BACKSTAGE[Backstage Platform]
```

### Internal Dependencies

- **Base Images**: Official Docker images (Alpine, Rust, Node.js, etc.)
- **Shared Workflows**: Reusable workflows from [`webgrip/workflows`](https://github.com/webgrip/workflows)
- **Configuration**: Settings from [`catalog-info.yml`](../../../catalog-info.yml)

## Operational Architecture

### Monitoring & Observability

Currently implemented:
- ✅ Build success/failure notifications via GitHub Actions
- ✅ Image vulnerability scanning
- ✅ Workflow execution logs

> **Assumption**: Detailed runtime monitoring (container metrics, resource usage) is handled by the Kubernetes platform and not part of this repository's scope. Validation needed: Confirm monitoring strategy with ops team.

### Backup & Recovery

- **Source Code**: Backed up via GitHub
- **Images**: Stored in Docker Hub with version history
- **Configuration**: Version controlled in this repository

### Disaster Recovery

In case of image unavailability:
1. Images can be rebuilt from source using local Docker
2. Alternative registries can be configured
3. Local development possible using `docker-compose.yml`

---

## Related Documentation

- [Purpose & Scope](purpose.md) - Why this architecture was chosen
- [Quick Start Guide](quick-start.md) - How to use this architecture
- [Docker Images](../docker-images/) - Detailed documentation for each component
- [Operations](../operations/) - Maintenance and operational procedures