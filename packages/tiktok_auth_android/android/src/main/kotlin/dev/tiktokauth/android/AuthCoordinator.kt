// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

/**
 * Tracks the single sign-in attempt that may be in progress and completes it
 * exactly once.
 *
 * All members are used from the main thread only.
 */
internal object AuthCoordinator {
    private var session: PendingAuth? = null
    private var callback: ((PlatformAuthResult) -> Unit)? = null

    /** The attempt in progress in this process, if any. */
    val current: PendingAuth?
        get() = session

    /** Starts [auth]. Returns `false` if another attempt is in progress. */
    fun begin(auth: PendingAuth, onResult: (PlatformAuthResult) -> Unit): Boolean {
        if (session != null) return false
        session = auth
        callback = onResult
        return true
    }

    /** Forgets the Dart callback, for example when the engine is detached. */
    fun detachCallback() {
        callback = null
    }

    /**
     * Completes the attempt [sessionId] with [result].
     *
     * Results for an attempt this process no longer knows about (because it
     * was restarted) are persisted for `takePendingResult()` when they came
     * from TikTok ([fromTikTok]); synthesized cancellations are dropped.
     * Results for an older attempt while a newer one runs are ignored.
     */
    fun complete(
        store: PendingAuthStore,
        sessionId: String,
        result: PlatformAuthResult,
        fromTikTok: Boolean,
    ) {
        val active = session
        if (active != null && active.id != sessionId) return

        session = null
        store.clearInProgress()
        val onResult = callback
        callback = null

        if (active != null && onResult != null) {
            onResult(result)
        } else if (fromTikTok) {
            store.saveCompleted(result)
        }
    }
}
