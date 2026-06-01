import Foundation
import os.log
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import UIKit

/// Host apps must call public API on the main thread (`@MainActor`).
@MainActor
public final class SeiChatSDK: NSObject {
  public static let shared = SeiChatSDK()

  private static let log = Logger(subsystem: "SeiChatSDK", category: "embed")

  /// Verified when shipping the binary repo; checked at runtime via React-Core bundle version.
  private static let supportedReactNativeVersionPrefix = "0.84."

  private var customBundleURL: URL?
  /// Must match AppRegistry.registerComponent('SeiChatEmbedded', …) in index.js.
  private let embeddedModuleName = "SeiChatEmbedded"
  private var delegate: SeiChatReactNativeDelegate?
  private var reactNativeFactory: RCTReactNativeFactory?
  private var reactNativeVersionCompatible = true

  private static func fallbackViewController(reason: String) -> UIViewController {
    sdkLog("makeViewController() fallback — \(reason)")
    let fallback = UIViewController()
    fallback.view.backgroundColor = .systemBackground

    let label = UILabel()
    label.text = "Sei Chat unavailable\n\(reason)"
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = .secondaryLabel
    label.font = .preferredFont(forTextStyle: .footnote)
    label.translatesAutoresizingMaskIntoConstraints = false
    fallback.view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: fallback.view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: fallback.view.centerYAnchor),
      label.leadingAnchor.constraint(
        greaterThanOrEqualTo: fallback.view.layoutMarginsGuide.leadingAnchor
      ),
      label.trailingAnchor.constraint(
        lessThanOrEqualTo: fallback.view.layoutMarginsGuide.trailingAnchor
      ),
    ])
    return fallback
  }

  fileprivate static func sdkLog(_ message: String) {
    log.info("\(message, privacy: .public)")
#if DEBUG
    print("[SeiChatSDK] \(message)")
#endif
  }

  fileprivate static func logBundleURL(_ url: URL?, source: String) {
    sdkLog("bundleURL() → \(source): \(url?.absoluteString ?? "nil")")
  }

  private override init() {
    super.init()
    Self.sdkLog("shared singleton init")
  }

  /// Initializes RN factory once for host app embedding.
  public func initialize(customBundleURL: URL? = nil) {
    Self.sdkLog("initialize() — customBundleURL: \(customBundleURL?.absoluteString ?? "nil")")

    guard checkReactNativeVersionCompatible() else {
      return
    }

    let bundleURLChanged = self.customBundleURL != customBundleURL

    if reactNativeFactory != nil {
      if bundleURLChanged {
        invalidate()
      } else {
        return
      }
    }

    self.customBundleURL = customBundleURL

    let sdkDelegate = SeiChatReactNativeDelegate(customBundleURL: customBundleURL)
    sdkDelegate.dependencyProvider = RCTAppDependencyProvider()

    delegate = sdkDelegate
    reactNativeFactory = RCTReactNativeFactory(delegate: sdkDelegate)
  }

  /// Creates a UIViewController that renders SeiChatEmbedded. Requires `initialize()` first.
  public func makeViewController(initialProps: [String: Any] = [:]) -> UIViewController {
    Self.sdkLog("makeViewController() — props keys: \(initialProps.keys.sorted().joined(separator: ","))")

    if !reactNativeVersionCompatible {
      let version = Self.reactNativeVersionString() ?? "unknown"
      let reason =
        "React Native \(version) is not supported. SeiChatSDK requires RN \(Self.supportedReactNativeVersionPrefix)x."
      Self.sdkLog("ERROR: makeViewController() blocked — \(reason)")
      return Self.fallbackViewController(reason: reason)
    }

    guard let reactNativeFactory else {
      let reason =
        "Call initialize() before makeViewController() (and again after invalidate())."
      Self.sdkLog("ERROR: makeViewController() without initialize()")
      return Self.fallbackViewController(reason: reason)
    }

    guard
      let viewController = createViewControllerViaFactory(
        reactNativeFactory: reactNativeFactory,
        moduleName: embeddedModuleName,
        initialProps: initialProps
      )
    else {
      let reason =
        "Could not create root view. In DEBUG, start Metro or use the pod shipped bundle; in Release, verify main.jsbundle is in the pod."
      Self.sdkLog("ERROR: makeViewController() factory failed")
      return Self.fallbackViewController(reason: reason)
    }

    Self.sdkLog("makeViewController() OK — factory-created module \(embeddedModuleName)")
    return viewController
  }

  public func invalidate() {
    Self.sdkLog("invalidate()")
    reactNativeFactory?.bridge?.invalidate()
    reactNativeFactory = nil
    delegate = nil
    customBundleURL = nil
  }

  @discardableResult
  private func checkReactNativeVersionCompatible() -> Bool {
    let version = Self.reactNativeVersionString() ?? "unknown"
    guard version.hasPrefix(Self.supportedReactNativeVersionPrefix) else {
      reactNativeVersionCompatible = false
      let message =
        "SeiChatSDK is verified for React Native \(Self.supportedReactNativeVersionPrefix)x; " +
        "host React-Core reports \(version). Align RN or ship a matching embed SDK build."
      Self.sdkLog("ERROR: \(message)")
#if DEBUG
      assertionFailure(message)
#endif
      return false
    }
    reactNativeVersionCompatible = true
    Self.sdkLog("React Native version OK: \(version)")
    return true
  }

  private static func reactNativeVersionString() -> String? {
    // Do not use React-Core CFBundleShortVersionString (often "1.0"); use RN's version API.
    let info = RCTGetReactNativeVersion()
    guard
      let major = info[RCTVersionMajor] as? NSNumber,
      let minor = info[RCTVersionMinor] as? NSNumber,
      let patch = info[RCTVersionPatch] as? NSNumber
    else {
      return nil
    }
    return "\(major.intValue).\(minor.intValue).\(patch.intValue)"
  }

  private func createViewControllerViaFactory(
    reactNativeFactory: RCTReactNativeFactory,
    moduleName: String,
    initialProps: [String: Any]
  ) -> UIViewController? {
    let factoryObject: AnyObject = reactNativeFactory.rootViewFactory

    if let vc: UIViewController = invokeSelector(
      object: factoryObject,
      selectorName: "viewControllerWithModuleName:initialProperties:",
      moduleName: moduleName,
      initialProps: initialProps
    ) {
      return vc
    }

    if let view: UIView = invokeSelector(
      object: factoryObject,
      selectorName: "viewWithModuleName:initialProperties:",
      moduleName: moduleName,
      initialProps: initialProps
    ) {
      let vc = UIViewController()
      vc.view = view
      return vc
    }

    return nil
  }

  private func invokeSelector<T: AnyObject>(
    object: AnyObject,
    selectorName: String,
    moduleName: String,
    initialProps: [String: Any]
  ) -> T? {
    let selector = NSSelectorFromString(selectorName)
    guard object.responds(to: selector) else { return nil }

    guard let target = object as? NSObject else {
      Self.sdkLog(
        "ERROR: rootViewFactory is not NSObject — cannot call \(selectorName). " +
          "Re-verify against React Native \(Self.supportedReactNativeVersionPrefix)x headers."
      )
      return nil
    }

    guard
      let unmanaged = target.perform(
        selector,
        with: moduleName as NSString,
        with: initialProps as NSDictionary
      )
    else {
      return nil
    }

    // RN 0.84 rootViewFactory factory selectors follow Cocoa naming (no copy/new/alloc) → autoreleased (+0).
    // perform returns +0 for such methods; takeUnretainedValue is correct. Re-verify if RN changes ownership.
    return unmanaged.takeUnretainedValue() as? T
  }
}

