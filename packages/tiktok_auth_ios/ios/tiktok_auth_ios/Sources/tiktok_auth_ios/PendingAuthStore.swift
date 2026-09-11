// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// The parts of a sign-in attempt needed to finish it after a relaunch.
struct PendingAuthRecord: Codable, Equatable {
  let id: String
  let redirectUri: String
  let expectedState: String
  let codeVerifier: String
  let usedWebAuth: Bool
  let createdAt: Date
}

/// Persists a sign-in across app relaunches in `UserDefaults`.
///
/// Entries expire after `maxAge` because TikTok authorization codes are
/// short-lived.
final class PendingAuthStore {
  static let maxAge: TimeInterval = 15 * 60

  private static let inProgressKey = "dev.tiktokauth.ios.inProgress"
  private static let completedKey = "dev.tiktokauth.ios.completed"

  private let defaults: UserDefaults
  private let now: () -> Date

  init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
    self.defaults = defaults
    self.now = now
  }

  func saveInProgress(_ record: PendingAuthRecord) {
    defaults.set(try? JSONEncoder().encode(record), forKey: Self.inProgressKey)
  }

  func loadInProgress() -> PendingAuthRecord? {
    guard let data = defaults.data(forKey: Self.inProgressKey),
      let record = try? JSONDecoder().decode(PendingAuthRecord.self, from: data)
    else { return nil }
    guard now().timeIntervalSince(record.createdAt) <= Self.maxAge else {
      clearInProgress()
      return nil
    }
    return record
  }

  func clearInProgress() {
    defaults.removeObject(forKey: Self.inProgressKey)
  }

  func saveCompleted(_ result: PlatformAuthResult) {
    let record = CompletedRecord(result: result, completedAt: now())
    defaults.set(try? JSONEncoder().encode(record), forKey: Self.completedKey)
  }

  func takeCompleted() -> PlatformAuthResult? {
    guard let data = defaults.data(forKey: Self.completedKey) else { return nil }
    defaults.removeObject(forKey: Self.completedKey)
    guard let record = try? JSONDecoder().decode(CompletedRecord.self, from: data),
      now().timeIntervalSince(record.completedAt) <= Self.maxAge
    else { return nil }
    return record.result
  }
}

private struct CompletedRecord: Codable {
  let errorKind: Int
  let usedWebAuth: Bool
  let grantedScopes: [String]
  let authCode: String?
  let codeVerifier: String?
  let state: String?
  let expectedState: String?
  let redirectUri: String?
  let nativeCode: String?
  let errorDescription: String?
  let completedAt: Date

  init(result: PlatformAuthResult, completedAt: Date) {
    errorKind = result.errorKind.rawValue
    usedWebAuth = result.usedWebAuth
    grantedScopes = result.grantedScopes
    authCode = result.authCode
    codeVerifier = result.codeVerifier
    state = result.state
    expectedState = result.expectedState
    redirectUri = result.redirectUri
    nativeCode = result.nativeCode
    errorDescription = result.errorDescription
    self.completedAt = completedAt
  }

  var result: PlatformAuthResult {
    PlatformAuthResult(
      errorKind: PlatformErrorKind(rawValue: errorKind) ?? .failed,
      usedWebAuth: usedWebAuth,
      grantedScopes: grantedScopes,
      authCode: authCode,
      codeVerifier: codeVerifier,
      state: state,
      expectedState: expectedState,
      redirectUri: redirectUri,
      nativeCode: nativeCode,
      errorDescription: errorDescription
    )
  }
}
