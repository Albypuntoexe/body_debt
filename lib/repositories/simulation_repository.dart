import 'dart:convert';
import 'dart:math';
import '../models/models.dart';
import '../services/preferences_service.dart';

class SimulationRepository {
  final PreferencesService _service;

  static const _keyProfile = 'user_profile_data';
  static const _keyHistory = 'history_log_map';

  SimulationRepository(this._service);

  // --- Profile & History Loading (Standard) ---
  UserProfile loadProfile() {
    final jsonStr = _service.getString(_keyProfile);
    if (jsonStr == null) return UserProfile.empty;
    try { return UserProfile.fromJson(jsonStr); } catch (e) { return UserProfile.empty; }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _service.setString(_keyProfile, profile.toJson());
  }

  DailyInput loadLogForDate(DateTime date) {
    final history = _loadHistoryMap();
    final key = _dateToKey(date);
    if (history.containsKey(key)) {
      return DailyInput.fromMap(history[key]);
    }
    return const DailyInput();
  }

  Future<void> saveLogForDate(DateTime date, DailyInput input) async {
    final history = _loadHistoryMap();
    final key = _dateToKey(date);
    history[key] = input.toMap();
    await _service.setString(_keyHistory, json.encode(history));
  }

  Map<String, dynamic> _loadHistoryMap() {
    final jsonStr = _service.getString(_keyHistory);
    if (jsonStr == null) return {};
    try { return json.decode(jsonStr) as Map<String, dynamic>; } catch (e) { return {}; }
  }

  String _dateToKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
  }

  Future<void> clearAllData() async {
    await _service.clear();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ALGORITMO V6.0: Scientific Hydration Pacing & Positive Reinforcement
  // ════════════════════════════════════════════════════════════════════════════

  SimulationResult runSimulation(UserProfile profile, DailyInput currentInput, DateTime targetDate, {bool isForecast = false}) {
    if (!profile.isSet) return SimulationResult.initial;

    final history = _loadHistoryMap();
    final now = DateTime.now();
    bool isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;

    // Parametri Base
    double idealSleep = (profile.age > 60) ? 7.0 : 8.0;

    // 1. PROCESSO S (Homeostatic Sleep Pressure)
    double homeostaticEnergy = 100.0;
    double cumulativeDebt = 0.0;

    if (history.isNotEmpty) {
      for (int i = 3; i > 0; i--) {
        DateTime pastDate = targetDate.subtract(Duration(days: i));
        String key = _dateToKey(pastDate);
        double slept = history.containsKey(key) ? DailyInput.fromMap(history[key]).sleepHours : idealSleep;
        double diff = idealSleep - slept;
        cumulativeDebt += diff > 0 ? diff : 0;
      }
      homeostaticEnergy -= (cumulativeDebt * 5.0);
    }

    double lastNightSleep = currentInput.sleepHours;
    if (lastNightSleep < idealSleep && lastNightSleep > 0) {
      homeostaticEnergy -= (idealSleep - lastNightSleep) * 5.0;
    }

    // 2. WAKE DECAY (Ore di Veglia)
    double hoursAwake = 0.0;
    if (isToday) {
      double currentHour = now.hour + (now.minute / 60.0);
      double wakeUpHour = 7.5; // Assumiamo sveglia media 7:30 se non specificato
      hoursAwake = currentHour - wakeUpHour;
      if (hoursAwake < 0) hoursAwake = 0;
    }

    double wakeDrain = hoursAwake * 3.5;
    homeostaticEnergy -= wakeDrain;

    // 3. PROCESSO C (Ritmo Circadiano)
    double circadianFactor = 0.0;
    if (isToday) {
      double hour = now.hour + (now.minute / 60.0);
      circadianFactor = sin(((hour - 10) * pi) / 12) * 10;
    }

    // -------------------------------------------------------------------------
    // 4. FISICA DELL'IDRATAZIONE (Aggiornata per Pacing 90 min)
    // -------------------------------------------------------------------------
    // Regola: 1 bicchiere (0.2L) ogni 1.5 ore (90 min) di veglia.
    // Questo crea una curva di fabbisogno graduale.

    double waterNeed = (hoursAwake / 1.5) * 0.2;
    if (waterNeed < 0.2) waterNeed = 0.2; // Minimo 1 bicchiere al mattino

    double hydrationRatio = 1.0;
    bool needsWaterNow = false;
    bool isHydrationOptimal = false; // Nuovo flag per il premio

    if (isToday) {
      if (currentInput.waterLiters < waterNeed) {
        // Se sei indietro
        double deficit = (waterNeed - currentInput.waterLiters);
        // Alert scatta se mancano più di 250ml (più di un bicchiere)
        if (deficit > 0.25) {
          hydrationRatio = 0.85;
          needsWaterNow = true;
        } else if (deficit > 0.1) {
          hydrationRatio = 0.95;
        }
      } else {
        // Se sei in pari o sopra -> PREMIO
        isHydrationOptimal = true;
        // Piccolo bonus energetico (fittizio) per gratificazione
        hydrationRatio = 1.02;
      }
    }

    // -------------------------------------------------------------------------
    // CALCOLO FINALE
    // -------------------------------------------------------------------------

    double totalEnergy = (homeostaticEnergy + circadianFactor) * hydrationRatio;

    // Safety check
    if (lastNightSleep >= 7 && currentInput.waterLiters >= 0.5 && hoursAwake < 4) {
      if (totalEnergy < 75) totalEnergy = 75;
    }

    // --- Messaggi Empatici e Gratificanti ---
    String message = "Physiological state stable.";

    if (needsWaterNow) {
      message = "You're falling behind on hydration. Drink a glass now to recover focus.";
    } else if (isHydrationOptimal && isToday) {
      // MESSAGGIO DI PREMIO
      message = "Hydration optimal! Your brain is performing at peak efficiency.";
    } else if (cumulativeDebt > 5) {
      message = "Adenosine levels high. Prioritize sleep tonight.";
    } else if (circadianFactor < -5 && isToday) {
      message = "Afternoon dip detected. It's natural to feel slower now.";
    } else if (totalEnergy < 20) {
      message = "Energy critical. Rest required.";
    }

    bool showEnergyChart = isToday;

    return SimulationResult(
      energyPercentage: totalEnergy.clamp(0, 100).toInt(),
      sleepDebtHours: cumulativeDebt,
      hydrationStatus: (currentInput.waterLiters / (waterNeed + 0.01) * 100).clamp(0, 100),
      predictionMessage: message,
      isPrediction: isForecast,
      isDayStarted: currentInput.sleepHours > 0 || currentInput.waterLiters > 0,
      needsWaterNow: needsWaterNow,
      showChart: showEnergyChart,
    );
  }
}