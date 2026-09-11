// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import TikTokOpenSDKCore
import UIKit

/// The iOS implementation of the tiktok_auth plugin.
///
/// Registers itself for application and scene lifecycle events, so apps do
/// not need to forward URLs from their AppDelegate or SceneDelegate.
public final class TikTokAuthPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private let coordinator: AuthCoordinator

  init(coordinator: AuthCoordinator = AuthCoordinator()) {
    self.coordinator = coordinator
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = TikTokAuthPlugin()
    TikTokAuthHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: plugin)
    registrar.addApplicationDelegate(plugin)
    registrar.addSceneDelegate(plugin)
  }

  // MARK: - UIApplicationDelegate (apps that do not use scenes)

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    coordinator.handle(url: url)
  }

  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([Any]) -> Void
  ) -> Bool {
    guard let url = userActivity.webpageURL else { return false }
    return coordinator.handle(url: url)
  }

  public func applicationDidEnterBackground(_ application: UIApplication) {
    coordinator.appDidEnterBackground()
  }

  public func applicationDidBecomeActive(_ application: UIApplication) {
    coordinator.appDidBecomeActive()
  }

  // MARK: - FlutterSceneLifeCycleDelegate

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    // A cold start through the redirect Universal Link.
    guard let options = connectionOptions else { return false }
    var handled = false
    for context in options.urlContexts {
      handled = coordinator.handle(url: context.url) || handled
    }
    for activity in options.userActivities {
      if let url = activity.webpageURL {
        handled = coordinator.handle(url: url) || handled
      }
    }
    return handled
  }

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in URLContexts {
      handled = coordinator.handle(url: context.url) || handled
    }
    return handled
  }

  public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    guard let url = userActivity.webpageURL else { return false }
    return coordinator.handle(url: url)
  }

  public func sceneDidEnterBackground(_ scene: UIScene) {
    coordinator.appDidEnterBackground()
  }

  public func sceneDidBecomeActive(_ scene: UIScene) {
    coordinator.appDidBecomeActive()
  }
}

// MARK: - TikTokAuthHostApi

extension TikTokAuthPlugin: TikTokAuthHostApi {
  func validateConfiguration(clientKey: String, redirectUri: String) throws -> [String] {
    coordinator.configuredRedirectUri = redirectUri
    return ConfigValidator.validate(clientKey: clientKey, info: Bundle.main.infoDictionary ?? [:])
  }

  func isTikTokInstalled() throws -> Bool {
    UIApplication.shared.isTikTokInstalled()
  }

  func authorize(request: PlatformAuthRequest) async throws -> PlatformAuthResult {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        self.coordinator.start(request) { result in
          continuation.resume(returning: result)
        }
      }
    }
  }

  func takePendingResult() throws -> PlatformAuthResult? {
    coordinator.takePendingResult()
  }
}
