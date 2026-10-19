import 'package:http/http.dart' as http;
import 'qr_downloader_stub.dart'
    if (dart.library.html) 'qr_downloader_web.dart' as platform_downloader;

class QrDownloader {
  static Future<bool> downloadQrImage({
    required String qrUrl,
    required String fileName,
  }) async {
    try {
      final response = await http.get(Uri.parse(qrUrl));
      if (response.statusCode == 200) {
        await platform_downloader.downloadBytes(
          response.bodyBytes,
          fileName,
          fallbackUrl: qrUrl,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
