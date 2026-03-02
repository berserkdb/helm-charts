#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Read current appVersion from the parent chart
CURRENT_VERSION=$(grep '^appVersion:' "$REPO_ROOT/charts/berserk/Chart.yaml" | awk '{print $2}')

# Fetch latest release from GitHub (private repo — needs auth)
RELEASE_JSON=""
if command -v gh &>/dev/null; then
  RELEASE_JSON=$(gh api repos/berserkdb/rustytrace/releases/latest 2>/dev/null || true)
fi
if [ -z "$RELEASE_JSON" ] && command -v curl &>/dev/null && [ -n "${GITHUB_TOKEN:-}" ]; then
  RELEASE_JSON=$(curl -sf -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/berserkdb/rustytrace/releases/latest 2>/dev/null || true)
fi

LATEST_RELEASE=""
LATEST_RELEASE_AGE=""
if [ -n "$RELEASE_JSON" ]; then
  LATEST_RELEASE=$(echo "$RELEASE_JSON" | jq -r '.tag_name' | sed 's/^v//')
  PUBLISHED_AT=$(echo "$RELEASE_JSON" | jq -r '.published_at')
  RELEASE_EPOCH=$(date -d "$PUBLISHED_AT" +%s 2>/dev/null)
  NOW_EPOCH=$(date +%s)
  AGE_SECONDS=$((NOW_EPOCH - RELEASE_EPOCH))
  AGE_DAYS=$((AGE_SECONDS / 86400))
  if [ "$AGE_DAYS" -eq 0 ]; then
    AGE_HOURS=$((AGE_SECONDS / 3600))
    LATEST_RELEASE_AGE="${AGE_HOURS} hours ago"
  elif [ "$AGE_DAYS" -eq 1 ]; then
    LATEST_RELEASE_AGE="1 day ago"
  else
    LATEST_RELEASE_AGE="${AGE_DAYS} days ago"
  fi
fi

# Determine default: prefer latest GitHub release, fall back to patch bump
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
NEXT_PATCH="${MAJOR}.${MINOR}.$((PATCH + 1))"

if [ -n "$LATEST_RELEASE" ] && [ "$LATEST_RELEASE" != "$CURRENT_VERSION" ]; then
  DEFAULT_VERSION="$LATEST_RELEASE"
else
  DEFAULT_VERSION="$NEXT_PATCH"
fi

if [ $# -eq 1 ]; then
  VERSION="$1"
else
  echo "Current appVersion: ${CURRENT_VERSION}"
  if [ -n "$LATEST_RELEASE" ]; then
    echo "Latest GitHub release: ${LATEST_RELEASE} (released ${LATEST_RELEASE_AGE})"
  else
    echo "Could not fetch latest GitHub release (need 'gh auth login' or GITHUB_TOKEN set)"
  fi
  read -rp "New appVersion [${DEFAULT_VERSION}]: " VERSION
  VERSION="${VERSION:-$DEFAULT_VERSION}"
fi

# Update appVersion in parent chart and all subcharts (skip berserk-common library chart)
find "$REPO_ROOT/charts" -name Chart.yaml -not -path "*/berserk-common/*" -exec sed -i "s/^appVersion: .*/appVersion: ${VERSION}/" {} +

echo "Updated appVersion in all Chart.yaml files to ${VERSION}"
