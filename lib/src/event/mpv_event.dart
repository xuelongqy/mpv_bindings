part of mpv_bindings;

/// Signature for [MpvClient._onEvents].
typedef MpvEventCallback = void Function(Pointer<mpv_event> event);
