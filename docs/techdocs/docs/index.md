# WebGrip Infrastructure

Welcome to the comprehensive documentation for WebGrip's infrastructure repository. This site provides an end-to-end map of our CI/CD infrastructure, Docker images, and automation workflows.

## What's Inside

This repository contains the foundational infrastructure components that power WebGrip's development and deployment processes:

- **6 Specialized Docker Images** for different stages of our CI/CD pipeline
- **Automated Build & Deploy Workflows** using GitHub Actions
- **Testing Infrastructure** with Playwright for end-to-end testing
- **Development Tools** for local testing and development

## Quick Navigation

### 🚀 **Getting Started**
- [Purpose & Scope](overview/purpose.md) - Understand what this repository provides
- [Architecture Overview](overview/architecture.md) - High-level system design
- [Quick Start Guide](overview/quick-start.md) - Get up and running quickly

### 🐳 **Docker Images**
Our specialized container images for different purposes:

| Image | Purpose | Documentation |
|-------|---------|---------------|
| [Rust CI Runner](docker-images/rust-ci-runner.md) | Rust development and CI environment | Complete Rust toolchain + utilities |
| [GitHub Actions Runner](docker-images/github-runner.md) | Self-hosted GitHub Actions runner | Custom runner with additional tools |
| [Helm Deploy](docker-images/helm-deploy.md) | Kubernetes deployment via Helm | Alpine-based deployment image |
| [Playwright Runner](docker-images/playwright-runner.md) | End-to-end testing environment | Browser testing infrastructure |
| [ACT Runner](docker-images/act-runner.md) | Local GitHub Actions testing | Run workflows locally with ACT |
| [Rust Releaser](docker-images/rust-releaser.md) | Release automation for Rust projects | Node.js + Rust release tooling |

### ⚙️ **Operations**
- [CI/CD Pipeline](cicd/automated-building.md) - How our automation works
- [Testing](testing/playwright-setup.md) - End-to-end test infrastructure
- [Contributing](operations/contributing-images.md) - Add new images or improve existing ones

## Repository Structure

```
infrastructure/
├── ops/docker/              # Docker image definitions
│   ├── rust-ci-runner/      # Rust development environment
│   ├── github-runner/       # GitHub Actions runner
│   ├── helm-deploy/         # Kubernetes Helm deployment
│   ├── playwright-runner/   # Browser testing environment
│   ├── act-runner/          # Local GitHub Actions testing
│   └── rust-releaser/       # Release automation
├── .github/workflows/       # CI/CD automation
├── tests/playwright-runner/ # Testing infrastructure
├── docs/techdocs/          # This documentation
└── catalog-info.yml        # Backstage service catalog
```

## Key Features

✅ **Automated Docker Image Building** - Changes to Dockerfiles trigger automatic builds and pushes  
✅ **Multi-Platform Support** - Images built for different architectures where needed  
✅ **Integrated Testing** - Playwright setup for comprehensive E2E testing  
✅ **Local Development** - ACT runner for testing GitHub Actions locally  
✅ **Backstage Integration** - Full service catalog integration  

## Getting Help

- **Issues**: Report problems or request features via [GitHub Issues](https://github.com/webgrip/infrastructure/issues)
- **Discussions**: Ask questions in [GitHub Discussions](https://github.com/webgrip/infrastructure/discussions)
- **Team**: Owned by `group:webgrip/ops` (see [catalog-info.yml](../../../catalog-info.yml))

---

> **Note**: This documentation is automatically maintained. See our [Maintenance Guide](operations/maintenance.md) for details on keeping it current.

## Recent Updates

Check the [ADRs section](adrs/index.md) for recent architectural decisions and changes to our infrastructure approach.