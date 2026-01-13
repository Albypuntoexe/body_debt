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

  // --- REVISED SIMULATION LOGIC ---
  SimulationResult runSimulation(UserProfile profile, DailyInput input, {bool isForecast = false}) {
    if (!profile.isSet) return SimulationResult.initial;

    // Se l'utente non ha ancora inserito nulla (0 sonno, 0 acqua),
    // non mostriamo "Failure", ma uno stato di attesa.
    if (input.sleepHours == 0 && input.waterLiters == 0 && !isForecast) {
      return const SimulationResult(
        energyPercentage: 0,
        sleepDebtHours: 0,
        hydrationStatus: 0,
        predictionMessage: "Waiting for today's data...",
        isPrediction: false,
        isDayStarted: false, // NUOVO FLAG
      );
    }

    double requiredSleep = 8.0;
    if (profile.age > 60) requiredSleep = 7.0;

    double sleepDifference = input.sleepHours - requiredSleep;
    double debt = sleepDifference < 0 ? -sleepDifference : 0;

    // Water logic
    double baseWater = (profile.weightKg * 0.035);
    double activityWater = (input.activityLevel - 1.0) * 0.5;
    double requiredWater = baseWater + activityWater;
    double hydrationPct = (input.waterLiters / requiredWater).clamp(0.0, 1.0);

    // Energy Calc
    double energy = 100.0;

    // Penalties (Calibrated)
    if (input.sleepHours < requiredSleep) {
      // Penalty less harsh immediately, accumulating
      energy -= (requiredSleep - input.sleepHours) * 10;
    }
    if (hydrationPct < 0.9) {
      energy -= (1.0 - hydrationPct) * 25;
    }
    if (profile.bmi > 30) energy -= 5;

    // --- NEW EMPATHETIC MESSAGES ---
    String message = "All systems operational.";

    if (energy < 40) {
      message = "Your body is running on reserves. Prioritize rest tonight.";
    } else if (sleepDifference < -2) {
      message = "Sleep debt detected. A short nap could help restore focus.";
    } else if (hydrationPct < 0.5) {
      message = "Hydration is low. A glass of water now will prevent headaches later.";
    } else if (hydrationPct < 0.8) {
      message = "Good start, but keep sipping water to maintain peak energy.";
    } else if (isForecast) {
      message = "Projected impact of these choices.";
    }

    return SimulationResult(
      energyPercentage: energy.clamp(0, 100).toInt(),
      sleepDebtHours: debt,
      hydrationStatus: hydrationPct * 100,
      predictionMessage: message,
      isPrediction: isForecast,
      isDayStarted: true,
    );
  }

  // --- Reset ---
  Future<void> clearAllData() async {
    await _service.clear();
  }
}