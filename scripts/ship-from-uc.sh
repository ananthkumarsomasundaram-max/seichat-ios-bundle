#!/usr/bin/env bash
# Builds main.jsbundle + assets from UniversalClientMobile (source of truth) and
# refreshes SeiChatSDK.swift for CocoaPods distribution.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UCM_ROOT="${SEI_UCM_ROOT:-${SDK_ROOT}/../sei_RN/sei-et-seichat-mobile/UniversalClientMobile}"
SHIP_DIR="${SDK_ROOT}/Shipped/ios"
SWIFT_DEST="${SDK_ROOT}/Sources/SeiChatSDK/SeiChatSDK.swift"
BRIDGE_LEGACY="${SDK_ROOT}/Sources/SeiChatSDK/SeiChatReactNativeBridge.swift"

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

echo "==> Sync SeiChatSDK.swift"
mkdir -p "$(dirname "${SWIFT_DEST}")"
cp "${UCM_ROOT}/ios/UniversalClientMobile/SeiChatSDK.swift" "${SWIFT_DEST}"
rm -f "${BRIDGE_LEGACY}"

echo "==> Flatten raster assets for CocoaPods (basename next to jsbundle)"
find "${SHIP_DIR}" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
  -exec cp -f {} "${SHIP_DIR}/" \;

echo "==> Done"
echo "    Bundle: ${SHIP_DIR}/main.jsbundle"
echo "    Swift:  ${SWIFT_DEST}"
ls -lh "${SHIP_DIR}/main.jsbundle"
find "${SHIP_DIR}" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' \) -print
