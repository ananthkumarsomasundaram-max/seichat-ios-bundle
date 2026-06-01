# seichat-sdk-ios-binary

Prebuilt iOS embed artifacts for native host apps (CocoaPods).

| Repo | URL |
|------|-----|
| React Native source | https://gitlab.strategiced.com/teams/emerging-technologies/sei-chat/sei-et-seichat-mobile |
| This repo | https://gitlab.strategiced.com/teams/emerging-technologies/sei-chat/seichat-sdk-ios-binary |

## Host requirements

| Requirement | Value |
|-------------|--------|
| iOS deployment target | 16.0+ (podspec) |
| Xcode | 15+ recommended |
| Swift | 5.7+ (`s.swift_version` in podspec) |
| React Native | **0.84.x** (must match host `React-Core` / embed pod ship) |

Host `Podfile` must already integrate React Native **0.84** (`React-Core`, `React-RCTAppDelegate`, `ReactAppDependencyProvider`). New Architecture flags follow the host app’s RN template — this pod does not add extra `pod_target_xcconfig` entries.

## Versioning

- **`VERSION`** — single source of truth for `SeiChatSDK.podspec` (`s.version`) and Git tag `vX.Y.Z`.
- **CI (planned):** `scripts/ship-from-uc.sh` → commit → `scripts/bump-version.sh X.Y.Z --tag` → push branch + tag.
- **Manual tag:** commit `VERSION`, then `./scripts/bump-version.sh 1.0.1 --tag` (requires clean tree).
- **Hosts** pin an explicit tag (never floating `main`):

```ruby
pod 'SeiChatSDK',
  :git => 'https://gitlab.strategiced.com/teams/emerging-technologies/sei-chat/seichat-sdk-ios-binary.git',
  :tag => 'v1.0.0'
```

## Ship a new bundle

```bash
export SEI_UCM_ROOT=/path/to/UniversalClientMobile
./scripts/ship-from-uc.sh
git add -A && git commit -m "chore(ME-672): ship iOS embed v$(cat VERSION)"
```

When adding offline brand images, update **`REQUIRED_SHIP_ASSETS`** in `scripts/ship-from-uc.sh` and **`s.resources`** in `SeiChatSDK.podspec` together.

## Host integration (smoke test)

1. Add the pod (tag or local `:path` to this repo).
2. `pod install` in the host iOS project.
3. Before presenting UI:

```swift
SeiChatSDK.shared.initialize()
let chat = SeiChatSDK.shared.makeViewController()
present(chat, animated: true)
```

4. **DEBUG:** prefer Metro (`npm start` in UniversalClientMobile). If Metro is down, the SDK falls back to the pod’s shipped `main.jsbundle`.
5. **Release:** pod includes `Shipped/ios/main.jsbundle` and allowlisted PNGs under `Shipped/ios/assets/…`.

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| “Sei Chat unavailable” label | Call `initialize()` before `makeViewController()`. Confirm RN **0.84.x** in the host app. In DEBUG, start Metro or rely on shipped `main.jsbundle` in the pod. |
| `pod install` fails on VERSION | Ensure `VERSION` exists at repo root (see `scripts/bump-version.sh`). |
| Metro not detected on device | Set packager host in the host app (e.g. Mac LAN IP). Check Xcode logs for `Metro packager host:port checked:`. |
| Pod version conflict | Host must use React Native `~> 0.84.0` to match this SDK. |

## Layout

| Path | Purpose |
|------|---------|
| `Sources/SeiChatSDK/SeiChatSDK.swift` | Copied from UniversalClientMobile on each ship |
| `Shipped/ios/main.jsbundle` | Production JS bundle |
| `Shipped/ios/assets/…` | Offline brand rasters referenced by the bundle (allowlisted) |
| `scripts/ship-from-uc.sh` | Bundle + sync Swift |
| `scripts/bump-version.sh` | Bump `VERSION`; optional `--tag` |
