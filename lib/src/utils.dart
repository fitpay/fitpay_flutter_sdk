import 'dart:typed_data';
import 'package:convert/convert.dart';

class Utils {
  static String hexEncode(Uint8List data) {
    return hex.encode(data ?? []);
  }

  static List<int> hexDecode(String data) {
    return hex.decode(data ?? '');
  }
}
