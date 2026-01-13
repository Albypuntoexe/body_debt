import 'dart:convert';
import '../models/models.dart';
import '../services/preferences_service.dart';

class SimulationRepository {
  final PreferencesService _service;

  // Storage Keys
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

  // --- Simulation Logic (The Math) ---
  SimulationResult runSimulation(UserProfile profile, DailyInput input, {bool isForecast = false}) {
    if (!profile.isSet) return SimulationResult.initial;

    double requiredSleep = 8.0;
    // Older people need slightly less sleep (simple logic for demo)
    if (profile.age > 60) requiredSleep = 7.0;

    double sleepDifference = input.sleepHours - requiredSleep;
    double debt = sleepDifference < 0 ? -sleepDifference : 0;

    // Hydration needs based on Weight and Activity
    // Formula: 35ml per kg + 500ml per activity level point over 1.0
    double baseWater = (profile.weightKg * 0.035);
    double activityWater = (input.activityLevel - 1.0) * 0.5;
    double requiredWater = baseWater + activityWater;

    double hydrationPct = (input.waterLiters / requiredWater).clamp(0.0, 1.0);

    // Energy Calculation
    double energy = 100.0;

    // Penalties
    if (input.sleepHours < requiredSleep) {
      energy -= (requiredSleep - input.sleepHours) * 12;
    }
    if (hydrationPct < 0.9) {
      energy -= (1.0 - hydrationPct) * 30;
    }

    // BMI Impact (Slight penalty if obese)
    if (profile.bmi > 30) energy -= 5;

    // Messages
    String message = "System Optimal.";
    if (energy < 40) message = "SYSTEM FAILURE IMMINENT.";
    else if (sleepDifference < -2) message = "Severe sleep deprivation detected.";
    else if (hydrationPct < 0.5) message = "Hydration critical. Cognitive decline expected.";
    else if (isForecast) message = "Projected outcome based on current settings.";

    return SimulationResult(
      energyPercentage: energy.clamp(0, 100).toInt(),
      sleepDebtHours: debt,
      hydrationStatus: hydrationPct * 100,
      predictionMessage: message,
      isPrediction: isForecast,
    );
  }

  // --- Reset ---
  Future<void> clearAllData() async {
    await _service.clear();
  }
}