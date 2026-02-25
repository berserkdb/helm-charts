#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Read current version from the parent chart
CURRENT_VERSION=$(grep '^version:' "$REPO_ROOT/charts/berserk/Chart.yaml" | awk '{print $2}')

# Bump patch version by 1
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
NEXT_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"

if [ $# -eq 1 ]; then
  VERSION="$1"
else
  echo "Current version: ${CURRENT_VERSION}"
  read -rp "New version [${NEXT_VERSION}]: " VERSION
  VERSION="${VERSION:-$NEXT_VERSION}"
fi

find "$REPO_ROOT/charts" -name Chart.yaml -exec sed -i "s/^version: .*/version: ${VERSION}/" {} +

echo "Updated all Chart.yaml files to version ${VERSION}"
