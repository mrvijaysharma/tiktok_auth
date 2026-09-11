#
# CocoaPods spec for the iOS implementation of tiktok_auth.
# Swift Package Manager users get the same sources through Package.swift.
#
Pod::Spec.new do |s|
  s.name             = 'tiktok_auth_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of the tiktok_auth Flutter plugin.'
  s.description      = <<-DESC
Wraps the official TikTok OpenSDK Login Kit for the tiktok_auth Flutter plugin.
                       DESC
  s.homepage         = 'https://pub.dev/packages/tiktok_auth'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = 'The tiktok_auth authors'
  s.source           = { :path => '.' }
  s.source_files     = 'tiktok_auth_ios/Sources/tiktok_auth_ios/**/*.swift'
  s.resource_bundles = {
    'tiktok_auth_ios_privacy' => ['tiktok_auth_ios/Sources/tiktok_auth_ios/PrivacyInfo.xcprivacy']
  }

  s.dependency 'Flutter'
  s.dependency 'TikTokOpenSDKCore', '~> 2.5'
  s.dependency 'TikTokOpenAuthSDK', '~> 2.5'

  s.platform = :ios, '15.0'
  s.swift_version = '5.9'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
