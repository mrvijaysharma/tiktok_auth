// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// Finds definite problems in the app's Info.plist.
enum ConfigValidator {
  /// URL schemes the TikTok SDK queries to detect and open the TikTok app.
  static let requiredQuerySchemes = ["tiktokopensdk", "snssdk1180", "snssdk1233"]

  static func validate(clientKey: String, info: [String: Any]) -> [String] {
    var problems: [String] = []

    let plistClientKey = (info["TikTokClientKey"] as? String) ?? ""
    if plistClientKey.isEmpty {
      problems.append(
        "Info.plist is missing TikTokClientKey. Add <key>TikTokClientKey</key>"
          + "<string>\(clientKey)</string> to ios/Runner/Info.plist.")
    } else if plistClientKey != clientKey {
      problems.append(
        "TikTokClientKey in Info.plist (\(plistClientKey)) does not match the clientKey "
          + "passed to initialize() (\(clientKey)).")
    }

    let querySchemes = (info["LSApplicationQueriesSchemes"] as? [String]) ?? []
    let missingSchemes = requiredQuerySchemes.filter { !querySchemes.contains($0) }
    if !missingSchemes.isEmpty {
      problems.append(
        "Info.plist LSApplicationQueriesSchemes is missing "
          + "\(missingSchemes.joined(separator: ", ")). Without them the TikTok app cannot "
          + "be detected and the browser is always used.")
    }

    let urlTypes = (info["CFBundleURLTypes"] as? [[String: Any]]) ?? []
    let urlSchemes = urlTypes.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
    if !urlSchemes.contains(clientKey) {
      problems.append(
        "Info.plist CFBundleURLTypes has no URL scheme \"\(clientKey)\". Browser sign-in "
          + "(when the TikTok app is not installed) cannot return to the app without it.")
    }

    return problems
  }
}
