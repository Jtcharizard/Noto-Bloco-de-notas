import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Cada etapa da abertura tem limite de tempo: se uma falhar, o app abre mesmo assim.
Future<void> _safely(Future<void> Function() step) async {
  try {
    await step().timeout(const Duration(seconds: 5));
  } catch (_) {
    /* Segue sem essa etapa (ex.: notificações indisponíveis). */
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _safely(() => initializeDateFormatting('pt_BR'));
  await _safely(() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_localTimeZone());
  });
  await _safely(
    () => notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: handleNotificationResponse,
    ),
  );
  await _safely(() async {
    final launch = await notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final response = launch!.notificationResponse;
      final id = response?.payload;
      final action = response?.actionId;
      if (id != null && (action == 'adiar10' || action == 'adiar60')) {
        pendingSnooze = (id, action == 'adiar10' ? 10 : 60);
      } else {
        pendingNoteOpen = id;
      }
    }
  });
  // Créditos das ilustrações do tutorial em "Ver licenças".
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/onboarding/LICENSE-fluent-emoji.txt',
    );
    yield LicenseEntryWithLineBreaks(['Fluent Emoji (Microsoft)'], text);
  });
  runApp(const NotoApp());
}
