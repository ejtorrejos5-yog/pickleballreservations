import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_dart_decoder/qr_code_dart_decoder.dart';

class QrDecodeResult {
  final bool userCanceled;
  final String? data;
  final String? error;

  const QrDecodeResult.canceled()
      : userCanceled = true,
        data = null,
        error = null;

  const QrDecodeResult.success(this.data)
      : userCanceled = false,
        error = null;

  const QrDecodeResult.notFound([this.error = 'No QR code could be found in the selected image.'])
      : userCanceled = false,
        data = null;

  bool get isSuccess => data != null && data!.isNotEmpty;
}

class QrImageDecoder {
  static final ImagePicker _picker = ImagePicker();

  /// Opens gallery/file selector to pick an image and decodes any QR code inside it.
  static Future<QrDecodeResult> pickAndDecode() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile == null) {
        return const QrDecodeResult.canceled();
      }

      final Uint8List bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) {
        return const QrDecodeResult.notFound('Selected image is empty.');
      }

      final decoder = QrCodeDartDecoder(
        formats: [
          BarcodeFormat.qrCode,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.code128,
        ],
      );

      final result = await decoder.decodeFile(bytes);
      if (result != null && result.text.isNotEmpty) {
        return QrDecodeResult.success(result.text.trim());
      }

      return const QrDecodeResult.notFound(
        'No valid QR code was detected in the selected image. Please make sure the QR code is clear and well-lit.',
      );
    } catch (e) {
      debugPrint('Error decoding QR from image: $e');
      return QrDecodeResult.notFound('Failed to read image: $e');
    }
  }
}
