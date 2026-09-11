// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.os.Build
import android.os.Bundle

/**
 * Receives the redirect URI as a verified App Link and hands it to
 * [TikTokAuthActivity] in the app's task.
 *
 * Declared in the plugin manifest with the `tiktokRedirectHost` and
 * `tiktokRedirectPath` placeholders, so the app's `MainActivity` and Flutter
 * deep linking never see the redirect.
 */
class TikTokAuthCallbackActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val redirect = intent
        if (redirect?.data != null) deliver(redirect)
        finish()
    }

    private fun deliver(redirect: Intent) {
        // CLEAR_TOP closes the Custom Tab or TikTok screen above the waiting
        // TikTokAuthActivity and hands it the redirect through onNewIntent.
        val response =
            Intent(this, TikTokAuthActivity::class.java).apply {
                data = redirect.data
                redirect.extras?.let(::putExtras)
                addFlags(
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                )
            }

        // Opened from the Custom Tab, inside the app's task.
        if (!isTaskRoot) {
            startActivity(response)
            return
        }

        // Opened in a task of its own, for example by the TikTok app. Deliver
        // the redirect inside the app's existing task. Starting the launcher
        // intent instead can create a second MainActivity: Flutter apps set
        // taskAffinity="" and the task may not have been started from the
        // launcher (a notification or a deep link, for example).
        val appTask = findAppTask()
        if (appTask != null) {
            appTask.startActivity(this, response, null)
        } else {
            // The app's task is gone. TikTokAuthActivity stores the result and
            // then reopens the app.
            startActivity(response.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /** The app's most recent task other than this one, if there is one. */
    private fun findAppTask(): ActivityManager.AppTask? =
        getSystemService(ActivityManager::class.java)?.appTasks?.firstOrNull { task ->
            task.idOrNull().let { id -> id != null && id != taskId }
        }
}

/** The task's ID, or `null` if the task was removed in the meantime. */
private fun ActivityManager.AppTask.idOrNull(): Int? =
    try {
        val info = taskInfo
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            info.taskId
        } else {
            @Suppress("DEPRECATION")
            info.persistentId
        }
    } catch (e: IllegalArgumentException) {
        null
    }
