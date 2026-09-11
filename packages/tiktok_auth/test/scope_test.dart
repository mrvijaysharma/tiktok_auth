import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/tiktok_auth.dart';

void main() {
  group('TikTokScope', () {
    test('predefined scopes use TikTok names', () {
      expect(TikTokScope.userInfoBasic.value, 'user.info.basic');
      expect(TikTokScope.userInfoProfile.value, 'user.info.profile');
      expect(TikTokScope.userInfoStats.value, 'user.info.stats');
      expect(TikTokScope.videoList.value, 'video.list');
      expect(TikTokScope.videoUpload.value, 'video.upload');
      expect(TikTokScope.videoPublish.value, 'video.publish');
      expect(TikTokScope.values, hasLength(6));
    });

    test('custom returns the canonical instance for known names', () {
      expect(
        identical(
          TikTokScope.custom('user.info.basic'),
          TikTokScope.userInfoBasic,
        ),
        isTrue,
      );
    });

    test('custom canonicalizes unknown names', () {
      final a = TikTokScope.custom('research.data.basic');
      final b = TikTokScope.custom(' research.data.basic ');
      expect(identical(a, b), isTrue);
      expect(a.value, 'research.data.basic');
      expect(a.toString(), 'research.data.basic');
    });

    test('custom rejects invalid names', () {
      expect(() => TikTokScope.custom(''), throwsArgumentError);
      expect(() => TikTokScope.custom('a,b'), throwsArgumentError);
      expect(() => TikTokScope.custom('a b'), throwsArgumentError);
    });

    test('works in const sets', () {
      const scopes = {TikTokScope.userInfoBasic, TikTokScope.videoList};
      expect(scopes.contains(TikTokScope.custom('video.list')), isTrue);
    });
  });
}
