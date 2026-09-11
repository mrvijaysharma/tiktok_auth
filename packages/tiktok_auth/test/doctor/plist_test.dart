import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/src/doctor/plist.dart';

void main() {
  test('parses an Info.plist', () {
    const source = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- <key>Commented</key><string>out</string> -->
	<key>TikTokClientKey</key>
	<string>awkey</string>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>tiktokopensdk</string>
		<string>snssdk1180</string>
	</array>
	<key>On</key>
	<true/>
	<key>Off</key>
	<false/>
	<key>Count</key>
	<integer>3</integer>
	<key>Ratio</key>
	<real>1.5</real>
	<key>Empty</key>
	<string></string>
	<key>Escaped</key>
	<string>a &amp; b &lt;c&gt;</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLSchemes</key>
			<array><string>awkey</string></array>
		</dict>
	</array>
	<key>EmptyArray</key>
	<array/>
</dict>
</plist>''';

    final plist = parsePlist(source)! as Map<String, Object?>;

    expect(plist.containsKey('Commented'), isFalse);
    expect(plist['TikTokClientKey'], 'awkey');
    expect(plist['LSApplicationQueriesSchemes'], [
      'tiktokopensdk',
      'snssdk1180',
    ]);
    expect(plist['On'], isTrue);
    expect(plist['Off'], isFalse);
    expect(plist['Count'], 3);
    expect(plist['Ratio'], 1.5);
    expect(plist['Empty'], '');
    expect(plist['Escaped'], 'a & b <c>');
    expect(plist['CFBundleURLTypes'], [
      {
        'CFBundleURLSchemes': ['awkey'],
      },
    ]);
    expect(plist['EmptyArray'], isEmpty);
  });

  test('parses an entitlements file', () {
    const source = '''
<plist version="1.0"><dict>
<key>com.apple.developer.associated-domains</key>
<array><string>applinks:example.com</string></array>
</dict></plist>''';
    expect(parsePlist(source), {
      'com.apple.developer.associated-domains': ['applinks:example.com'],
    });
  });

  test('rejects malformed input', () {
    expect(
      () => parsePlist('<plist><dict><key>a</key></plist>'),
      throwsFormatException,
    );
    expect(() => parsePlist('<plist><dict>'), throwsFormatException);
    expect(
      () => parsePlist('<plist><unknown/></plist>'),
      throwsFormatException,
    );
  });
}
