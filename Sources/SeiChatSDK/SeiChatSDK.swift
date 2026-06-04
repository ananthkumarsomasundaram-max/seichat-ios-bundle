import Foundation
import os.log
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import UIKit

public final class SeiChatSDK: NSObject {
  public static let shared = SeiChatSDK()

  private static let log = Logger(subsystem: "SeiChatSDK", category: "embed")

  private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  private var customBundleURL: URL?
  /// Must match AppRegistry.registerComponent('SeiChatEmbedded', …) in index.js.
  private let embeddedModuleName = "SeiChatEmbedded"
  private var delegate: SeiChatReactNativeDelegate?
  private var reactNativeFactory: RCTReactNativeFactory?
  private var isInitialized = false

  private static func sdkLog(_ message: String) {
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

  /// Initializes RN factory once for host app embedding. Call from the main thread only.
  public func initialize(
    launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
    customBundleURL: URL? = nil
  ) {
    Self.sdkLog("initialize() — customBundleURL: \(customBundleURL?.absoluteString ?? "nil")")
    let bundleURLChanged = self.customBundleURL != customBundleURL

    if reactNativeFactory != nil {
      if bundleURLChanged {
        invalidate()
      } else {
        return
      }
    }

    self.launchOptions = launchOptions
    self.customBundleURL = customBundleURL

    let sdkDelegate = SeiChatReactNativeDelegate(customBundleURL: customBundleURL)
    sdkDelegate.dependencyProvider = RCTAppDependencyProvider()

    delegate = sdkDelegate
    reactNativeFactory = RCTReactNativeFactory(delegate: sdkDelegate)
    isInitialized = true
  }

  /// Creates a UIViewController that renders SeiChatEmbedded. Call from the main thread only.
  public func makeViewController(initialProps: [String: Any] = [:]) -> UIViewController {
    Self.sdkLog("makeViewController() — props keys: \(initialProps.keys.sorted().joined(separator: ","))")

    if reactNativeFactory == nil {
      if !isInitialized {
        Self.sdkLog(
          "WARNING: makeViewController() without initialize() — call initialize() after invalidate()"
        )
      }
      initialize(launchOptions: launchOptions, customBundleURL: customBundleURL)
    }

    guard
      let reactNativeFactory,
      let viewController = createViewControllerViaFactory(
        reactNativeFactory: reactNativeFactory,
        moduleName: embeddedModuleName,
        initialProps: initialProps
      )
    else {
      Self.sdkLog("makeViewController() FAILED — no root view (check Metro in DEBUG, main.jsbundle in Release)")
      let fallback = UIViewController()
      fallback.view.backgroundColor = .systemBackground
      return fallback
    }

    Self.sdkLog("makeViewController() OK — factory-created module \(embeddedModuleName)")
    return viewController
  }

  public func invalidate() {
    Self.sdkLog("invalidate()")
    reactNativeFactory?.bridge?.invalidate()
    reactNativeFactory = nil
    delegate = nil
    launchOptions = nil
    customBundleURL = nil
    isInitialized = false
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
    guard object.responds(to: selector), let raw = object.method(for: selector) else { return nil }

    // RN 0.84 rootViewFactory is ObjC-only; IMP matches *WithModuleName:initialProperties:
    typealias Function = @convention(c) (AnyObject, Selector, NSString, NSDictionary) -> AnyObject?
    let function = unsafeBitCast(raw, to: Function.self)
    let result = function(object, selector, moduleName as NSString, initialProps as NSDictionary)
    return result as? T
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
    // Require Metro in debug; do not fall back to Bundle.main/main.jsbundle (stale after pod tests).
    let provider = RCTBundleURLProvider.sharedSettings()
    let hostPort = provider.packagerServerHostPort()
    if !hostPort.isEmpty, RCTBundleURLProvider.isPackagerRunning(hostPort) {
      let metro = provider.jsBundleURL(forBundleRoot: "index")
      SeiChatSDK.logBundleURL(metro, source: "Metro")
      return metro
    }
    SeiChatSDK.logBundleURL(nil, source: "Metro (not running — cd UniversalClientMobile && npm start)")
    return nil
#else
    let shipped = resolveShippedBundleURL()
    SeiChatSDK.logBundleURL(shipped, source: "shipped main.jsbundle")
    return shipped
#endif
  }
}
