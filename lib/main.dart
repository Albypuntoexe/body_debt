import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/preferences_service.dart';
import 'services/notification_service.dart';
import 'repositories/simulation_repository.dart';
import 'view_models/simulation_view_model.dart';
import 'screens/dashboard_screen.dart';
import 'app/theme.dart';

void main() async {
  // Assicura che i binding nativi siano pronti prima di chiamare istanze asincrone
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Platform Layer
  final prefs = await SharedPreferences.getInstance();

  // 2. Service Layer
  final prefsService = PreferencesService(prefs);
  final notificationService = NotificationService(prefsService); // Nuovo servizio

  // 3. Repository Layer
  final simRepo = SimulationRepository(prefsService);

  // 4. App Launch
  runApp(
    ChangeNotifierProvider(
      // Iniettiamo entrambi i servizi nel ViewModel
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