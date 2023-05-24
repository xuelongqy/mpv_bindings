import 'dart:ffi';

import 'package:ffi/ffi.dart';

extension StringExtension on String {
  Pointer<Char> toNativeChar({Allocator allocator = malloc}) {
    return toNativeUtf8(allocator: malloc).cast<Char>();
  }
}

extension StringListExtension on List<String> {
  Pointer<Pointer<Char>> toNativeCharList({Allocator allocator = malloc}) {
    final argsPointer = malloc.call<Pointer<Char>>(length + 1);
    for (int i = 0; i < length; i++) {
      argsPointer[i] = this[i].toNativeChar();
    }
    argsPointer[length] = nullptr;
    return argsPointer;
  }
}

extension PointerCharExtension on Pointer<Char> {
  String? toDartString({int? length}) {
    if (this == nullptr) {
      return null;
    }
    return cast<Utf8>().toDartString(length: length);
  }
}
