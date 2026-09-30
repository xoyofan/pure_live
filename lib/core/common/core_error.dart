/// HTTP error carried out of the parsing core. Localization of the status
/// text is a UI concern: hosts register [statusCodeFormatter] (the Flutter app
/// wires it to its i18n); without one the error renders the raw status.
class HttpError extends Error {
  /// Optional i18n hook, e.g. "HTTP 404" -> localized sentence.
  static String Function(int statusCode)? statusCodeFormatter;

  final int statusCode;
  final String message;

  /// What the server answered, when it was not a JSON API error.
  ///
  /// A rejected request (Douyu's edge answers 403 with a four-byte body) says
  /// nothing through the status code alone, and the body plus the request id is
  /// what makes such a failure diagnosable at all.
  final String? responseBody;

  /// Response headers worth keeping for diagnostics (`x-request-id`, rate limits).
  final Map<String, String> responseHeaders;

  HttpError(this.message, {this.statusCode = 0, this.responseBody, this.responseHeaders = const <String, String>{}});

  @override
  String toString() {
    if (statusCode != 0) {
      return statusCodeToString(statusCode);
    }
    return message;
  }

  String statusCodeToString(int statusCode) {
    final formatter = statusCodeFormatter;
    if (formatter != null) return formatter(statusCode);
    return message.isNotEmpty ? 'HTTP $statusCode: $message' : 'HTTP $statusCode';
  }
}
