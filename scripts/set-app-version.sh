#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Read current appVersion from the parent chart
CURRENT_VERSION=$(grep '^appVersion:' "$REPO_ROOT/charts/berserk/Chart.yaml" | awk '{print $2}')

# Bump patch version by 1
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
NEXT_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"

if [ $# -eq 1 ]; then
  VERSION="$1"
else
  echo "Current appVersion: ${CURRENT_VERSION}"
  read -rp "New appVersion [${NEXT_VERSION}]: " VERSION
  VERSION="${VERSION:-$NEXT_VERSION}"
fi

# Update appVersion in parent chart and all subcharts (skip berserk-common library chart)
find "$REPO_ROOT/charts" -name Chart.yaml -not -path "*/berserk-common/*" -exec sed -i "s/^appVersion: .*/appVersion: ${VERSION}/" {} +

echo "Updated appVersion in all Chart.yaml files to ${VERSION}"
