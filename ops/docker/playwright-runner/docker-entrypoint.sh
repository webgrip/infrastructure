#!/bin/bash
set -e

echo "=========================================="
echo "Pre-built Playwright Container Starting Up"
echo "Time Zone: ${TZ:-Not Set}"
echo "Node Version: $(node -v)"
echo "Playwright Version: $(npx playwright --version)"
echo "PHP version: $(php -v)"
echo "Composer version: $(composer -V)"
echo "=========================================="

# Simply hand off execution to the command provided by the workflow
exec "$@"