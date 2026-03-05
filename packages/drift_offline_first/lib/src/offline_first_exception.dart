/// Wraps a remote provider exception as an offline-first exception.
///
/// Thrown when a [requireRemote] policy fails or when connectivity is required.
class OfflineFirstException implements Exception {
  /// The underlying exception from the remote provider.
  final Object originalException;

  const OfflineFirstException(this.originalException);

  @override
  String toString() => 'OfflineFirstException: $originalException';
}
