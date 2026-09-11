// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import TikTokOpenAuthSDK
import TikTokOpenSDKCore
import UIKit

/// Tracks the single sign-in attempt that may be in progress and completes it
/// exactly once. Used on the main thread only.
final class AuthCoordinator {
  private final class Session {
    /// Strong reference: the TikTok SDK drops the callback when the request is
    /// deallocated.
    let request: TikTokAuthRequest
    let record: PendingAuthRecord
    let completion: (PlatformAuthResult) -> Void
    var leftApp = false

    init(
      request: TikTokAuthRequest,
      record: PendingAuthRecord,
      completion: @escaping (PlatformAuthResult) -> Void
    ) {
      self.request = request
      self.record = record
      self.completion = completion
    }
  }

  /// The redirect URI passed to `initialize`, used to recognise callbacks.
  var configuredRedirectUri: String?

  private var session: Session?
  private var pendingCancel: DispatchWorkItem?
  private let store: PendingAuthStore
  private let tiktokInstalled: () -> Bool
  private let cancelGracePeriod: TimeInterval

  init(
    store: PendingAuthStore = PendingAuthStore(),
    tiktokInstalled: @escaping () -> Bool = { UIApplication.shared.isTikTokInstalled() },
    cancelGracePeriod: TimeInterval = 1.0
  ) {
    self.store = store
    self.tiktokInstalled = tiktokInstalled
    self.cancelGracePeriod = cancelGracePeriod
  }

  var isInProgress: Bool { session != nil }

  func start(_ request: PlatformAuthRequest, completion: @escaping (PlatformAuthResult) -> Void) {
    guard session == nil else {
      completion(
        ResultMapper.failure(.alreadyInProgress, "A TikTok sign-in is already in progress."))
      return
    }

    let authRequest = TikTokAuthRequest(
      scopes: Set(request.scopes), redirectURI: request.redirectUri)
    authRequest.state = request.state
    authRequest.isWebAuth = request.preferWebAuth

    let record = PendingAuthRecord(
      id: UUID().uuidString,
      redirectUri: request.redirectUri,
      expectedState: request.state,
      codeVerifier: authRequest.pkce.codeVerifier,
      // Mirrors the SDK, which uses the browser when TikTok is not installed.
      usedWebAuth: request.preferWebAuth || !tiktokInstalled(),
      createdAt: Date()
    )
    session = Session(request: authRequest, record: record, completion: completion)
    store.saveInProgress(record)

    let started = authRequest.send { [weak self] response in
      DispatchQueue.main.async {
        guard let self else { return }
        let result: PlatformAuthResult
        if let authResponse = response as? TikTokAuthResponse {
          result = ResultMapper.map(authResponse, record: record)
        } else {
          result = ResultMapper.failure(
            .failed, "TikTok returned an unexpected response.", record: record)
        }
        self.complete(sessionId: record.id, with: result)
      }
    }
    if !started {
      complete(
        sessionId: record.id,
        with: ResultMapper.failure(
          .failed,
          "The TikTok SDK could not start sign-in. Check TikTokClientKey in Info.plist and "
            + "the redirect URI.",
          record: record))
    }
  }

  /// Handles [url] if it is a TikTok callback. Returns whether it was claimed.
  func handle(url: URL) -> Bool {
    guard isCallback(url) else { return false }
    if TikTokURLHandler.handleOpenURL(url) { return true }

    // No live request, for example because the app was relaunched: finish the
    // stored attempt and keep the result for takePendingResult().
    if session == nil, let record = store.loadInProgress(),
      url.absoluteString.hasPrefix(record.redirectUri),
      let response = try? TikTokAuthResponse(fromURL: url, redirectURI: record.redirectUri)
    {
      store.clearInProgress()
      store.saveCompleted(ResultMapper.map(response, record: record))
    }
    // Claim every callback URL so the app's router never treats it as a deep link.
    return true
  }

  func appDidEnterBackground() {
    session?.leftApp = true
  }

  /// The user came back. For the TikTok-app flow, no response means they
  /// cancelled; the browser flow reports cancellation itself.
  func appDidBecomeActive() {
    guard let current = session, current.leftApp, !current.record.usedWebAuth else { return }
    pendingCancel?.cancel()
    let record = current.record
    let work = DispatchWorkItem { [weak self] in
      self?.complete(
        sessionId: record.id,
        with: ResultMapper.failure(
          .cancelled,
          "The user returned to the app without completing TikTok sign-in.",
          record: record))
    }
    pendingCancel = work
    DispatchQueue.main.asyncAfter(deadline: .now() + cancelGracePeriod, execute: work)
  }

  func takePendingResult() -> PlatformAuthResult? {
    store.takeCompleted()
  }

  private func isCallback(_ url: URL) -> Bool {
    let redirectUris = [configuredRedirectUri, session?.record.redirectUri, store.loadInProgress()?.redirectUri]
      .compactMap { $0 }
    if redirectUris.contains(where: { url.absoluteString.hasPrefix($0) }) { return true }
    // The browser flow calls back to <clientKey>://response.bridge.tiktok.com/oauth.
    let clientKey = TikTokInfo.clientKey
    return !clientKey.isEmpty && url.scheme?.lowercased() == clientKey.lowercased()
  }

  private func complete(sessionId: String, with result: PlatformAuthResult) {
    guard let current = session, current.record.id == sessionId else { return }
    session = nil
    pendingCancel?.cancel()
    pendingCancel = nil
    store.clearInProgress()
    current.completion(result)
  }
}
