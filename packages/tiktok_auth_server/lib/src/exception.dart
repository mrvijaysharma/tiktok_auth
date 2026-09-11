/// Thrown when a TikTok API call fails.
class TikTokApiException implements Exception {
  /// Creates an exception.
  const TikTokApiException(
    this.error, {
    this.description,
    this.logId,
    this.statusCode,
  });

  /// TikTok's error code, for example `invalid_grant` or
  /// `access_token_invalid`.
  final String error;

  /// TikTok's human-readable description, if any.
  final String? description;

  /// TikTok's request log ID. Include it when contacting TikTok support.
  final String? logId;

  /// The HTTP status code of the response.
  final int? statusCode;

  @override
  String toString() {
    final buffer = StringBuffer('TikTokApiException($error)');
    if (description != null && description!.isNotEmpty) {
      buffer.write(': $description');
    }
    if (statusCode != null) buffer.write(' [HTTP $statusCode]');
    if (logId != null && logId!.isNotEmpty) buffer.write(' [log_id: $logId]');
    return buffer.toString();
  }
}
