import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadBytes(Uint8List bytes, String fileName, {String? fallbackUrl}) async {
  if (fallbackUrl != null) {
    final uri = Uri.parse(fallbackUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
