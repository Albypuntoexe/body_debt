import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/preferences_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'repositories/simulation_repository.dart';
import 'view_models/simulation_view_model.dart';
import 'screens/dashboard_screen.dart';
import 'app/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final prefsService = PreferencesService(prefs);

  // 1. Setup Servizi
  final notificationService = NotificationService(prefsService);
  await notificationService.init(); // Chiede permessi UI

  final backgroundService = BackgroundService();
  await backgroundService.init(); // Inizializza WorkManager
  await backgroundService.registerPeriodicTask(); // Schedula il task ogni 15 min

  // 2. Repo
  final simRepo = SimulationRepository(prefsService);

  runApp(
    ChangeNotifierProvider(
      create: (_) => SimulationViewModel(simRepo, notificationService),
      child: const BodyDebtApp(),
    ),
  );
}

class BodyDebtApp extends StatelessWidget {
  const BodyDebtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BodyDebt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}