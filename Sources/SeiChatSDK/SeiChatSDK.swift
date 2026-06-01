import Foundation
import os.log
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import UIKit

@objcMembers
public final class SeiChatSDK: NSObject {
  public static let shared = SeiChatSDK()

  private static let log = Logger(subsystem: "SeiChatSDK", category: "embed")

  private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  private var customBundleURL: URL?
  private let embeddedModuleName = "SeiChatEmbedded"
  private var delegate: SeiChatReactNativeDelegate?
  private var reactNativeFactory: RCTReactNativeFactory?

  private static func sdkLog(_ message: String) {
    log.info("\(message, privacy: .public)")
    print("[SeiChatSDK] \(message)")
  }

  fileprivate static func logBundleURL(_ url: URL?, source: String) {
    sdkLog("bundleURL() → \(source): \(url?.absoluteString ?? "nil")")
  }

  private override init() {
    super.init()
    Self.sdkLog("shared singleton init")
  }

  /// Initializes RN factory once for host app embedding.
  public func initialize(
    launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
    customBundleURL: URL? = nil
  ) {
    Self.sdkLog("initialize() — customBundleURL: \(customBundleURL?.absoluteString ?? "nil")")
    self.launchOptions = launchOptions
    let bundleURLChanged = self.customBundleURL != customBundleURL
    self.customBundleURL = customBundleURL
    if reactNativeFactory != nil {
      if bundleURLChanged {
        invalidate()
      } else {
        return
      }
    }

    let sdkDelegate = SeiChatReactNativeDelegate(customBundleURL: customBundleURL)
    sdkDelegate.dependencyProvider = RCTAppDependencyProvider()

    delegate = sdkDelegate
    reactNativeFactory = RCTReactNativeFactory(delegate: sdkDelegate)
  }

  /// Creates a UIViewController that renders SeiChatEmbedded.
  /// Designed to be invoked from UIKit/SwiftUI/Storyboard button actions.
  public func makeViewController(initialProps: [String: Any] = [:]) -> UIViewController {
    Self.sdkLog("makeViewController() — props keys: \(initialProps.keys.sorted().joined(separator: ","))")

    if reactNativeFactory == nil {
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
      fallback.view.backgroundColor = .white
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
  }

  private func createViewControllerViaFactory(
    reactNativeFactory: RCTReactNativeFactory,
    moduleName: String,
    initialProps: [String: Any]
  ) -> UIViewController? {
    let factoryObject: AnyObject = reactNativeFactory.rootViewFactory

    if let vc = invokeViewControllerSelector(
      object: factoryObject,
      selectorName: "viewControllerWithModuleName:initialProperties:",
      moduleName: moduleName,
      initialProps: initialProps
    ) {
      return vc
    }

    if let view = invokeViewSelector(
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

  private func invokeViewControllerSelector(
    object: AnyObject,
    selectorName: String,
    moduleName: String,
    initialProps: [String: Any]
  ) -> UIViewController? {
    let selector = NSSelectorFromString(selectorName)
    guard object.responds(to: selector), let raw = object.method(for: selector) else { return nil }

    typealias Function = @convention(c) (AnyObject, Selector, NSString, NSDictionary) -> AnyObject?
    let function = unsafeBitCast(raw, to: Function.self)
    let result = function(object, selector, moduleName as NSString, initialProps as NSDictionary)
    return result as? UIViewController
  }

  private func invokeViewSelector(
    object: AnyObject,
    selectorName: String,
    moduleName: String,
    initialProps: [String: Any]
  ) -> UIView? {
    let selector = NSSelectorFromString(selectorName)
    guard object.responds(to: selector), let raw = object.method(for: selector) else { return nil }

    typealias Function = @convention(c) (AnyObject, Selector, NSString, NSDictionary) -> AnyObject?
    let function = unsafeBitCast(raw, to: Function.self)
    let result = function(object, selector, moduleName as NSString, initialProps as NSDictionary)
    return result as? UIView
  }
}

final class SeiChatReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  private let customBundleURL: URL?

  init(customBundleURL: URL?) {
    self.customBundleURL = customBundleURL
    super.init()
  }

  override func sourceURL(for bridge: RCTBridge) -> URL? {
    bundleURL()
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
    if !hostPort.isEmpty, RCTBundleURLProvider.isPackagerRunning(hostPort) {
      let metro = provider.jsBundleURL(forBundleRoot: "index")
      SeiChatSDK.logBundleURL(metro, source: "Metro")
      return metro
    }
    if let shipped = resolveShippedBundleURL() {
      SeiChatSDK.logBundleURL(shipped, source: "shipped main.jsbundle (Metro unavailable)")
      return shipped
    }
    SeiChatSDK.logBundleURL(nil, source: "Metro not running and no shipped bundle in pod")
    return nil
#else
    let shipped = resolveShippedBundleURL()
    SeiChatSDK.logBundleURL(shipped, source: "shipped main.jsbundle")
    return shipped
#endif
  }
}
