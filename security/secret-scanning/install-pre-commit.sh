#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="${ROOT}/security/secret-scanning/.pre-commit-config.yaml"
cd "${ROOT}"
pre-commit install --config "${CONFIG}"
echo "Installed pre-commit hooks from ${CONFIG}"
