// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build

/** Finds definite problems in the app's native configuration. */
internal object ConfigValidator {
    fun validate(context: Context, redirectUri: String): List<String> {
        val problems = mutableListOf<String>()
        val uri = Uri.parse(redirectUri)
        if (!callbackActivityHandles(context, uri)) {
            problems +=
                "The redirect URI $redirectUri is not handled by this app, so TikTok " +
                "could not return to it. In android/app/build.gradle(.kts) set " +
                "manifestPlaceholders[\"tiktokRedirectHost\"] = \"${uri.host.orEmpty()}\" and " +
                "manifestPlaceholders[\"tiktokRedirectPath\"] = " +
                "\"${uri.path.orEmpty().removePrefix("/")}\" (no leading slash)."
        }
        return problems
    }

    private fun callbackActivityHandles(context: Context, uri: Uri): Boolean {
        val intent =
            Intent(Intent.ACTION_VIEW, uri)
                .addCategory(Intent.CATEGORY_BROWSABLE)
                .setPackage(context.packageName)
        val handlers: List<ResolveInfo> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.queryIntentActivities(intent, 0)
            }
        return handlers.any { it.activityInfo?.name == TikTokAuthCallbackActivity::class.java.name }
    }
}
