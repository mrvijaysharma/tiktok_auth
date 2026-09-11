import Flutter
import TikTokOpenAuthSDK
import UIKit
import XCTest

@testable import tiktok_auth_ios

private let redirectUri = "https://example.com/tiktok/callback"

private func makeRecord(createdAt: Date = Date()) -> PendingAuthRecord {
  PendingAuthRecord(
    id: "session",
    redirectUri: redirectUri,
    expectedState: "expected-state",
    codeVerifier: "verifier",
    usedWebAuth: false,
    createdAt: createdAt
  )
}

private func makeStore(now: @escaping () -> Date = Date.init) -> PendingAuthStore {
  let suite = "tiktok_auth_tests.\(UUID().uuidString)"
  return PendingAuthStore(defaults: UserDefaults(suiteName: suite)!, now: now)
}

final class ConfigValidatorTests: XCTestCase {
  private let validInfo: [String: Any] = [
    "TikTokClientKey": "awkey",
    "LSApplicationQueriesSchemes": ["tiktokopensdk", "snssdk1180", "snssdk1233"],
    "CFBundleURLTypes": [["CFBundleURLSchemes": ["awkey"]]],
  ]

  func testValidInfoHasNoProblems() {
    XCTAssertEqual(ConfigValidator.validate(clientKey: "awkey", info: validInfo), [])
  }

  func testMissingClientKey() {
    var info = validInfo
    info["TikTokClientKey"] = nil
    let problems = ConfigValidator.validate(clientKey: "awkey", info: info)
    XCTAssertEqual(problems.count, 1)
    XCTAssertTrue(problems[0].contains("missing TikTokClientKey"))
  }

  func testMismatchedClientKey() {
    var info = validInfo
    info["TikTokClientKey"] = "other"
    info["CFBundleURLTypes"] = [["CFBundleURLSchemes": ["awkey"]]]
    let problems = ConfigValidator.validate(clientKey: "awkey", info: info)
    XCTAssertEqual(problems.count, 1)
    XCTAssertTrue(problems[0].contains("does not match"))
  }

  func testMissingQuerySchemes() {
    var info = validInfo
    info["LSApplicationQueriesSchemes"] = ["tiktokopensdk"]
    let problems = ConfigValidator.validate(clientKey: "awkey", info: info)
    XCTAssertEqual(problems.count, 1)
    XCTAssertTrue(problems[0].contains("snssdk1180, snssdk1233"))
  }

  func testMissingUrlScheme() {
    var info = validInfo
    info["CFBundleURLTypes"] = nil
    let problems = ConfigValidator.validate(clientKey: "awkey", info: info)
    XCTAssertEqual(problems.count, 1)
    XCTAssertTrue(problems[0].contains("CFBundleURLTypes"))
  }
}

final class ResultMapperTests: XCTestCase {
  private func response(_ query: String) throws -> TikTokAuthResponse {
    let url = try XCTUnwrap(URL(string: "\(redirectUri)?\(query)"))
    return try TikTokAuthResponse(fromURL: url, redirectURI: redirectUri)
  }

  func testSuccess() throws {
    let result = ResultMapper.map(
      try response("code=abc&state=expected-state&scopes=video.list,user.info.basic"),
      record: makeRecord())
    XCTAssertEqual(result.errorKind, .success)
    XCTAssertEqual(result.authCode, "abc")
    XCTAssertEqual(result.codeVerifier, "verifier")
    XCTAssertEqual(result.state, "expected-state")
    XCTAssertEqual(result.expectedState, "expected-state")
    XCTAssertEqual(result.redirectUri, redirectUri)
    XCTAssertEqual(result.grantedScopes, ["user.info.basic", "video.list"])
    XCTAssertNil(result.nativeCode)
  }

  func testCancelledWinsOverAccessDenied() throws {
    let result = ResultMapper.map(
      try response("error_code=-2&error=access_denied&error_description=cancelled"),
      record: makeRecord())
    XCTAssertEqual(result.errorKind, .cancelled)
    XCTAssertEqual(result.nativeCode, "-2:access_denied")
    XCTAssertEqual(result.errorDescription, "cancelled")
    XCTAssertNil(result.authCode)
  }

