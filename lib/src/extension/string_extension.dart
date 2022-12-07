import 'dart:ffi';

import 'package:ffi/ffi.dart';

extension StringExtension on String {
  Pointer<Char> toNativeChar({Allocator allocator = malloc}) {
    return toNativeUtf8(allocator: malloc).cast<Char>();
  }
}

extension PointerCharExtension on Pointer<Char> {
  String toDartString({int? length}) {
    return cast<Utf8>().toDartString(length: length);
  }
}
