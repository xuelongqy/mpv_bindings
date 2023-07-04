part of mpv_bindings;

/// [mpv_event] callback.
/// Signature for [MpvClient._handleEvent].
typedef MpvEventCallback = void Function(Pointer<mpv_event> event);

/// [mpv_event_id.MPV_EVENT_PROPERTY_CHANGE] callback.
/// Signature for [MpvClient._onPropertyChange].
typedef MpvPropertyChangeCallback<T> = void Function(T? value);
