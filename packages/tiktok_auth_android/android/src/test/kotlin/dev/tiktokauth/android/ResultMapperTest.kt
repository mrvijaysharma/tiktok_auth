// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import com.tiktok.open.sdk.core.constants.Constants
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class ResultMapperTest {
    private val auth =
        PendingAuth(
            id = "session",
            clientKey = "awkey",
            redirectUri = "https://example.com/tiktok/callback",
            scopes = listOf("user.info.basic", "video.list"),
            state = "expected-state",
            codeVerifier = "verifier",
            preferWebAuth = false,
            disableAutoAuth = false,
            language = null,
            usedWebAuth = true,
            createdAtMillis = 0L,
        )

    private fun map(
        authCode: String? = "",
        errorCode: Int = Constants.BaseError.OK,
        errorMessage: String? = null,
        authError: String? = null,
        authErrorDescription: String? = null,
        grantedPermissions: String? = "",
    ) = ResultMapper.fromFields(
        authCode = authCode,
        state = "returned-state",
        grantedPermissions = grantedPermissions,
        errorCode = errorCode,
        errorMessage = errorMessage,
        authError = authError,
        authErrorDescription = authErrorDescription,
        auth = auth,
    )

    @Test
    fun successCarriesCodeVerifierStateAndScopes() {
        val result = map(authCode = "code", grantedPermissions = "user.info.basic, video.list,")

        assertEquals(PlatformErrorKind.SUCCESS, result.errorKind)
        assertEquals("code", result.authCode)
        assertEquals("verifier", result.codeVerifier)
        assertEquals("returned-state", result.state)
        assertEquals("expected-state", result.expectedState)
        assertEquals("https://example.com/tiktok/callback", result.redirectUri)
        assertEquals(listOf("user.info.basic", "video.list"), result.grantedScopes)
        assertEquals(true, result.usedWebAuth)
        assertNull(result.nativeCode)
    }

    @Test
    fun cancelledErrorCodeMapsToCancelled() {
        val result = map(errorCode = Constants.BaseError.CANCELLED)
        assertEquals(PlatformErrorKind.CANCELLED, result.errorKind)
        assertEquals("${Constants.BaseError.CANCELLED}", result.nativeCode)
        assertNull(result.authCode)
        assertNull(result.codeVerifier)
    }

    @Test
    fun accessDeniedMapsToDenied() {
        val result =
            map(
                errorCode = Constants.BaseError.ERROR_DENIED,
                authError = "access_denied",
                authErrorDescription = "The user denied the request",
            )
        assertEquals(PlatformErrorKind.DENIED, result.errorKind)
        assertEquals("-2:access_denied", result.nativeCode)
        assertEquals("The user denied the request", result.errorDescription)
    }

    @Test
    fun configurationErrorsMapToMisconfigured() {
        for (error in listOf("invalid_client", "invalid_redirect_uri", "invalid_scope")) {
            val result = map(errorCode = Constants.BaseError.ERROR_DENIED, authError = error)
            assertEquals(PlatformErrorKind.MISCONFIGURED, result.errorKind, error)
        }
    }

    @Test
    fun certificateMismatchMapsToMisconfigured() {
        val result =
            map(
                errorCode = Constants.BaseError.FAILED,
                errorMessage = "10033 App certificate does not match configurations",
            )
        assertEquals(PlatformErrorKind.MISCONFIGURED, result.errorKind)
        assertEquals(
            "10033 App certificate does not match configurations",
            result.errorDescription,
        )
    }

    @Test
    fun otherErrorsMapToFailed() {
        assertEquals(
            PlatformErrorKind.FAILED,
            map(errorCode = Constants.BaseError.ERROR_UNKNOWN).errorKind,
        )
        assertEquals(PlatformErrorKind.FAILED, map(errorCode = Constants.BaseError.FAILED).errorKind)
        assertEquals(
            PlatformErrorKind.FAILED,
            map(errorCode = Constants.BaseError.UNSUPPORTED).errorKind,
        )
    }

    @Test
    fun failureKeepsSessionContext() {
        val result = ResultMapper.failure(PlatformErrorKind.CANCELLED, "closed", auth)
        assertEquals(PlatformErrorKind.CANCELLED, result.errorKind)
        assertEquals("expected-state", result.expectedState)
        assertEquals(true, result.usedWebAuth)
        assertEquals("closed", result.errorDescription)
    }
}
