// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import TikTokOpenAuthSDK

/// Converts TikTok SDK responses into Pigeon results.
enum ResultMapper {
  /// OAuth `error` values that mean the app or portal is misconfigured.
  private static let configurationErrors: Set<String> = [
    "invalid_client",
    "invalid_redirect_uri",
    "invalid_request",
    "invalid_scope",
    "unauthorized_client",
    "unsupported_response_type",
  ]

  static func map(_ response: TikTokAuthResponse, record: PendingAuthRecord) -> PlatformAuthResult {
    if response.errorCode == .noError, let authCode = response.authCode, !authCode.isEmpty {
      return PlatformAuthResult(
        errorKind: .success,
        usedWebAuth: record.usedWebAuth,
        grantedScopes: (response.grantedPermissions ?? []).sorted(),
        authCode: authCode,
        codeVerifier: record.codeVerifier,
        state: response.state,
        expectedState: record.expectedState,
        redirectUri: record.redirectUri
      )
    }

    var nativeCode = "\(response.errorCode.rawValue)"
    if let error = response.error, !error.isEmpty { nativeCode += ":\(error)" }
    return PlatformAuthResult(
      errorKind: errorKind(for: response.errorCode, error: response.error),
      usedWebAuth: record.usedWebAuth,
      grantedScopes: [],
      expectedState: record.expectedState,
      redirectUri: record.redirectUri,
      nativeCode: nativeCode,
      errorDescription: response.errorDescription ?? response.error
    )
  }

  static func errorKind(for code: TikTokAuthResponseErrorCode, error: String?) -> PlatformErrorKind {
    // The SDK reports a closed browser / cancelled open as `cancelled` with
    // error "access_denied", so the code must be checked first.
    if code == .cancelled { return .cancelled }
    if code == .missingParams { return .misconfigured }
    if let error, configurationErrors.contains(error) { return .misconfigured }
    if code == .denied || error == "access_denied" { return .denied }
    return .failed
  }

  /// A failure that did not come from TikTok.
  static func failure(
    _ kind: PlatformErrorKind,
    _ description: String,
    record: PendingAuthRecord? = nil
  ) -> PlatformAuthResult {
    PlatformAuthResult(
      errorKind: kind,
      usedWebAuth: record?.usedWebAuth ?? false,
      grantedScopes: [],
      expectedState: record?.expectedState,
      redirectUri: record?.redirectUri,
      errorDescription: description
    )
  }
}
