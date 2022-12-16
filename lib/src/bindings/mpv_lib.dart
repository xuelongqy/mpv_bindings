part of mpv_bindings;

/// Mpv library and bindings.
class MpvLib {
  /// Mpv bindings.
  static MpvBindings? _bindings;

  /// Get mpv bindings.
  static MpvBindings get bindings {
    _bindings ??= MpvBindings(_mpvLibrary);
    return _bindings!;
  }

  /// Set mpv bindings.
  static set bindings(MpvBindings value) {
    bindings = value;
  }

  /// Mpv library.
  static get _mpvLibrary {
    if (Platform.isWindows) {
      return DynamicLibrary.open('mpv-2.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libmpv.dylib');
    }
    return DynamicLibrary.open('libmpv.so');
  }
}
