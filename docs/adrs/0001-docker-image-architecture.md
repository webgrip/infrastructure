# Docker Image Architecture and Organization

* Status: accepted
* Deciders: WebGrip Ops Team, Infrastructure Contributors
* Date: 2024-01-15

## Context and Problem Statement

WebGrip needs a standardized approach for organizing and building Docker images that support our development, testing, and deployment workflows. We need to decide on the architectural patterns, directory structure, and naming conventions that will scale with our organization's growth.

## Decision Drivers

* Maintainability and ease of contribution from multiple team members
* Consistent build patterns across different types of infrastructure images
* Clear separation of concerns between different tool categories
* Efficient build times and layer caching
* Security best practices and minimal attack surface
* Integration with existing CI/CD workflows

## Considered Options

* **Option 1**: Single monolithic image with all tools
* **Option 2**: Service-specific images organized by tool category
* **Option 3**: Minimal base images with extension points
* **Option 4**: Language/runtime-specific images with overlapping tools

## Decision Outcome

Chosen option: "**Option 2: Service-specific images organized by tool category**", because it provides the best balance of specificity, maintainability, and reusability while avoiding the complexity of excessive modularity.

### Positive Consequences

* Clear ownership and responsibility for each image
* Faster iteration cycles when updating specific tools
* Better caching efficiency in CI/CD pipelines
* Easier troubleshooting and debugging of specific use cases
* Natural scaling as we add new tool categories

### Negative Consequences

* Some duplication of base packages across images
* More complex dependency management across images
* Potential inconsistencies if not carefully managed
* Higher maintenance overhead for multiple images

## Pros and Cons of the Options

### Option 1: Single monolithic image

* Good, because simple to maintain and deploy
* Good, because no duplication of base packages
* Good, because single point of truth for tool versions
* Bad, because very large image size
* Bad, because slow build times and poor caching
* Bad, because difficult to update individual tools
* Bad, because increased security attack surface

### Option 2: Service-specific images organized by tool category

* Good, because clear separation of concerns
* Good, because optimized for specific use cases
* Good, because faster build times with better caching
* Good, because easier to maintain and update
* Good, because smaller attack surface per image
* Bad, because some duplication across images
* Bad, because more complex overall architecture
* Bad, because requires coordination for shared dependencies

### Option 3: Minimal base images with extension points

* Good, because maximum flexibility and composability
* Good, because minimal duplication
* Good, because very small base images
* Bad, because complex build and deployment workflows
* Bad, because difficult to ensure consistency
* Bad, because steep learning curve for contributors
* Bad, because runtime complexity for tool installation

### Option 4: Language/runtime-specific images

* Good, because natural organization by technology stack
* Good, because shared tools within language ecosystems
* Bad, because cross-cutting tools need to be duplicated
* Bad, because doesn't align with our workflow-based usage patterns
* Bad, because creates artificial boundaries between related tools

## Implementation Details

### Directory Structure

```
ops/docker/
├── rust-ci-runner/      # Rust development and CI tools
├── github-runner/       # Self-hosted GitHub Actions runner
├── helm-deploy/         # Kubernetes deployment tools
├── playwright-runner/   # End-to-end testing environment
├── act-runner/          # Local GitHub Actions testing
└── rust-releaser/       # Release automation tools
```

### Naming Convention

Images follow the pattern: `webgrip/{category}-{purpose}`

Examples:
- `webgrip/rust-ci-runner` - Rust development and CI
- `webgrip/helm-deploy` - Kubernetes deployment
- `webgrip/playwright-runner` - E2E testing

### Build Patterns

All images will follow these standard patterns:
- Multi-stage builds for optimization
- Non-root user execution
- Standardized labels and metadata
- Security scanning integration
- Automated building on changes

## Links

* Related to [ADR-0004](0004-base-image-selection.md) - Base Image Selection Strategy
* Related to [ADR-0005](0005-multi-stage-builds.md) - Multi-stage Build Pattern Adoption
* Implemented in [Docker Images Documentation](../techdocs/docs/docker-images/)