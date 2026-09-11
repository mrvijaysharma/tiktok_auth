// Configuration rules shared by `TikTokAuthConfig` and `tiktok_auth:doctor`.
//
// This file must not import Flutter: the doctor runs on the Dart VM.

/// The longest redirect URI TikTok accepts, exclusive.
const int maxRedirectUriLength = 512;

/// Returns the problems with [clientKey]. Empty if there are none.
List<String> clientKeyProblems(String clientKey) {
  if (clientKey.trim().isEmpty) {
    const problem =
        'clientKey is empty. Copy the client key of your app from the TikTok '
        'developer portal.';
    return [problem];
  }
  if (clientKey != clientKey.trim()) {
    return ['clientKey has leading or trailing whitespace.'];
  }
  return [];
}

/// Returns the problems with [redirectUri]. Empty if there are none.
List<String> redirectUriProblems(String redirectUri) {
  final problems = <String>[];
  final uri = Uri.tryParse(redirectUri);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    problems.add('redirectUri "$redirectUri" is not an absolute URL.');
  } else {
    if (uri.scheme != 'https') {
      problems.add(
        'redirectUri must use https. TikTok returns to your app through a '
        'Universal Link (iOS) / App Link (Android).',
      );
    }
    if (redirectUri.contains('#')) {
      problems.add('redirectUri must not contain a fragment (#).');
    }
    if (uri.hasQuery) {
      problems.add(
        'redirectUri must be static and must not contain query parameters.',
      );
    }
  }
  if (redirectUri.length >= maxRedirectUriLength) {
    problems.add(
      'redirectUri must be shorter than $maxRedirectUriLength characters.',
    );
  }
  return problems;
}
