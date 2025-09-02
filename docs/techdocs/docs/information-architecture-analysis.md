# Information Architecture Analysis for webgrip/infrastructure

## Repository Analysis Summary

The `webgrip/infrastructure` repository serves as a centralized CI/CD infrastructure provider, containing Docker images and automation tooling that supports WebGrip's development and deployment workflows.

**Key Components Identified**:
- 6 specialized Docker images in [`ops/docker/`](../../ops/docker/)
- GitHub Actions automation in [`.github/workflows/`](../../.github/workflows/)
- Playwright testing infrastructure in [`tests/playwright-runner/`](../../tests/playwright-runner/)
- Backstage catalog integration via [`catalog-info.yml`](../../catalog-info.yml)

## Proposed Information Architecture Alternatives

### Alternative 1: Service-First Organization (RECOMMENDED)

**Rationale**: Each Docker image serves as a distinct "service" with specific responsibilities in the CI/CD ecosystem. This mirrors how the repository is already organized and aligns with how users will interact with individual images.

```
1. Overview
   - Purpose and scope
   - Quick start guide
   - Architecture overview
2. Docker Images (Services)
   - Rust CI Runner
   - GitHub Actions Runner  
   - Helm Deploy
   - Playwright Runner
   - ACT Runner
   - Rust Releaser
3. CI/CD Pipeline
   - Automated building
   - Docker registry integration
   - Workflow details
4. Testing
   - Playwright setup
   - Test execution
5. Operations
   - Building locally
   - Contributing new images
   - Maintenance procedures
6. ADRs
```

**Mapping to Code**:
- Overview → Root README, catalog-info.yml
- Docker Images → Individual directories in `ops/docker/`
- CI/CD → `.github/workflows/on_dockerfile_change.yml`
- Testing → `tests/playwright-runner/`
- Operations → Dockerfile patterns, docker-compose.yml

### Alternative 2: Layer-First Organization

**Rationale**: Organizes by infrastructure layers (runtime, build, deploy, test).

```
1. Overview
2. Runtime Environment
   - Base images and platforms
   - Container orchestration
3. Build Layer
   - Rust toolchains (rust-ci-runner, rust-releaser)
   - Build automation
4. Deployment Layer
   - Helm deployment (helm-deploy)
   - Runner infrastructure (github-runner, act-runner)
5. Testing Layer
   - Playwright testing (playwright-runner)
6. Automation
   - CI/CD workflows
7. Operations & Maintenance
8. ADRs
```

### Alternative 3: Workflow-First Organization

**Rationale**: Organizes around development workflows and use cases.

```
1. Overview
2. Development Workflows
   - Rust development (rust-ci-runner)
   - Local testing with ACT (act-runner)
   - E2E testing (playwright-runner)
3. Deployment Workflows
   - Kubernetes deployment (helm-deploy)
   - Release processes (rust-releaser)
4. Infrastructure Workflows
   - Self-hosted runners (github-runner)
   - Automated image building
5. Testing & Quality
6. Operations
7. ADRs
```

## Recommendation: Alternative 1 (Service-First)

**Why this works best for this repository**:

1. **Matches existing structure**: The repository is already organized by service (Docker image)
2. **User-centric**: Developers typically need specific images for specific purposes
3. **Clear ownership**: Each image has distinct responsibilities and can be documented independently
4. **Scalable**: Easy to add new images as new services
5. **Maintenance-friendly**: Changes to one image don't affect documentation of others

**Trade-offs**:
- Some cross-cutting concerns (security, monitoring) need to be addressed in multiple places
- Workflow documentation is distributed across services rather than centralized

**Implementation depth**: ≤ 3 levels
- Level 1: Main sections (Overview, Docker Images, etc.)
- Level 2: Individual services or subsections
- Level 3: Specific topics within services (Usage, Configuration, Troubleshooting)

## Next Steps

1. Implement the Service-First IA in `mkdocs.yml` navigation
2. Create placeholder pages for each section
3. Populate content section by section, starting with Overview
4. Add cross-links and Mermaid diagrams where helpful
5. Integrate ADRs and establish maintenance procedures