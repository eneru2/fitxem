import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitxem/app.dart';
import 'package:fitxem/services/reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  if (notificationsSupported) {
    await container.read(reminderServiceProvider).initialize();
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const JustClockApp(),
    ),
  );
}
