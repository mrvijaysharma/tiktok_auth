// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import android.content.Context
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * Persists a sign-in across process death.
 *
 * Android may stop the app while the user is in TikTok or the browser. The
 * attempt in progress is stored so the callback can still be matched when the
 * process is restarted, and the finished result is stored until Dart collects
 * it with `takePendingResult()`. Both entries expire after [MAX_AGE_MILLIS]
 * because TikTok authorization codes are short-lived.
 */
internal class PendingAuthStore(context: Context) {
    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveInProgress(auth: PendingAuth) {
        // commit() rather than apply(): the process may be stopped right after
        // TikTok or the browser comes to the foreground.
        prefs.edit().putString(KEY_IN_PROGRESS, auth.toJson()).commit()
    }

    fun loadInProgress(nowMillis: Long = System.currentTimeMillis()): PendingAuth? {
        val auth = prefs.getString(KEY_IN_PROGRESS, null)?.let(PendingAuth::fromJson)
        if (auth == null || nowMillis - auth.createdAtMillis > MAX_AGE_MILLIS) {
            clearInProgress()
            return null
        }
        return auth
    }

    fun clearInProgress() {
        prefs.edit().remove(KEY_IN_PROGRESS).apply()
    }

    fun saveCompleted(result: PlatformAuthResult, nowMillis: Long = System.currentTimeMillis()) {
        prefs.edit().putString(KEY_COMPLETED, result.toJson(nowMillis)).commit()
    }

    fun takeCompleted(nowMillis: Long = System.currentTimeMillis()): PlatformAuthResult? {
        val json = prefs.getString(KEY_COMPLETED, null) ?: return null
        prefs.edit().remove(KEY_COMPLETED).apply()
        return try {
            val o = JSONObject(json)
            if (nowMillis - o.getLong(COMPLETED_AT) > MAX_AGE_MILLIS) return null
            val scopes = o.getJSONArray(GRANTED_SCOPES)
            PlatformAuthResult(
                errorKind = PlatformErrorKind.ofRaw(o.getInt(ERROR_KIND)) ?: PlatformErrorKind.FAILED,
                usedWebAuth = o.getBoolean(USED_WEB_AUTH),
                grantedScopes = List(scopes.length()) { scopes.getString(it) },
                authCode = o.stringOrNull(AUTH_CODE),
                codeVerifier = o.stringOrNull(CODE_VERIFIER),
                state = o.stringOrNull(STATE),
                expectedState = o.stringOrNull(EXPECTED_STATE),
                redirectUri = o.stringOrNull(REDIRECT_URI),
                nativeCode = o.stringOrNull(NATIVE_CODE),
                errorDescription = o.stringOrNull(ERROR_DESCRIPTION),
            )
        } catch (e: JSONException) {
            null
        }
    }

    private fun PlatformAuthResult.toJson(nowMillis: Long): String =
        JSONObject()
            .put(ERROR_KIND, errorKind.raw)
            .put(USED_WEB_AUTH, usedWebAuth)
            .put(GRANTED_SCOPES, JSONArray(grantedScopes))
            .putOpt(AUTH_CODE, authCode)
            .putOpt(CODE_VERIFIER, codeVerifier)
            .putOpt(STATE, state)
            .putOpt(EXPECTED_STATE, expectedState)
            .putOpt(REDIRECT_URI, redirectUri)
            .putOpt(NATIVE_CODE, nativeCode)
            .putOpt(ERROR_DESCRIPTION, errorDescription)
            .put(COMPLETED_AT, nowMillis)
            .toString()

    private fun JSONObject.stringOrNull(key: String): String? =
        if (has(key) && !isNull(key)) getString(key) else null

    companion object {
        const val MAX_AGE_MILLIS = 15 * 60 * 1000L

        private const val PREFS_NAME = "dev.tiktokauth.android.pending"
        private const val KEY_IN_PROGRESS = "inProgress"
        private const val KEY_COMPLETED = "completed"

        private const val ERROR_KIND = "errorKind"
        private const val USED_WEB_AUTH = "usedWebAuth"
        private const val GRANTED_SCOPES = "grantedScopes"
        private const val AUTH_CODE = "authCode"
        private const val CODE_VERIFIER = "codeVerifier"
        private const val STATE = "state"
        private const val EXPECTED_STATE = "expectedState"
        private const val REDIRECT_URI = "redirectUri"
        private const val NATIVE_CODE = "nativeCode"
        private const val ERROR_DESCRIPTION = "errorDescription"
        private const val COMPLETED_AT = "completedAtMillis"
    }
}
