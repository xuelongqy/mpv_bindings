part of mpv_bindings;

/// Generic data storage.
///
/// If mpv writes this struct (e.g. via mpv_get_property()), you must not change
/// the data. In some cases (mpv_get_property()), you have to free it with
/// mpv_free_node_contents(). If you fill this struct yourself, you're also
/// responsible for freeing it, and you must not call mpv_free_node_contents().
class MpvNode {
  /// Data type [mpv_node].
  static Pointer<mpv_node> toNode(dynamic data, [Pointer<mpv_node>? pointer]) {
    final u = malloc.call<UnnamedUnion1>();
    int? format;
    if (data is String) {
      u.ref.string = data.toNativeChar();
      format = mpv_format.MPV_FORMAT_STRING;
    } else if (data is bool) {
      u.ref.flag = data ? 1 : 0;
      format = mpv_format.MPV_FORMAT_FLAG;
    } else if (data is int) {
      u.ref.int64 = data;
      format = mpv_format.MPV_FORMAT_INT64;
    } else if (data is double) {
      u.ref.double_ = data;
      format = mpv_format.MPV_FORMAT_DOUBLE;
    } else if (data is List<int>) {
      final ba = malloc.call<mpv_byte_array>();
      final Pointer<Uint8> result = malloc.allocate<Uint8>(data.length + 1);
      final Uint8List nativeString = result.asTypedList(data.length + 1);
      nativeString.setAll(0, data);
      nativeString[data.length] = 0;
      ba.ref.data = result.cast();
      ba.ref.size = data.length;
      u.ref.ba = ba;
      format = mpv_format.MPV_FORMAT_BYTE_ARRAY;
    } else if (data is List) {
      u.ref.list = toNodeList(data);
      format = mpv_format.MPV_FORMAT_NODE_ARRAY;
    } else if (data is Map) {
      u.ref.list = toNodeMap(data);
      format = mpv_format.MPV_FORMAT_NODE_MAP;
    }
    if (format != null) {
      final node = pointer ?? malloc.call<mpv_node>();
      copyU(node.ref.u, u.ref);
      node.ref.format = format;
      return node;
    }
    malloc.free(u);
    return nullptr;
  }

  /// [mpv_node] to data.
  static T? toData<T>(Pointer<mpv_node> node) {
    final u = node.ref.u;
    int format = node.ref.format;
    if (format == mpv_format.MPV_FORMAT_STRING) {
      return u.string.toDartString() as T;
    } else if (format == mpv_format.MPV_FORMAT_FLAG) {
      return (u.flag == 1) as T;
    } else if (format == mpv_format.MPV_FORMAT_INT64) {
      return u.int64 as T;
    } else if (format == mpv_format.MPV_FORMAT_DOUBLE) {
      return u.double_ as T;
    } else if (format == mpv_format.MPV_FORMAT_BYTE_ARRAY) {
      final baRef = u.ba.ref;
      return baRef.data.cast<Int8>().asTypedList(baRef.size).toList() as T;
    } else if (format == mpv_format.MPV_FORMAT_NODE_ARRAY) {
      return toList(u.list) as T;
    } else if (format == mpv_format.MPV_FORMAT_NODE_MAP) {
      return toMap(u.list) as T;
    }
    return null;
  }

  /// Copy [mpv_node.u]
  static copyU(UnnamedUnion1 u1, UnnamedUnion1 u2) {
    u1.string = u2.string;
    u1.flag = u2.flag;
    u1.int64 = u2.int64;
    u1.double_ = u2.double_;
    u1.list = u2.list;
    u1.ba = u2.ba;
  }

  /// List to [mpv_node_list].
  static Pointer<mpv_node_list> toNodeList(List data) {
    final nodeList = malloc.call<mpv_node_list>();
    final values = malloc.call<mpv_node>(data.length);
    for (int i = 0; i < data.length; i++) {
      toNode(data[i], values.elementAt(i));
    }
    nodeList.ref.num = data.length;
    nodeList.ref.values = values;
    return nodeList;
  }

  /// Map to [mpv_node_list].
  static Pointer<mpv_node_list> toNodeMap(Map data) {
    final entries = data.entries.toList();
    final nodeList = malloc.call<mpv_node_list>();
    final values = malloc.call<mpv_node>(entries.length);
    final keys = malloc.call<Pointer<Char>>(entries.length);
    for (int i = 0; i < entries.length; i++) {
      toNode(entries[i].value, values.elementAt(i));
      keys[i] = entries[i].key.toString().toNativeChar();
    }
    nodeList.ref.num = entries.length;
    nodeList.ref.values = values;
    nodeList.ref.keys = keys;
    return nodeList;
  }

  /// [mpv_node_list] to List.
  static List toList(Pointer<mpv_node_list> nodeList) {
    final data = [];
    final num = nodeList.ref.num;
    final list = nodeList.ref.values;
    for (int i = 0; i < num; i++) {
      data.add(toData(list.elementAt(i)));
    }
    return data;
  }

  /// [mpv_node_list] to Map.
  static Map toMap(Pointer<mpv_node_list> nodeList) {
    List<MapEntry> entries = [];
    final num = nodeList.ref.num;
    final list = nodeList.ref.values;
    final keys = nodeList.ref.keys;
    for (int i = 0; i < num; i++) {
      entries.add(MapEntry(keys[i].toDartString(), toData(list.elementAt(i))));
    }
    return Map.fromEntries(entries);
  }
}
