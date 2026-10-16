import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'noto_app.dart';
import 'noto_store.dart';

/// Descobre o fuso do celular pelo deslocamento atual (sem depender de plugin).
/// Prefere São Paulo quando bate, para manter o comportamento de sempre no Brasil.
tz.Location _localTimeZone() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset.inMilliseconds;
  final preferred = tz.getLocation('America/Sao_Paulo');
  if (preferred.currentTimeZone.offset == offset) return preferred;
  tz.Location? match;
  for (final location in tz.timeZoneDatabase.locations.values) {
    final zone = location.currentTimeZone;
    if (zone.offset != offset) continue;
    match ??= location;
    if (zone.abbreviation == now.timeZoneName) return location;
  }
  return match ?? preferred;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  tzdata.initializeTimeZones();
  tz.setLocalLocation(_localTimeZone());
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  runApp(const NotoApp());
}
