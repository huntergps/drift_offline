import 'package:http/http.dart' as http;

/// Thrown when a REST operation returns a non-successful HTTP response.
class RestException implements Exception {
  /// The HTTP response that triggered this exception.
  final http.Response response;

  const RestException(this.response);

  @override
  String toString() =>
      'RestException: ${response.statusCode} ${response.reasonPhrase}\n${response.body}';
}
