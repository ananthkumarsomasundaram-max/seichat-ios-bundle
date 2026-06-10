#!/usr/bin/env bash
# Builds main.jsbundle + assets from UniversalClientMobile and syncs SeiChatSDK.swift.
#
# Dual-repo note: SeiChatSDK.swift source of truth is sei-et-seichat-mobile (UniversalClientMobile).
# This repo receives a copy on each ship — re-run after any Swift change in the RN repo.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UCM_ROOT="${SEI_UCM_ROOT:-${SDK_ROOT}/../../sei_RN/sei-et-seichat-mobile/UniversalClientMobile}"
SHIP_DIR="${SDK_ROOT}/Shipped/ios"
SWIFT_DEST="${SDK_ROOT}/Sources/SeiChatSDK/SeiChatSDK.swift"
# Legacy bridge removed when embed API consolidated into SeiChatSDK.swift (pre-ME-672).
BRIDGE_LEGACY="${SDK_ROOT}/Sources/SeiChatSDK/SeiChatReactNativeBridge.swift"

# Keep in sync with SeiChatSDK.podspec s.resources (offline brand rasters only).
# Paths are relative to SHIP_DIR. RN writes assets/assets/… because assets-dest is Shipped/ios
# and Metro preserves the source path assets/images/… under an assets/ folder.
REQUIRED_SHIP_ASSETS=(
  assets/assets/images/strayer-logo.png
  assets/assets/images/strayer-wordmark.png
)

if [[ ! -d "${UCM_ROOT}" ]]; then
  echo "UniversalClientMobile not found at: ${UCM_ROOT}"
  echo "Set SEI_UCM_ROOT to your UniversalClientMobile path."
  exit 1
fi

if [[ ! -d "${UCM_ROOT}/node_modules" ]]; then
  echo "Run npm install in UniversalClientMobile first."
  exit 1
fi

echo "==> Bundle JS from ${UCM_ROOT}"
rm -rf "${SHIP_DIR}"
mkdir -p "${SHIP_DIR}"

(
  cd "${UCM_ROOT}"
  npx react-native bundle \
    --platform ios \
    --dev false \
    --entry-file index.js \
    --bundle-output "${SHIP_DIR}/main.jsbundle" \
    --assets-dest "${SHIP_DIR}"
)

BUNDLE_PATH="${SHIP_DIR}/main.jsbundle"
if [[ ! -s "${BUNDLE_PATH}" ]]; then
  echo "ERROR: main.jsbundle is missing or empty — bundle step failed silently"
  exit 1
fi

echo "==> Verify allowlisted ship assets"
for rel in "${REQUIRED_SHIP_ASSETS[@]}"; do
  path="${SHIP_DIR}/${rel}"
  if [[ ! -f "${path}" ]]; then
    echo "ERROR: missing required ship asset: ${path}"
    echo "Update REQUIRED_SHIP_ASSETS in scripts/ship-from-uc.sh and SeiChatSDK.podspec when adding offline brand images."
    exit 1
  fi
done

echo "==> Sync SeiChatSDK native sources"
IOS_SRC_DIR="${UCM_ROOT}/ios/UniversalClientMobile"
SDK_SOURCES=(
  SeiChatSDK.swift
  SeiChatHostBridge.swift
  SeiChatHostBridge.m
)
mkdir -p "$(dirname "${SWIFT_DEST}")"
for rel in "${SDK_SOURCES[@]}"; do
  src="${IOS_SRC_DIR}/${rel}"
  if [[ ! -f "${src}" ]]; then
    echo "ERROR: missing ${src}"
    exit 1
  fi
  cp "${src}" "${SDK_ROOT}/Sources/SeiChatSDK/"
done
SWIFT_SRC="${IOS_SRC_DIR}/SeiChatSDK.swift"
for api_marker in "public func initialize" "public func makeViewController" "public func invalidate" "onCloseRequested"; do
  if ! grep -q "${api_marker}" "${SWIFT_SRC}"; then
    echo "ERROR: SeiChatSDK.swift missing expected API (${api_marker}) — verify UniversalClientMobile source"
    exit 1
  fi
done
rm -f "${BRIDGE_LEGACY}"

echo "==> Done"
echo "    Bundle: ${BUNDLE_PATH}"
echo "    Swift:  ${SWIFT_DEST}"
ls -lh "${BUNDLE_PATH}"
for rel in "${REQUIRED_SHIP_ASSETS[@]}"; do
  ls -lh "${SHIP_DIR}/${rel}"
done
