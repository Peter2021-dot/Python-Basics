import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class ImageUtils {
  /// Compresses image bytes to a target size or quality.
  /// Works on Mobile and Web.
  static Future<Uint8List> compressImage(Uint8List bytes, {int quality = 70, int maxWidth = 1024}) async {
    try {
      // Decode the image
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      // Resize if too large
      img.Image resized = image;
      if (image.width > maxWidth) {
        resized = img.copyResize(image, width: maxWidth);
      }

      // Encode back to JPG with compression
      final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      
      debugPrint('Image compressed from ${bytes.length} to ${compressed.length} bytes');
      return compressed;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return bytes;
    }
  }
}
