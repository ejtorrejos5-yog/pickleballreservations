import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple CORS proxy that forwards PayMongo API calls from Flutter web.
/// Flutter web cannot call api.paymongo.com directly due to browser CORS policy.
/// This proxy runs locally, forwards the requests, and adds CORS headers.

const _paymongoBase = 'https://api.paymongo.com';
const _proxyPort = 8085;

void main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _proxyPort);
  print('');
  print('╔════════════════════════════════════════════════════════════╗');
  print('║  PayMongo CORS Proxy running on http://localhost:$_proxyPort   ║');
  print('║  Forwarding requests to $_paymongoBase          ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');

  await for (final request in server) {
    _handleRequest(request);
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  // Add CORS headers to every response
  request.response.headers
    ..add('Access-Control-Allow-Origin', '*')
    ..add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
    ..add('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');

  // Handle preflight OPTIONS request
  if (request.method == 'OPTIONS') {
    request.response.statusCode = 200;
    await request.response.close();
    return;
  }

  final targetUrl = '$_paymongoBase${request.uri.path}';
  final timestamp = DateTime.now().toIso8601String().substring(11, 19);
  print('[$timestamp] ${request.method} ${request.uri.path} → $targetUrl');

  try {
    // Read the incoming request body
    final bodyBytes = await request.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );

    // Copy relevant headers from the browser request
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      // Only forward relevant headers, skip browser-specific ones
      if (lower == 'authorization' ||
          lower == 'content-type' ||
          lower == 'accept') {
        headers[name] = values.join(', ');
      }
    });

    // Forward to PayMongo
    http.Response response;
    if (request.method == 'POST') {
      response = await http.post(
        Uri.parse(targetUrl),
        headers: headers,
        body: bodyBytes,
      );
    } else {
      response = await http.get(
        Uri.parse(targetUrl),
        headers: headers,
      );
    }

    print('[$timestamp]   → ${response.statusCode} (${response.body.length} bytes)');

    // Send the response back with CORS headers
    request.response.statusCode = response.statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(response.body);
    await request.response.close();
  } catch (e) {
    print('[$timestamp]   → ERROR: $e');
    request.response.statusCode = 502;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': 'Proxy error: $e'}));
    await request.response.close();
  }
}
