import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/simulation_repository.dart';
import 'preferences_service.dart';
import 'notification_service.dart';

const String taskName = "bodyDebtCheckTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("[BACKGROUND WORKER] 🕒 Sveglia automatica: Analisi parametri fisiologici...");

    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsService = PreferencesService(prefs);
      final repo = SimulationRepository(prefsService);
      final notifService = NotificationService(prefsService);

      // Init notifiche in background
      await notifService.initBackground();

      final profile = repo.loadProfile();
      if (!profile.isSet) {
        return Future.value(true);
      }

      final now = DateTime.now();
      final todayLog = repo.loadLogForDate(now);

      final result = repo.runSimulation(profile, todayLog, now, isForecast: false);

      if (notifService.areNotificationsEnabled) {
        if (result.needsWaterNow) {
          await notifService.showHydrationReminder(
            title: "Hydration Alert 💧",
            body: "Dehydration is accelerating fatigue (-15% efficiency). Drink now.",
          );
        } else if (result.energyPercentage < 20 && now.hour < 23 && now.hour > 7) {
          await notifService.showHydrationReminder(
            title: "Critical Energy ⚠️",
            body: "System at ${result.energyPercentage}%. Cognitive function limited. Rest required.",
          );
        }
      }

      print("[BACKGROUND] Check completato. Energy: ${result.energyPercentage}%");

    } catch (e) {
      print("[BACKGROUND ERROR] $e");
      return Future.value(false);
    }

    return Future.value(true);
  });
}

class BackgroundService {

  Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Metti FALSE quando rilasci l'app sullo store
    );
  }

  Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "body_debt_periodic_check",
      taskName,
      frequency: const Duration(minutes: 15),

      constraints: Constraints(
        // CORREZIONE 1: Rimosso NetworkType.not_required (è il default)
        requiresBatteryNotLow: false,
      ),

      // CORREZIONE 2: Usa ExistingPeriodicWorkPolicy invece di ExistingWorkPolicy
      // 'update' sostituisce il vecchio 'replace' per i task periodici
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  Future<void> cancelTasks() async {
    await Workmanager().cancelAll();
  }
}