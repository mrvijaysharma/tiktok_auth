// Copyright 2026 The tiktok_auth authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package dev.tiktokauth.android

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/** One sign-in attempt, from the moment Dart starts it until TikTok answers. */
internal data class PendingAuth(
    val id: String,
    val clientKey: String,
    val redirectUri: String,
    val scopes: List<String>,
    val state: String,
    val codeVerifier: String,
    val preferWebAuth: Boolean,
    val disableAutoAuth: Boolean,
    val language: String?,
    val usedWebAuth: Boolean,
    val createdAtMillis: Long,
) {
    fun toJson(): String =
        JSONObject()
            .put(ID, id)
            .put(CLIENT_KEY, clientKey)
            .put(REDIRECT_URI, redirectUri)
            .put(SCOPES, JSONArray(scopes))
            .put(STATE, state)
            .put(CODE_VERIFIER, codeVerifier)
            .put(PREFER_WEB_AUTH, preferWebAuth)
            .put(DISABLE_AUTO_AUTH, disableAutoAuth)
            .putOpt(LANGUAGE, language)
            .put(USED_WEB_AUTH, usedWebAuth)
            .put(CREATED_AT, createdAtMillis)
            .toString()

    companion object {
        private const val ID = "id"
        private const val CLIENT_KEY = "clientKey"
        private const val REDIRECT_URI = "redirectUri"
        private const val SCOPES = "scopes"
        private const val STATE = "state"
        private const val CODE_VERIFIER = "codeVerifier"
        private const val PREFER_WEB_AUTH = "preferWebAuth"
        private const val DISABLE_AUTO_AUTH = "disableAutoAuth"
        private const val LANGUAGE = "language"
        private const val USED_WEB_AUTH = "usedWebAuth"
        private const val CREATED_AT = "createdAtMillis"

        fun fromJson(json: String): PendingAuth? =
            try {
                val o = JSONObject(json)
                val scopes = o.getJSONArray(SCOPES)
                PendingAuth(
                    id = o.getString(ID),
                    clientKey = o.getString(CLIENT_KEY),
                    redirectUri = o.getString(REDIRECT_URI),
                    scopes = List(scopes.length()) { scopes.getString(it) },
                    state = o.getString(STATE),
                    codeVerifier = o.getString(CODE_VERIFIER),
                    preferWebAuth = o.getBoolean(PREFER_WEB_AUTH),
                    disableAutoAuth = o.getBoolean(DISABLE_AUTO_AUTH),
                    language = if (o.isNull(LANGUAGE)) null else o.getString(LANGUAGE),
                    usedWebAuth = o.getBoolean(USED_WEB_AUTH),
                    createdAtMillis = o.getLong(CREATED_AT),
                )
            } catch (e: JSONException) {
                null
            }
    }
}
