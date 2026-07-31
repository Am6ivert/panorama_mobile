import 'dart:io';

import 'package:panorama_backend/api.dart';
import 'package:panorama_backend/db.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final db = await Db.open();
  final api = Api(db);

  final handler = const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(logRequests())
      .addHandler(api.handler);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Panorama API запущен на http://localhost:${server.port}/api/v1');

  ProcessSignal.sigint.watch().listen((_) async {
    await db.close();
    exit(0);
  });
}

/// CORS — чтобы web-версия приложения могла обращаться к API.
Middleware _cors() => (Handler inner) => (Request req) async {
      const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
      };
      if (req.method == 'OPTIONS') return Response.ok('', headers: headers);
      final res = await inner(req);
      return res.change(headers: {...res.headers, ...headers});
    };
