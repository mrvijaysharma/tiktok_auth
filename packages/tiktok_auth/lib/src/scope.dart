import 'package:flutter/foundation.dart';

/// A TikTok OAuth scope (permission) that an app can request.
///
/// Use the predefined constants for the scopes TikTok documents, or
/// [TikTokScope.custom] for scopes introduced after this package was
/// released. Instances are canonical: two scopes with the same [value] are
/// identical, so they work in `const` sets and as map keys.
///
/// Every scope other than [userInfoBasic] must be approved for your app in
/// the TikTok developer portal before users can grant it.
@immutable
final class TikTokScope {
  const TikTokScope._(this.value);

  /// Returns the scope named [value], for example `research.data.basic`.
  ///
  /// Throws an [ArgumentError] if [value] is empty or contains commas or
  /// whitespace.
  factory TikTokScope.custom(String value) {
    final name = value.trim();
    if (name.isEmpty || name.contains(',') || name.contains(RegExp(r'\s'))) {
      throw ArgumentError.value(
        value,
        'value',
        'A scope must be one non-empty token without commas or whitespace',
      );
    }
    return _known[name] ?? _custom.putIfAbsent(name, () => TikTokScope._(name));
  }

  /// Read a user's basic profile: open ID, union ID, avatar, display name.
  ///
  /// Available to every Login Kit app without extra review.
  static const userInfoBasic = TikTokScope._('user.info.basic');

  /// Read a user's extended profile: bio, profile link, verified status,
  /// username.
  static const userInfoProfile = TikTokScope._('user.info.profile');

  /// Read a user's statistics: follower, following, like and video counts.
  static const userInfoStats = TikTokScope._('user.info.stats');

  /// Read a user's public videos.
  static const videoList = TikTokScope._('video.list');

  /// Upload videos to a user's TikTok inbox as drafts.
  static const videoUpload = TikTokScope._('video.upload');

  /// Publish videos directly to a user's profile.
  static const videoPublish = TikTokScope._('video.publish');

  /// All scopes predefined by this package.
  static const List<TikTokScope> values = [
    userInfoBasic,
    userInfoProfile,
    userInfoStats,
    videoList,
    videoUpload,
    videoPublish,
  ];

  static final Map<String, TikTokScope> _known = {
    for (final scope in values) scope.value: scope,
  };

  static final Map<String, TikTokScope> _custom = {};

  /// The scope name TikTok uses, for example `user.info.basic`.
  final String value;

  @override
  String toString() => value;
}