  func testDenied() throws {
    XCTAssertEqual(
      ResultMapper.map(try response("error_code=-4"), record: makeRecord()).errorKind, .denied)
  }

  func testConfigurationErrors() throws {
    XCTAssertEqual(
      ResultMapper.map(
        try response("error_code=-1&error=invalid_redirect_uri"), record: makeRecord()
      ).errorKind,
      .misconfigured)
    XCTAssertEqual(
      ResultMapper.map(try response("error_code=10005"), record: makeRecord()).errorKind,
      .misconfigured)
  }

  func testOtherErrorsFail() throws {
    XCTAssertEqual(
      ResultMapper.map(try response("error_code=-3"), record: makeRecord()).errorKind, .failed)
    XCTAssertEqual(
      ResultMapper.map(try response("error_code=-8"), record: makeRecord()).errorKind, .failed)
  }
}

final class PendingAuthStoreTests: XCTestCase {
  func testInProgressRoundTrip() {
    let store = makeStore()
    let record = makeRecord()
    store.saveInProgress(record)
    XCTAssertEqual(store.loadInProgress(), record)
    store.clearInProgress()
    XCTAssertNil(store.loadInProgress())
  }

  func testInProgressExpires() {
    var now = Date()
    let store = makeStore(now: { now })
    store.saveInProgress(makeRecord(createdAt: now))
    now = now.addingTimeInterval(PendingAuthStore.maxAge + 1)
    XCTAssertNil(store.loadInProgress())
  }

  func testCompletedIsTakenOnce() {
    let store = makeStore()
    store.saveCompleted(
      PlatformAuthResult(
        errorKind: .success, usedWebAuth: true, grantedScopes: ["user.info.basic"],
        authCode: "abc", codeVerifier: "verifier", state: "s", expectedState: "s"))
    let result = store.takeCompleted()
    XCTAssertEqual(result?.authCode, "abc")
    XCTAssertEqual(result?.usedWebAuth, true)
    XCTAssertEqual(result?.grantedScopes, ["user.info.basic"])
    XCTAssertNil(store.takeCompleted())
  }
}

final class AuthCoordinatorTests: XCTestCase {
  func testIgnoresUnrelatedUrls() throws {
    let coordinator = AuthCoordinator(store: makeStore(), tiktokInstalled: { false })
    coordinator.configuredRedirectUri = redirectUri
    XCTAssertFalse(coordinator.handle(url: try XCTUnwrap(URL(string: "https://example.com/other"))))
    XCTAssertFalse(coordinator.handle(url: try XCTUnwrap(URL(string: "myapp://open"))))
  }

  func testFinishesStoredAttemptAfterRelaunch() throws {
    let store = makeStore()
    store.saveInProgress(makeRecord())
    let coordinator = AuthCoordinator(store: store, tiktokInstalled: { true })

    let url = try XCTUnwrap(URL(string: "\(redirectUri)?code=abc&state=expected-state"))
    XCTAssertTrue(coordinator.handle(url: url))

    XCTAssertNil(store.loadInProgress())
    let result = coordinator.takePendingResult()
    XCTAssertEqual(result?.errorKind, .success)
    XCTAssertEqual(result?.authCode, "abc")
    XCTAssertEqual(result?.codeVerifier, "verifier")
    XCTAssertEqual(result?.expectedState, "expected-state")
  }

  func testClaimsCallbackWithoutPendingAttempt() throws {
    let coordinator = AuthCoordinator(store: makeStore(), tiktokInstalled: { true })
    coordinator.configuredRedirectUri = redirectUri
    XCTAssertTrue(coordinator.handle(url: try XCTUnwrap(URL(string: "\(redirectUri)?code=x"))))
    XCTAssertNil(coordinator.takePendingResult())
  }
}
