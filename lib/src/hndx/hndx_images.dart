import 'dart:typed_data';
import '../utils.dart';
import 'package:image/image.dart';
import 'dart:io';

class HndxImgUtils {
  static const int HNDX_IMAGE_WIDTH = 200;
  static const int HNDX_IMAGE_HEIGHT = 126;

  // this is a straight up direct port of: https://bitbucket.org/fitpay/hndx-nrf/src/develop/hndx_gpx_tools/image_gen/image_gen.py
  static Uint8List convert(Uint8List imageBytes) {
    print('reading image');
    Image img = decodeImage(imageBytes);

    print('resize image');
    img = copyResize(img, height: HNDX_IMAGE_HEIGHT, width: HNDX_IMAGE_WIDTH);

    print('convert image to rgba');
    Uint8List rgba = img.getBytes(format: Format.rgba);

    bool transparency = false;
    int image_mode = 0x00;
    int image_version = 0x41;

    print('determine mode');
    int idx = 0;
    while (idx < rgba.length) {
      int r = rgba[idx++];
      int g = rgba[idx++];
      int b = rgba[idx++];
      int alpha = rgba[idx++];

      print('${r.toRadixString(16)}/${g.toRadixString(16)}/${b.toRadixString(16)}, a: ${alpha.toRadixString(16)}');
      if (alpha < 0xF0) {
        transparency = true;
        image_mode = 0x01;
        break;
      }
    }

    print('transparency: $transparency, mode: ${image_mode.toRadixString(16)}');

    BytesBuilder rle_array_a = BytesBuilder();
    BytesBuilder rle_array_b = BytesBuilder();

    int rle_leng = 0;
    int rle_color = 0;
    int image_index = 0;

    print('converting, length ${rgba.length}');
    idx = 0;
    if (!transparency) {
      while (idx < rgba.length) {
        int r = rgba[idx++];
        int g = rgba[idx++];
        int b = rgba[idx++];
        int alpha = rgba[idx++];

        int color = (((31 * (r + 4)) / 255).round() << 11) |
            (((63 * (g + 2)) / 255).round() << 5) |
            ((31 * (b + 4)) / 255).round();
        rle_array_b.add([color & 0xFF, (color >> 8) & 0xFF]);

        if (image_index == 0) {
          rle_color = color;
        } else {
          rle_leng++;
        }
        image_index++;

        if (rle_leng >= 0x100 || rle_color != color) {
          rle_array_a.add([rle_leng - 1, rle_color & 0xFF, (rle_color >> 8) & 0xFF]);

          rle_leng = 0;
          rle_color = color;
        }

        rle_array_a.add([rle_leng, rle_color & 0xFF, (rle_color >> 8) & 0xFF]);
      }
    } else {
      int rle_alpha = 0;

      while (idx < rgba.length) {
        int r = rgba[idx++];
        int g = rgba[idx++];
        int b = rgba[idx++];
        int alpha = rgba[idx++];

        // RGBA545
        int alpha_pak = (alpha * 225 + 4096) >> 13;
        int alpha_pak_split = (((alpha_pak & 0x04) << 9) | ((alpha_pak & 0x02) << 4) | (alpha_pak & 0x01));
        int color_pak = 0;
        if (alpha_pak > 0) {
          int red_b = ((r * 15 + 135) >> 8);
          int green_b = ((g * 249 + 1024) >> 11);
          int blue_b = ((b * 15 + 135) >> 8);
          color_pak = (red_b << 12) | (green_b << 6) | (blue_b << 1);
        }
        int ca_pak = color_pak | alpha_pak_split;
        rle_array_b.add([ca_pak & 0xFF, (ca_pak >> 8) & 0xFF]);

        // RGBA565
        int alpha_rle = (((15 * (alpha + 8)) / 255).round() & 0x0F);
        int color_rle = 0;
        if (alpha_rle > 0) {
          color_rle = (((31 * (r + 4)) / 255).round() << 11) |
              (((63 * (g + 2)) / 255).round() << 5) |
              ((31 * (b + 4)) / 255).round();
        }

        if (image_index == 0) {
          rle_alpha = alpha_rle;
          rle_color = color_rle;
        } else {
          rle_leng++;
        }

        if (rle_leng >= 16 || rle_alpha != alpha_rle || rle_color != color_rle) {
          rle_array_a.add([(((rle_leng - 1) << 4) + rle_alpha), rle_color & 0xFF, (rle_color >> 8) & 0xFF]);
          rle_leng = 0;
          rle_alpha = alpha;
          rle_color = color_rle;
        }

        image_index++;
        rle_array_a.add([((rle_leng << 4) + rle_alpha), rle_color & 0xFF, (rle_color >> 8) & 0xFF]);
      }
    }
    print('convert complete, ${rle_array_a.length}, ${rle_array_b.length}');

    if (rle_array_b.length < rle_array_a.length) {
      print('mode switch');
      image_mode |= 0x02;
      rle_array_a = rle_array_b;
    }

    if (rle_array_a.length > 0xFFFF) {
      print('image is to large!');
      return Uint8List(0);
    }

    Uint8List header = Uint8List.fromList([
      image_version,
      image_mode,
      img.width & 0xFF,
      (img.width >> 8) & 0xFF,
      img.height & 0xFF,
      (img.height >> 8) & 0xFF,
      rle_array_a.length & 0xFF,
      (rle_array_a.length >> 8) & 0xFF
    ]);

    print('header [${Utils.hexEncode(header)}]');

    BytesBuilder buf = new BytesBuilder();
    buf.add(header);
    buf.add(rle_array_a.toBytes());
    return buf.toBytes();
  }
}

// void main(List<String> args) {
//   // preview image
//   Uint8List beforePreview = File('image.bin').readAsBytesSync();
//   Image preview = Image.fromBytes(200, 126, beforePreview.sublist(8), format: Format.rgba);
// }
