part of mpv_bindings;

/// [mpv_node] extension.
extension MpvNodeExtension on Pointer<mpv_node> {
  /// [mpv_node] value.
  T? value<T>() => MpvNode.toData(this);
}

/// [mpv_event_property] extension.
extension MpvEventPropertyExtension on mpv_event_property {
  /// [mpv_event_property] value.
  T? value<T>() {
    if (data.address == 0) {
      return null;
    }
    if (format == mpv_format.MPV_FORMAT_STRING) {
      return data.cast<Char>().toDartString() as T;
    } else if (format == mpv_format.MPV_FORMAT_FLAG) {
      return (data.cast<Uint8>().value == 1) as T;
    } else if (format == mpv_format.MPV_FORMAT_INT64) {
      return data.cast<Int64>().value as T;
    } else if (format == mpv_format.MPV_FORMAT_DOUBLE) {
      return data.cast<Double>().value as T;
    } else if (format == mpv_format.MPV_FORMAT_BYTE_ARRAY) {
      final baRef = data.cast<mpv_byte_array>().ref;
      return baRef.data.cast<Int8>().asTypedList(baRef.size).toList() as T;
    } else if (format == mpv_format.MPV_FORMAT_NODE_ARRAY) {
      return MpvNode.toList(data.cast<mpv_node_list>()) as T;
    } else if (format == mpv_format.MPV_FORMAT_NODE_MAP) {
      return MpvNode.toMap(data.cast<mpv_node_list>()) as T;
    } else if (format == mpv_format.MPV_FORMAT_NODE) {
      return data.cast<mpv_node>().value<T>();
    }
    return null;
  }
}

/// [mpv_event_property] extension.
extension MpvEventPropertyPointerExtension on Pointer<mpv_event_property> {
  /// [mpv_event_property] value.
  T? value<T>() {
    if (address == 0) {
      return null;
    }
    return ref.value<T>();
  }
}
