import 'dart:async';
import 'dart:io';

import 'package:panorama_backend/api.dart';
import 'package:panorama_backend/db.dart';
import 'package:panorama_backend/fcm.dart';
import 'package:panorama_backend/server_app.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final db = await Db.open();
  final fcm = await Fcm.tryLoad();
  final api = Api(db, fcm);

  // Стек middleware собирается в lib/server_app.dart — тем же кодом его
  // поднимают тесты, поэтому проверяется ровно то, что работает в бою.
  final handler = buildHandler(db, api: api);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Panorama API запущен на http://localhost:${server.port}/api/v1');

  // Проверка истечения броней раз в минуту (FR-11.2/11.3/11.4).
  Timer.periodic(const Duration(minutes: 1), (_) => api.runExpiryChecks());

  ProcessSignal.sigint.watch().listen((_) async {
    await db.close();
    exit(0);
  });
}
