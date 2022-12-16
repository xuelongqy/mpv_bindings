part of mpv_bindings;

class MpvException implements Exception {
  /// See [mpv_error].
  final int code;

  /// See [mpv_error_string].
  final String message;

  MpvException({required this.code, required this.message});

  @override
  String toString() {
    return "MpvException: $message";
  }
}
