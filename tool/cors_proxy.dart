/// A lightweight CORS proxy for Flutter web development.
///
/// Forwards requests from the Flutter app (localhost) to the real API
/// server and adds CORS headers so the browser allows the response.
///
/// Usage:
///   dart run tool/cors_proxy.dart
///
/// Then point your Flutter app at http://localhost:9090 instead of
/// the real server URL.
import 'dart:io';

const _targetHost = 'blueultimate.learnonyx.com';
const _targetPort = 8022;
const _proxyPort = 9090;

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _proxyPort);
  print('CORS proxy listening on http://localhost:$_proxyPort');
  print('Forwarding to https://$_targetHost:$_targetPort');
  print('');

  await for (final request in server) {
    _handleRequest(request);
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  // CORS preflight
  if (request.method == 'OPTIONS') {
    _addCorsHeaders(request.response);
    request.response
      ..statusCode = HttpStatus.noContent
      ..close();
    return;
  }

  final targetUrl = Uri(
    scheme: 'https',
    host: _targetHost,
    port: _targetPort,
    path: request.uri.path,
    query: request.uri.hasQuery ? request.uri.query : null,
  );

  try {
    final client = HttpClient()
      ..badCertificateCallback = (_, __, ___) => true;

    final proxyReq = await client.openUrl(request.method, targetUrl);

    // Copy original headers (except host)
    request.headers.forEach((name, values) {
      if (name.toLowerCase() == 'host') return;
      for (final v in values) {
        proxyReq.headers.add(name, v);
      }
    });
    proxyReq.headers.set('host', '$_targetHost:$_targetPort');

    // Forward request body
    await for (final chunk in request) {
      proxyReq.add(chunk);
    }
    final proxyResp = await proxyReq.close();

    // Copy status + headers from the real server
    request.response.statusCode = proxyResp.statusCode;
    proxyResp.headers.forEach((name, values) {
      // Skip headers the proxy sets itself
      if (name.toLowerCase().startsWith('access-control-')) return;
      for (final v in values) {
        request.response.headers.add(name, v);
      }
    });

    _addCorsHeaders(request.response);

    await proxyResp.pipe(request.response);
    print('${request.method} ${request.uri.path} → ${proxyResp.statusCode}');
  } catch (e) {
    print('ERROR ${request.uri.path} → $e');
    request.response
      ..statusCode = HttpStatus.badGateway
      ..headers.contentType = ContentType.text
      ..write('Proxy error: $e')
      ..close();
  }
}

void _addCorsHeaders(HttpResponse response) {
  response.headers
    ..add('Access-Control-Allow-Origin', '*')
    ..add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
    ..add('Access-Control-Allow-Headers', '*')
    ..add('Access-Control-Expose-Headers', '*');
}
