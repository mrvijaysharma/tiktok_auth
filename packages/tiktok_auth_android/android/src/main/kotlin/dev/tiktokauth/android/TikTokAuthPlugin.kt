// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import android.app.Activity
import android.content.Context
import com.tiktok.open.sdk.auth.utils.PKCEUtils
import com.tiktok.open.sdk.core.appcheck.TikTokAppCheckUtil
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.util.UUID
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/** The Android implementation of the tiktok_auth plugin. */
class TikTokAuthPlugin : FlutterPlugin, ActivityAware, TikTokAuthHostApi {
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        TikTokAuthHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TikTokAuthHostApi.setUp(binding.binaryMessenger, null)
        // A sign-in that finishes now is kept for takePendingResult().
        AuthCoordinator.detachCallback()
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun validateConfiguration(clientKey: String, redirectUri: String): List<String> =
        ConfigValidator.validate(requireContext(), redirectUri)

    override fun isTikTokInstalled(): Boolean =
        TikTokAppCheckUtil.isTikTokAppInstalled(requireContext())

    // Pigeon calls this on the main thread.
    override suspend fun authorize(request: PlatformAuthRequest): PlatformAuthResult =
        suspendCancellableCoroutine { continuation ->
            startAuthorization(request) { result ->
                if (continuation.isActive) continuation.resume(result)
            }
        }

    override fun takePendingResult(): PlatformAuthResult? =
        PendingAuthStore(requireContext()).takeCompleted()

    private fun startAuthorization(
        request: PlatformAuthRequest,
        onResult: (PlatformAuthResult) -> Unit,
    ) {
        val host = activity
        if (host == null) {
            onResult(
                ResultMapper.failure(
                    PlatformErrorKind.FAILED,
                    "TikTok sign-in needs a foreground activity. Call signIn() while the " +
                        "app is visible.",
                ),
            )
            return
        }

        val auth =
            PendingAuth(
                id = UUID.randomUUID().toString(),
                clientKey = request.clientKey,
                redirectUri = request.redirectUri,
                scopes = request.scopes,
                state = request.state,
                codeVerifier = PKCEUtils.generateCodeVerifier(),
                preferWebAuth = request.preferWebAuth,
                disableAutoAuth = request.disableAutoAuth,
                language = request.language,
                // Mirrors the SDK: AuthMethod.TikTokApp falls back to a Custom Tab
                // when no TikTok app is installed.
                usedWebAuth =
                    request.preferWebAuth || !TikTokAppCheckUtil.isTikTokAppInstalled(host),
                createdAtMillis = System.currentTimeMillis(),
            )

        if (!AuthCoordinator.begin(auth, onResult)) {
            onResult(
                ResultMapper.failure(
                    PlatformErrorKind.ALREADY_IN_PROGRESS,
                    "A TikTok sign-in is already in progress.",
                ),
            )
            return
        }

        val store = PendingAuthStore(host)
        store.saveInProgress(auth)
        try {
            host.startActivity(TikTokAuthActivity.startIntent(host, auth.id))
        } catch (e: RuntimeException) {
            AuthCoordinator.complete(
                store,
                auth.id,
                ResultMapper.failure(
                    PlatformErrorKind.FAILED,
                    "Could not start TikTok sign-in: ${e.message}",
                    auth,
                ),
                fromTikTok = false,
            )
        }
    }

    private fun requireContext(): Context =
        checkNotNull(context) { "tiktok_auth is not attached to a Flutter engine." }
}
