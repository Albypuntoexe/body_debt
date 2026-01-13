import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/preferences_service.dart';
import 'repositories/simulation_repository.dart';
import 'view_models/simulation_view_model.dart';
import 'screens/dashboard_screen.dart';
import 'app/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Platform
  final prefs = await SharedPreferences.getInstance();

  // 2. Service
  final prefsService = PreferencesService(prefs);

  // 3. Repository (The Brain)
  final simRepo = SimulationRepository(prefsService);

  runApp(
    // 4. ViewModel (Provider)
    ChangeNotifierProvider(
      create: (_) => SimulationViewModel(simRepo),
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
      theme: AppTheme.darkTheme, // Forced dark mode for simulation vibe
      home: const DashboardScreen(),
    );
  }
}