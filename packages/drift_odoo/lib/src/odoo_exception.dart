import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base exception for all Odoo API errors.
class OdooException implements Exception {
  /// The Odoo exception class name (e.g. `'odoo.exceptions.AccessError'`).
  final String name;

  /// Human-readable error message.
  final String message;

  /// HTTP status code of the response.
  final int statusCode;

  /// The raw HTTP response.
  final http.Response response;

  const OdooException({
    required this.name,
    required this.message,
    required this.statusCode,
    required this.response,
  });

  @override
  String toString() => 'OdooException($statusCode): [$name] $message';

  /// Parse an Odoo JSON-2 error response into the appropriate [OdooException] subtype.
  factory OdooException.fromResponse(http.Response response) {
    var name = 'OdooException';
    var message = response.body;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      name = body['name'] as String? ?? name;
      message = body['message'] as String? ?? message;
    } catch (_) {}

    final status = response.statusCode;
    if (status == 401) {
      return OdooUnauthorizedException(name: name, message: message, response: response);
    }
    if (status == 403) {
      return OdooAccessError(name: name, message: message, response: response);
    }
    if (status == 404) {
      return OdooNotFoundError(name: name, message: message, response: response);
    }
    if (status == 422) {
      return OdooValidationError(name: name, message: message, response: response);
    }

    return OdooException(name: name, message: message, statusCode: status, response: response);
  }
}

/// Thrown when the API key is missing or invalid (HTTP 401).
class OdooUnauthorizedException extends OdooException {
  const OdooUnauthorizedException({
    required super.name,
    required super.message,
    required super.response,
  }) : super(statusCode: 401);
}

/// Thrown when the user lacks access rights (HTTP 403).
class OdooAccessError extends OdooException {
  const OdooAccessError({
    required super.name,
    required super.message,
    required super.response,
  }) : super(statusCode: 403);
}

/// Thrown when the model or record is not found (HTTP 404).
class OdooNotFoundError extends OdooException {
  const OdooNotFoundError({
    required super.name,
    required super.message,
    required super.response,
  }) : super(statusCode: 404);
}

/// Thrown when a validation error occurs (HTTP 422).
class OdooValidationError extends OdooException {
  const OdooValidationError({
    required super.name,
    required super.message,
    required super.response,
  }) : super(statusCode: 422);
}
