// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.tiktok.open.sdk.auth.AuthApi
import com.tiktok.open.sdk.auth.AuthRequest

/**
 * An invisible activity that owns one sign-in attempt.
 *
 * The TikTok app (via `startActivityForResult`) and the Custom Tab are both
 * launched from this activity, so it is resumed exactly when the user comes
 * back. If it resumes without a response, the user cancelled. Responses
 * arrive through [onActivityResult] (TikTok app) or [onNewIntent] (redirect
 * forwarded by [TikTokAuthCallbackActivity]).
 */
class TikTokAuthActivity : Activity() {
    private lateinit var store: PendingAuthStore
    private var auth: PendingAuth? = null
    private var launched = false
    private var leftForAuthorization = false
    private var completed = false
    private val handler = Handler(Looper.getMainLooper())
    private val cancelIfStillWaiting = Runnable {
        auth?.let { current ->
            complete(
                current,
                ResultMapper.failure(
                    PlatformErrorKind.CANCELLED,
                    "The user returned to the app without completing TikTok sign-in.",
                    current,
                ),
                fromTikTok = false,
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = PendingAuthStore(this)

        val sessionId =
            savedInstanceState?.getString(KEY_SESSION_ID) ?: intent.getStringExtra(EXTRA_SESSION_ID)
        auth = findAuth(sessionId)
        launched = savedInstanceState?.getBoolean(KEY_LAUNCHED) ?: false
        leftForAuthorization = launched

        // Created by a forwarded redirect, for example after process death.
        if (handleResponse(intent)) return

        if (auth == null) {
            finishQuietly()
        } else if (!launched) {
            launch()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleResponse(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        handleResponse(data)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(cancelIfStillWaiting)
        if (isFinishing && !completed) {
            // Finished without a response, for example because Back was
            // pressed before the browser appeared. Report it now: onDestroy
            // can run seconds later, once the system is idle.
            auth?.let { current ->
                complete(
                    current,
                    ResultMapper.failure(
                        PlatformErrorKind.CANCELLED,
                        "TikTok sign-in was closed.",
                        current,
                    ),
                    fromTikTok = false,
                )
            }
            return
        }
        if (launched) leftForAuthorization = true
    }

    override fun onResume() {
        super.onResume()
        val current = auth ?: return
        if (completed) return

        // Completed elsewhere, for example by a callback delivered in another task.
        val stillPending =
            AuthCoordinator.current?.id == current.id || store.loadInProgress()?.id == current.id
        if (!stillPending) {
            finishQuietly()
            return
        }

        // Back from TikTok or the browser without a response: the user cancelled.
        // Wait briefly in case the response is still being delivered.
        if (leftForAuthorization) handler.postDelayed(cancelIfStillWaiting, CANCEL_GRACE_MILLIS)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(KEY_SESSION_ID, auth?.id)
        outState.putBoolean(KEY_LAUNCHED, launched)
    }

    override fun onDestroy() {
        handler.removeCallbacks(cancelIfStillWaiting)
        if (isFinishing && !completed) {
            auth?.let { current ->
                completed = true
                AuthCoordinator.complete(
                    store,
                    current.id,
                    ResultMapper.failure(
                        PlatformErrorKind.CANCELLED,
                        "TikTok sign-in was closed.",
                        current,
                    ),
                    fromTikTok = false,
                )
            }
        }
        super.onDestroy()
    }

    private fun findAuth(sessionId: String?): PendingAuth? {
        val inMemory = AuthCoordinator.current
        val persisted = store.loadInProgress()
        return when (sessionId) {
            null -> inMemory ?: persisted
            inMemory?.id -> inMemory
            persisted?.id -> persisted
            else -> null
        }
    }

    private fun launch() {
        val current = auth ?: return
        launched = true

        val request =
            AuthRequest(
                clientKey = current.clientKey,
                scope = current.scopes.joinToString(","),
                redirectUri = current.redirectUri,
                codeVerifier = current.codeVerifier,
                autoAuthDisabled = current.disableAutoAuth,
                state = current.state,
                language = current.language,
            )
        val method =
            if (current.preferWebAuth) AuthApi.AuthMethod.ChromeTab else AuthApi.AuthMethod.TikTokApp

        val started =
            try {
                AuthApi(this).authorize(request, method)
            } catch (e: ActivityNotFoundException) {
                fail(current, "No browser is available to show TikTok sign-in.")
                return
            } catch (e: RuntimeException) {
                fail(current, "The TikTok SDK could not start sign-in: ${e.message}")
                return
            }
        if (!started) {
            fail(current, "The TikTok SDK rejected the sign-in request.")
        }
    }

    private fun handleResponse(intent: Intent?): Boolean {
        if (intent == null || completed) return false
        val current = auth ?: AuthCoordinator.current ?: store.loadInProgress() ?: return false
        val response =
            AuthApi(this).getAuthResponseFromIntent(intent, current.redirectUri) ?: return false
        auth = current
        complete(current, ResultMapper.fromResponse(response, current), fromTikTok = true)
        return true
    }

    private fun fail(current: PendingAuth, message: String) {
        complete(
            current,
            ResultMapper.failure(PlatformErrorKind.FAILED, message, current),
            fromTikTok = false,
        )
    }

    private fun complete(current: PendingAuth, result: PlatformAuthResult, fromTikTok: Boolean) {
        if (completed) return
        completed = true
        handler.removeCallbacks(cancelIfStillWaiting)
        AuthCoordinator.complete(store, current.id, result, fromTikTok)
        finishToApp()
    }

    private fun finishQuietly() {
        completed = true
        finishToApp()
    }

    /**
     * Finishes, first reopening the app if this activity is alone in its task.
     * That happens when the redirect arrives after the app's task was closed;
     * the app then recovers the stored result with getPendingAuthorization().
     */
    private fun finishToApp() {
        if (isTaskRoot) {
            packageManager.getLaunchIntentForPackage(packageName)?.let(::startActivity)
        }
        finish()
    }

    companion object {
        private const val EXTRA_SESSION_ID = "dev.tiktokauth.android.SESSION_ID"
        private const val KEY_SESSION_ID = "sessionId"
        private const val KEY_LAUNCHED = "launched"

        /** How long to wait for a late response after the user returns. */
        private const val CANCEL_GRACE_MILLIS = 500L

        internal fun startIntent(context: Context, sessionId: String): Intent =
            Intent(context, TikTokAuthActivity::class.java)
                .putExtra(EXTRA_SESSION_ID, sessionId)
                .addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
    }
}