final class SeiChatReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  private let customBundleURL: URL?

  init(customBundleURL: URL?) {
    self.customBundleURL = customBundleURL
    super.init()
  }

  private func resolveShippedBundleURL() -> URL? {
    Bundle(for: SeiChatSDK.self).url(forResource: "main", withExtension: "jsbundle")
  }

  override func bundleURL() -> URL? {
    if let customBundleURL {
      SeiChatSDK.logBundleURL(customBundleURL, source: "customBundleURL")
      return customBundleURL
    }
#if DEBUG
    let provider = RCTBundleURLProvider.sharedSettings()
    let hostPort = provider.packagerServerHostPort()
    SeiChatSDK.sdkLog("Metro packager host:port checked: \(hostPort.isEmpty ? "(empty)" : hostPort)")
    if !hostPort.isEmpty, RCTBundleURLProvider.isPackagerRunning(hostPort) {
      let metro = provider.jsBundleURL(forBundleRoot: "index")
      SeiChatSDK.logBundleURL(metro, source: "Metro @ \(hostPort)")
      return metro
    }
    if let shipped = resolveShippedBundleURL() {
      let shippedSource = hostPort.isEmpty
        ? "shipped main.jsbundle (Metro host not configured)"
        : "shipped main.jsbundle (Metro not running @ \(hostPort))"
      SeiChatSDK.logBundleURL(shipped, source: shippedSource)
      return shipped
    }
    SeiChatSDK.logBundleURL(
      nil,
      source: "no bundle — start Metro or ship main.jsbundle into the pod"
    )
    return nil
#else
    let shipped = resolveShippedBundleURL()
    SeiChatSDK.logBundleURL(shipped, source: "shipped main.jsbundle")
    return shipped
#endif
  }
}
