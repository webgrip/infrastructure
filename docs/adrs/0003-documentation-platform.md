# Documentation Platform Selection (TechDocs)

* Status: accepted
* Deciders: WebGrip Ops Team, Development Teams
* Date: 2024-01-25

## Context and Problem Statement

WebGrip's infrastructure repository needs comprehensive documentation that is discoverable, maintainable, and integrates well with our existing tooling. We need to choose a documentation platform that serves multiple audiences (developers, ops, QA) and can scale with our infrastructure complexity.

## Decision Drivers

* Integration with existing Backstage service catalog
* Support for technical documentation with code examples
* Version control integration and change tracking
* Low maintenance overhead for contributors
* Support for diagrams and technical illustrations
* Search and navigation capabilities
* Multi-audience content organization

## Considered Options

* **Option 1**: Backstage TechDocs (MkDocs-based)
* **Option 2**: GitBook or Notion for external hosting
* **Option 3**: GitHub Wiki or GitHub Pages
* **Option 4**: Custom documentation site with static site generator

## Decision Outcome

Chosen option: "**Option 1: Backstage TechDocs (MkDocs-based)**", because it provides seamless integration with our existing Backstage infrastructure, supports technical content well, and maintains documentation as code within the repository.

### Positive Consequences

* Seamless integration with Backstage service catalog
* Documentation as code approach with version control
* MkDocs provides excellent technical documentation features
* Mermaid diagram support for architecture visualization
* Low barrier to contribution (Markdown-based)
* Automatic publishing through existing CI/CD pipelines

### Negative Consequences

* Dependency on Backstage for optimal experience
* Learning curve for Mermaid diagram syntax
* Limited customization compared to custom solutions
* MkDocs-specific configuration and plugins

## Pros and Cons of the Options

### Option 1: Backstage TechDocs (MkDocs-based)

* Good, because integrates with existing Backstage catalog
* Good, because documentation as code approach
* Good, because excellent Markdown and technical content support
* Good, because automatic publishing and search
* Good, because supports Mermaid diagrams
* Good, because low maintenance overhead
* Bad, because tied to Backstage ecosystem
* Bad, because limited styling customization
* Bad, because requires MkDocs knowledge for advanced features

### Option 2: GitBook or Notion

* Good, because excellent user interface and editing experience
* Good, because built-in collaboration features
* Good, because great for non-technical contributors
* Bad, because external dependency and potential costs
* Bad, because doesn't integrate with our existing tooling
* Bad, because limited version control integration
* Bad, because potential vendor lock-in

### Option 3: GitHub Wiki or GitHub Pages

* Good, because minimal setup and native GitHub integration
* Good, because no additional tools or dependencies
* Good, because familiar interface for GitHub users
* Bad, because limited organization and navigation features
* Bad, because poor support for technical documentation
* Bad, because no diagram support without additional tools
* Bad, because limited search capabilities

### Option 4: Custom documentation site

* Good, because maximum flexibility and customization
* Good, because can be optimized for specific needs
* Good, because full control over features and integrations
* Bad, because high development and maintenance overhead
* Bad, because requires custom CI/CD setup
* Bad, because potential complexity for contributors
* Bad, because no existing ecosystem of plugins and themes

## Implementation Details

### TechDocs Structure

```
docs/techdocs/
├── mkdocs.yml           # MkDocs configuration
└── docs/                # Documentation content
    ├── index.md         # Landing page
    ├── overview/        # High-level overview
    ├── docker-images/   # Individual image documentation
    ├── cicd/           # CI/CD pipeline documentation
    ├── testing/        # Testing infrastructure
    ├── operations/     # Operations guides
    └── adrs/           # Architectural Decision Records
```

### MkDocs Configuration

```yaml
site_name: 'WebGrip Infrastructure'
site_description: 'CI/CD Infrastructure and Docker Images for WebGrip'

plugins:
  - techdocs-core

theme:
  name: material
  features:
    - navigation.tabs
    - navigation.top
    - toc.integrate

markdown_extensions:
  - admonition
  - codehilite
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
  - toc:
      permalink: true
```

### Integration with Backstage

```yaml
# catalog-info.yml
metadata:
  annotations:
    backstage.io/techdocs-ref: dir:./docs/techdocs
```

### Content Organization Principles

1. **Service-first navigation**: Organize primarily around Docker images as services
2. **Multi-audience content**: Clear sections for developers, ops, and QA teams
3. **Link-rich documentation**: Extensive cross-referencing and citations
4. **Visual architecture**: Mermaid diagrams for complex workflows and architecture
5. **Practical examples**: Real-world usage patterns and troubleshooting

## Quality Standards

### Documentation Requirements

* Every major component has dedicated documentation
* All claims link to source code or configuration
* Assumptions are clearly marked with validation suggestions
* Troubleshooting sections with common issues and solutions
* Cross-references between related topics

### Maintenance Process

* Documentation reviews as part of PR process
* Quarterly link validation and content review
* Automated building and deployment through CI/CD
* Community feedback integration through GitHub issues

## Links

* Implements [ADR-0001](0001-docker-image-architecture.md) - Service-specific documentation structure
* Related to [Infrastructure Repository](https://github.com/webgrip/infrastructure)
* Integrates with [Backstage Service Catalog](../../../catalog-info.yml)