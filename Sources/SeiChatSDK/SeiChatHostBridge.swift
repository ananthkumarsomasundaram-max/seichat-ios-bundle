import Foundation

@objc(SeiChatHostBridge)
final class SeiChatHostBridge: NSObject {
  @objc static func requiresMainQueueSetup() -> Bool {
    true
  }

  @objc func requestClose() {
    SeiChatSDK.shared.notifyCloseRequested()
  }
}
