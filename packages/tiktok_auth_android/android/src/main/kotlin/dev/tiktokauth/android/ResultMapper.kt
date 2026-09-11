// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import com.tiktok.open.sdk.auth.AuthResponse
import com.tiktok.open.sdk.core.constants.Constants

/** Converts TikTok SDK responses into Pigeon results. */
internal object ResultMapper {
    /** OAuth `error` values that mean the app or portal is misconfigured. */
    private val CONFIGURATION_ERRORS =
        setOf(
            "invalid_client",
            "invalid_redirect_uri",
            "invalid_request",
            "invalid_scope",
            "unauthorized_client",
            "unsupported_response_type",
        )

    /** TikTok's "App certificate does not match configurations" error. */
    private const val CERTIFICATE_MISMATCH = "10033"

    fun fromResponse(response: AuthResponse, auth: PendingAuth): PlatformAuthResult =
        fromFields(
            authCode = response.authCode,
            state = response.state,
            grantedPermissions = response.grantedPermissions,
            errorCode = response.errorCode,
            errorMessage = response.errorMsg,
            authError = response.authError,
            authErrorDescription = response.authErrorDescription,
            auth = auth,
        )

    fun fromFields(
        authCode: String?,
        state: String?,
        grantedPermissions: String?,
        errorCode: Int,
        errorMessage: String?,
        authError: String?,
        authErrorDescription: String?,
        auth: PendingAuth,
    ): PlatformAuthResult {
        if (!authCode.isNullOrEmpty()) {
            return PlatformAuthResult(
                errorKind = PlatformErrorKind.SUCCESS,
                usedWebAuth = auth.usedWebAuth,
                grantedScopes = splitScopes(grantedPermissions),
                authCode = authCode,
                codeVerifier = auth.codeVerifier,
                state = state,
                expectedState = auth.state,
                redirectUri = auth.redirectUri,
            )
        }

        val description = authErrorDescription?.takeIf { it.isNotBlank() } ?: errorMessage
        return PlatformAuthResult(
            errorKind = errorKindFor(errorCode, authError, description),
            usedWebAuth = auth.usedWebAuth,
            grantedScopes = emptyList(),
            expectedState = auth.state,
            redirectUri = auth.redirectUri,
            nativeCode = if (authError.isNullOrEmpty()) "$errorCode" else "$errorCode:$authError",
            errorDescription = description,
        )
    }

    fun errorKindFor(errorCode: Int, authError: String?, description: String?): PlatformErrorKind =
        when {
            authError in CONFIGURATION_ERRORS -> PlatformErrorKind.MISCONFIGURED
            description?.contains(CERTIFICATE_MISMATCH) == true -> PlatformErrorKind.MISCONFIGURED
            authError == "access_denied" -> PlatformErrorKind.DENIED
            errorCode == Constants.BaseError.CANCELLED -> PlatformErrorKind.CANCELLED
            errorCode == Constants.BaseError.ERROR_DENIED -> PlatformErrorKind.DENIED
            else -> PlatformErrorKind.FAILED
        }

    /** A failure that did not come from TikTok. */
    fun failure(
        kind: PlatformErrorKind,
        description: String?,
        auth: PendingAuth? = null,
    ): PlatformAuthResult =
        PlatformAuthResult(
            errorKind = kind,
            usedWebAuth = auth?.usedWebAuth ?: false,
            grantedScopes = emptyList(),
            expectedState = auth?.state,
            redirectUri = auth?.redirectUri,
            errorDescription = description,
        )

    private fun splitScopes(value: String?): List<String> =
        value.orEmpty().split(',').map { it.trim() }.filter { it.isNotEmpty() }
}
