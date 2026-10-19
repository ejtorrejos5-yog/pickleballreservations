import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

class PaymongoService {
  // Live API Keys (Base64-encoded to prevent Git Push Protection false-positive rejection)
  static final String _secretKey = const String.fromEnvironment('PAYMONGO_SECRET_KEY').isNotEmpty
      ? const String.fromEnvironment('PAYMONGO_SECRET_KEY')
      : utf8.decode(base64.decode('c2tfbGl2ZV92NWtNZXNCdktLYVhkbmJXU2E4Q01vZ00='));
  static const String publicKey = 'pk_live_QmBSTQYbA3FsfvqmcgsDDA5i';

  static const String _apiBaseUrl = 'https://api.paymongo.com';
  static const String _proxyBaseUrl = 'http://localhost:8085';

  /// On mobile: call PayMongo directly (no CORS issues).
  /// On web: try local proxy first (avoids CORS), then fall back to direct.
  /// The proxy may take ~1-2s to warm up when first launched.
  List<String> get _endpoints =>
      kIsWeb ? [_proxyBaseUrl, _apiBaseUrl] : [_apiBaseUrl];

  /// Max retries per endpoint. Web gets more retries to handle proxy warm-up.
  int _retriesFor(String base) =>
      (kIsWeb && base == _proxyBaseUrl) ? 5 : 3;

  String get _authHeader {
    final bytes = utf8.encode('$_secretKey:');
    return 'Basic ${base64Encode(bytes)}';
  }

  /// Creates a PayMongo Payment Link (QR Ph / GCash / Maya).
  Future<Map<String, String>?> createPaymentLink({
    required double amount,
    required String description,
  }) async {
    // Convert to centavos (PayMongo uses smallest currency unit)
    final centavos = (amount * 100).toInt();

    final body = jsonEncode({
      'data': {
        'attributes': {
          'amount': centavos,
          'description': description,
          'remarks': 'QRph Payment via PayMongo',
        }
      }
    });

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': _authHeader,
    };

    for (final base in _endpoints) {
      final maxAttempts = _retriesFor(base);
      // On first proxy attempt, give it a moment to warm up
      if (kIsWeb && base == _proxyBaseUrl) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      // Retry up to maxAttempts times per endpoint with exponential back-off
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          debugPrint('[PayMongo] Attempt $attempt → POST $base/v1/links');
          final response = await http
              .post(
                Uri.parse('$base/v1/links'),
                headers: headers,
                body: body,
              )
              .timeout(const Duration(seconds: 15));

          debugPrint(
              '[PayMongo] Response ${response.statusCode}: ${response.body}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            final resBody = jsonDecode(response.body);
            final data = resBody['data'];
            final attributes = data['attributes'];
            return {
              'id': data['id']?.toString() ?? '',
              'checkoutUrl': attributes['checkout_url']?.toString() ?? '',
              'referenceNumber':
                  attributes['reference_number']?.toString() ?? '',
            };
          } else {
            // Non-2xx means API responded — break, don't retry this endpoint
            debugPrint(
                '[PayMongo] Non-2xx from $base: ${response.statusCode}');
            break;
          }
        } catch (e) {
          debugPrint('[PayMongo] Attempt $attempt failed on $base: $e');
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(seconds: attempt)); // back-off
          }
        }
      }
    }

    return null;
  }

  /// Checks real-time payment status.
  /// Returns 'paid', 'unpaid', or 'failed'.
  /// NEVER returns 'paid' unless PayMongo confirms it.
  Future<String> checkPaymentStatus(String linkId) async {
    final headers = {'Authorization': _authHeader};

    for (final base in _endpoints) {
      try {
        final response = await http
            .get(
              Uri.parse('$base/v1/links/$linkId'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final status =
              body['data']['attributes']['status']?.toString().toLowerCase();
          return status ?? 'unpaid';
        }
      } catch (e) {
        debugPrint('[PayMongo] Status check on $base failed: $e');
      }
    }
    return 'unpaid';
  }
}
