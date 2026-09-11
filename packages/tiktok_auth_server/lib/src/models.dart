/// Tokens returned by TikTok's `/v2/oauth/token/` endpoint.
class TikTokTokens {
  /// Creates tokens.
  const TikTokTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.openId,
    required this.scopes,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    this.tokenType = 'Bearer',
  });

  /// Parses a token response received at [receivedAt] (default: now).
  factory TikTokTokens.fromJson(
    Map<String, Object?> json, {
    DateTime? receivedAt,
  }) {
    final now = receivedAt ?? DateTime.now();
    return TikTokTokens(
      accessToken: json['access_token']! as String,
      refreshToken: json['refresh_token']! as String,
      openId: json['open_id']! as String,
      scopes: {
        for (final scope in ((json['scope'] as String?) ?? '').split(','))
          if (scope.trim().isNotEmpty) scope.trim(),
      },
      accessTokenExpiresAt: now.add(
        Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 0),
      ),
      refreshTokenExpiresAt: now.add(
        Duration(seconds: (json['refresh_expires_in'] as num?)?.toInt() ?? 0),
      ),
      tokenType: (json['token_type'] as String?) ?? 'Bearer',
    );
  }

  /// The access token, valid for about 24 hours.
  final String accessToken;

  /// The refresh token, valid for about 365 days.
  ///
  /// TikTok may return a new refresh token when you refresh. Always store the
  /// latest one.
  final String refreshToken;

  /// The user's ID within your app. Use it as the user's identifier.
  final String openId;

  /// The scopes the user granted.
  final Set<String> scopes;

  /// When [accessToken] expires.
  final DateTime accessTokenExpiresAt;

  /// When [refreshToken] expires.
  final DateTime refreshTokenExpiresAt;

  /// Always `Bearer`.
  final String tokenType;

  /// Whether [accessToken] expires within [margin] of [now].
  bool isAccessTokenExpired({
    DateTime? now,
    Duration margin = const Duration(minutes: 5),
  }) => !(now ?? DateTime.now()).add(margin).isBefore(accessTokenExpiresAt);

  @override
  String toString() =>
      'TikTokTokens(openId: $openId, scopes: $scopes, '
      'accessToken: <redacted>, refreshToken: <redacted>, '
      'accessTokenExpiresAt: $accessTokenExpiresAt)';
}

/// A field of the TikTok `/v2/user/info/` endpoint.
enum TikTokUserField {
  /// The user's ID within your app. Scope `user.info.basic`.
  openId('open_id'),

  /// The user's ID across apps of the same developer. Scope `user.info.basic`.
  unionId('union_id'),

  /// Profile image URL. Scope `user.info.basic`.
  avatarUrl('avatar_url'),

  /// 100 x 100 profile image URL. Scope `user.info.basic`.
  avatarUrl100('avatar_url_100'),

  /// Large profile image URL. Scope `user.info.basic`.
  avatarLargeUrl('avatar_large_url'),

  /// Display name. Scope `user.info.basic`.
  displayName('display_name'),

  /// Bio. Scope `user.info.profile`.
  bioDescription('bio_description'),

  /// Link to the profile in the TikTok app. Scope `user.info.profile`.
  profileDeepLink('profile_deep_link'),

  /// Whether TikTok verified the account. Scope `user.info.profile`.
  isVerified('is_verified'),

  /// The unique username. Scope `user.info.profile`.
  username('username'),

  /// Follower count. Scope `user.info.stats`.
  followerCount('follower_count'),

  /// Following count. Scope `user.info.stats`.
  followingCount('following_count'),

  /// Total likes. Scope `user.info.stats`.
  likesCount('likes_count'),

  /// Public video count. Scope `user.info.stats`.
  videoCount('video_count');

  const TikTokUserField(this.value);

  /// The fields available with the default `user.info.basic` scope.
  static const Set<TikTokUserField> basic = {
    openId,
    unionId,
    avatarUrl,
    displayName,
  };

  /// The name TikTok uses for this field.
  final String value;
}

/// A TikTok user profile. Fields that were not requested, or whose scope
/// was not granted, are `null`.
class TikTokUser {
  /// Creates a user.
  const TikTokUser({
    this.openId,
    this.unionId,
    this.avatarUrl,
    this.avatarUrl100,
    this.avatarLargeUrl,
    this.displayName,
    this.bioDescription,
    this.profileDeepLink,
    this.isVerified,
    this.username,
    this.followerCount,
    this.followingCount,
    this.likesCount,
    this.videoCount,
    this.raw = const {},
  });

  /// Parses the `data.user` object of a `/v2/user/info/` response.
  factory TikTokUser.fromJson(Map<String, Object?> json) {
    String? string(String key) => json[key] as String?;
    int? integer(String key) => (json[key] as num?)?.toInt();
    return TikTokUser(
      openId: string('open_id'),
      unionId: string('union_id'),
      avatarUrl: string('avatar_url'),
      avatarUrl100: string('avatar_url_100'),
      avatarLargeUrl: string('avatar_large_url'),
      displayName: string('display_name'),
      bioDescription: string('bio_description'),
      profileDeepLink: string('profile_deep_link'),
      isVerified: json['is_verified'] as bool?,
      username: string('username'),
      followerCount: integer('follower_count'),
      followingCount: integer('following_count'),
      likesCount: integer('likes_count'),
      videoCount: integer('video_count'),
      raw: Map.unmodifiable(json),
    );
  }

  /// See [TikTokUserField.openId].
  final String? openId;

  /// See [TikTokUserField.unionId].
  final String? unionId;

  /// See [TikTokUserField.avatarUrl].
  final String? avatarUrl;

  /// See [TikTokUserField.avatarUrl100].
  final String? avatarUrl100;

  /// See [TikTokUserField.avatarLargeUrl].
  final String? avatarLargeUrl;

  /// See [TikTokUserField.displayName].
  final String? displayName;

  /// See [TikTokUserField.bioDescription].
  final String? bioDescription;

  /// See [TikTokUserField.profileDeepLink].
  final String? profileDeepLink;

  /// See [TikTokUserField.isVerified].
  final bool? isVerified;

  /// See [TikTokUserField.username].
  final String? username;

  /// See [TikTokUserField.followerCount].
  final int? followerCount;

  /// See [TikTokUserField.followingCount].
  final int? followingCount;

  /// See [TikTokUserField.likesCount].
  final int? likesCount;

  /// See [TikTokUserField.videoCount].
  final int? videoCount;

  /// The unparsed `data.user` object, including fields added by TikTok later.
  final Map<String, Object?> raw;
}
