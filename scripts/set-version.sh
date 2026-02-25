#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 1.0.7"
  exit 1
fi

VERSION="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

find "$REPO_ROOT/charts" -name Chart.yaml -exec sed -i "s/^version: .*/version: ${VERSION}/" {} +

echo "Updated all Chart.yaml files to version ${VERSION}"
