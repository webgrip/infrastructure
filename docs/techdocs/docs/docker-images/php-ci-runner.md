# PHP CI Runner

The PHP CI Runner provides a lightweight, reproducible container environment for running PHP CI tasks (Composer installs, unit tests, static analysis, etc.).

## Image Details

| Property | Value |
|----------|-------|
| **Base Image** | `ubuntu:noble` |
| **PHP Version** | 8.3 (configurable via build arg) |
| **Registry** | `webgrip/php-ci-runner` |
| **Dockerfile** | [`ops/docker/php-ci-runner/Dockerfile`](../../../ops/docker/php-ci-runner/Dockerfile) |

## Included Tooling

- **PHP CLI** + common extensions (`bcmath`, `curl`, `gd`, `intl`, `mbstring`, `mysql`, `soap`, `sockets`, `xml`, `zip`)
- **Composer** (installed to `/usr/local/bin/composer`)
- Common CI utilities: `git`, `curl`, `jq`, `patch`, `rsync`, `zip`, `unzip`

## Usage Examples

### Run Composer + PHPUnit

```bash
docker run --rm -it \
  -v $(pwd):/workspace \
  -w /workspace \
  webgrip/php-ci-runner:latest \
  bash -lc "composer install && vendor/bin/phpunit"
```

### Use in GitHub Actions (container job)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container: webgrip/php-ci-runner:latest
    steps:
      - uses: actions/checkout@v4
      - run: composer install
      - run: vendor/bin/phpunit
```

## Configuration

### Build Arguments

```dockerfile
ARG PHP_VERSION=8.3
```

Build with a different PHP version:

```bash
docker build \
  --build-arg PHP_VERSION=8.2 \
  -t webgrip/php-ci-runner:local \
  ops/docker/php-ci-runner/
```
