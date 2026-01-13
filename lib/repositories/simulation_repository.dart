import 'dart:convert';
import '../models/models.dart';
import '../services/preferences_service.dart';

class SimulationRepository {
  final PreferencesService _service;

  static const _keyProfile = 'user_profile_data';
  static const _keyHistory = 'history_log_map';

  SimulationRepository(this._service);

  // --- Profile Management ---
  UserProfile loadProfile() {
    final jsonStr = _service.getString(_keyProfile);
    if (jsonStr == null) return UserProfile.empty;
    return UserProfile.fromJson(jsonStr);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _service.setString(_keyProfile, profile.toJson());
  }

  // --- History & Calendar Management ---

  /// Loads the specific log for a date. If none exists, returns default.
  DailyInput loadLogForDate(DateTime date) {
    final history = _loadHistoryMap();
    final key = _dateToKey(date);

    if (history.containsKey(key)) {
      return DailyInput.fromMap(history[key]);
    }
    return const DailyInput(); // Return empty/default if no data for that day
  }

  /// Saves the log for a specific date to disk
  Future<void> saveLogForDate(DateTime date, DailyInput input) async {
    final history = _loadHistoryMap();
    final key = _dateToKey(date);

    history[key] = input.toMap();

    // Convert entire map back to JSON and save
    await _service.setString(_keyHistory, json.encode(history));
  }

  /// Helper: Load full history from disk
  Map<String, dynamic> _loadHistoryMap() {
    final jsonStr = _service.getString(_keyHistory);
    if (jsonStr == null) return {};
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  /// Helper: Format Date key (YYYY-MM-DD) to ignore time
  String _dateToKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
  }

  SimulationResult runSimulation(UserProfile profile, DailyInput input, {bool isForecast = false}) {
    if (!profile.isSet) return SimulationResult.initial;

    // Se non ci sono dati, giorno non iniziato
    if (input.sleepHours == 0 && input.waterLiters == 0 && !isForecast) {
      return const SimulationResult(
        energyPercentage: 0,
        sleepDebtHours: 0,
        hydrationStatus: 0,
        predictionMessage: "Waiting for data...",
        isPrediction: false,
        isDayStarted: false,
      );
    }

    final now = DateTime.now();
    // Assumiamo sveglia alle 8:00 se non specificato (per semplicità)
    final wakeUpTime = DateTime(now.year, now.month, now.day, 8, 0);

    // Calcolo ore passate dalla sveglia (minimo 0)
    double hoursAwake = now.difference(wakeUpTime).inMinutes / 60.0;
    if (hoursAwake < 0) hoursAwake = 0; // Prima delle 8:00

    // --- 1. IDRATAZIONE TEMPORALE ---
    // Regola: 1 bicchiere (200ml) ogni 90 minuti (1.5 ore) è l'ideale.
    double idealWaterIntake = (hoursAwake / 1.5) * 0.2;
    if (idealWaterIntake < 0.2) idealWaterIntake = 0.2; // Almeno un bicchiere per iniziare

    // Deficit idrico attuale
    double waterDeficit = idealWaterIntake - input.waterLiters;
    bool needsWaterNow = waterDeficit > 0.15; // Se mancano quasi un bicchiere (150ml)

    // --- 2. DRAIN ENERGETICO ---
    double baseEnergy = 100.0;

    // Penalità Sonno (Start Level)
    double requiredSleep = (profile.age > 60) ? 7.0 : 8.0;
    if (input.sleepHours < requiredSleep) {
      baseEnergy -= (requiredSleep - input.sleepHours) * 10;
    }

    // Decay Rate (Scarica oraria)
    // Base: -4% energia all'ora.
    // Se disidratato: il decadimento accelera a -8% all'ora!
    double hourlyDecay = 4.0;
    if (needsWaterNow) {
      hourlyDecay = 8.0; // IL DOPPIO DELLA FATICA SE NON BEVI
    }

    double currentEnergy = baseEnergy - (hoursAwake * hourlyDecay);

    // Bonus parziali (Sonno extra recuperato o cibo) possono essere aggiunti qui
    // Clamp finale
    currentEnergy = currentEnergy.clamp(0.0, 100.0);

    // --- MESSAGGI ---
    String message = "Energy levels stable.";

    if (needsWaterNow) {
      message = "Hydration alert: You are lagging behind. Drink a glass now to stop the energy drain.";
    } else if (currentEnergy < 30) {
      message = "Battery Low. Mental focus is compromised.";
    } else if (hoursAwake > 14) {
      message = "End of day approaching. Wind down naturally.";
    } else if (input.sleepHours < requiredSleep) {
      message = "Running on caffeine and willpower due to sleep debt.";
    }

    return SimulationResult(
      energyPercentage: currentEnergy.toInt(),
      sleepDebtHours: (requiredSleep - input.sleepHours).clamp(0, 24),
      hydrationStatus: (input.waterLiters / (idealWaterIntake + 0.5)) * 100, // Status vs Ideal so far
      predictionMessage: message,
      isPrediction: isForecast,
      isDayStarted: true,
      needsWaterNow: needsWaterNow, // NUOVO CAMPO (vedi sotto)
    );
  }
  Future<void> clearAllData() async {
    await _service.clear();
  }
}