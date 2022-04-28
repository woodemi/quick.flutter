import 'dart:convert';
import 'dart:ffi';

import 'package:libusb/libusb64.dart';

const int _kMaxSmi64 = (1 << 62) - 1;
const int _kMaxSmi32 = (1 << 30) - 1;
final int _maxSize = sizeOf<IntPtr>() == 8 ? _kMaxSmi64 : _kMaxSmi32;

extension LibusbExtension on Libusb {
  String describeError(int error) {
    var array = libusb_error_name(error);
    var nativeString = array.asTypedList(_maxSize);
    var strlen = nativeString.indexWhere((char) => char == 0);
    return utf8.decode(array.asTypedList(strlen));
  }
}
