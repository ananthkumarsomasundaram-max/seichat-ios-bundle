#!/usr/bin/env bash
# Bumps VERSION. Podspec reads VERSION; consumers pin :tag => vX.Y.Z.
#
# Usage:
#   ./scripts/bump-version.sh 1.0.1          # writes VERSION (commit before --tag)
#   ./scripts/bump-version.sh 1.0.1 --tag    # annotated tag v1.0.1 (clean tree, VERSION committed)
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="${SDK_ROOT}/VERSION"
CREATE_TAG=0

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <semver> [--tag]" >&2
  exit 1
fi

NEW_VERSION="$1"
if [[ "${2:-}" == "--tag" ]]; then
  CREATE_TAG=1
fi

if [[ ! "${NEW_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: version must be semver (e.g. 1.0.1), got: ${NEW_VERSION}" >&2
  exit 1
fi

TAG="v${NEW_VERSION}"

if [[ "${CREATE_TAG}" -eq 1 ]]; then
  if [[ -n "$(git -C "${SDK_ROOT}" status --porcelain)" ]]; then
    echo "ERROR: working tree not clean — commit VERSION before tagging" >&2
    exit 1
  fi
  if git -C "${SDK_ROOT}" rev-parse "${TAG}" >/dev/null 2>&1; then
    echo "ERROR: tag ${TAG} already exists" >&2
    exit 1
  fi
  CURRENT_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
  if [[ "${CURRENT_VERSION}" != "${NEW_VERSION}" ]]; then
    echo "ERROR: VERSION is '${CURRENT_VERSION}' but expected '${NEW_VERSION}'" >&2
    echo "Run without --tag first, commit VERSION, then: $0 ${NEW_VERSION} --tag" >&2
    exit 1
  fi
  git -C "${SDK_ROOT}" tag -a "${TAG}" -m "SeiChatSDK ${NEW_VERSION}"
  echo "Created tag ${TAG}"
  echo "Push with: git push origin ${TAG}"
  exit 0
fi

printf '%s\n' "${NEW_VERSION}" > "${VERSION_FILE}"
echo "VERSION → ${NEW_VERSION} (pod :tag => ${TAG})"
echo "Next: git add VERSION && git commit, then: $0 ${NEW_VERSION} --tag"
