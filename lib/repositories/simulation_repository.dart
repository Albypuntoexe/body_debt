import 'dart:convert';
import 'dart:math'; // Necessario per il calcolo Circadiano
import '../models/models.dart';
import '../services/preferences_service.dart';

class SimulationRepository {
  final PreferencesService _service;

  static const _keyProfile = 'user_profile_data';
  static const _keyHistory = 'history_log_map';

  SimulationRepository(this._service);

  // --- Profile & History Loading ---
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
  // ALGORITMO BORBÉLY (Two-Process Model) + Hydration Physics
  // ════════════════════════════════════════════════════════════════════════════

  SimulationResult runSimulation(UserProfile profile, DailyInput currentInput, DateTime targetDate, {bool isForecast = false}) {
    if (!profile.isSet) return SimulationResult.initial;

    final history = _loadHistoryMap();
    final now = DateTime.now();
    bool isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;

    // Parametri Base
    double idealSleep = (profile.age > 60) ? 7.0 : 8.0;

    // -------------------------------------------------------------------------
    // 1. PROCESSO S (Homeostatic Sleep Pressure) - Il "Serbatoio"
    // -------------------------------------------------------------------------

    double homeostaticEnergy = 100.0;
    double cumulativeDebt = 0.0; // Definita qui come cumulativeDebt

    // Analizziamo gli ultimi 3 giorni (impatto maggiore)
    if (history.isNotEmpty) {
      for (int i = 3; i > 0; i--) {
        DateTime pastDate = targetDate.subtract(Duration(days: i));
        String key = _dateToKey(pastDate);

        double slept;
        if (history.containsKey(key)) {
          slept = DailyInput.fromMap(history[key]).sleepHours;
        } else {
          // Giorno mancante: Assumiamo media statistica (neutro)
          slept = idealSleep;
        }

        double diff = idealSleep - slept;
        cumulativeDebt += diff > 0 ? diff : 0;
      }

      // Penalità storica (max 5% per ora di debito)
      homeostaticEnergy -= (cumulativeDebt * 5.0);
    }

    // Applicazione del sonno della notte appena trascorsa
    double lastNightSleep = currentInput.sleepHours;

    if (lastNightSleep < idealSleep && lastNightSleep > 0) {
      // Penalità lineare per sonno insufficiente stanotte
      homeostaticEnergy -= (idealSleep - lastNightSleep) * 5.0;
    }

    // -------------------------------------------------------------------------
    // 2. WAKE DECAY (Il consumo durante il giorno)
    // -------------------------------------------------------------------------

    double hoursAwake = 0.0;
    if (isToday) {
      double currentHour = now.hour + (now.minute / 60.0);
      double wakeUpHour = 7.0; // Media statistica sveglia

      hoursAwake = currentHour - wakeUpHour;
      if (hoursAwake < 0) hoursAwake = 0;
    }

    // L'energia cala fisiologicamente circa 3.5% all'ora mentre sei sveglio
    double wakeDrain = hoursAwake * 3.5;
    homeostaticEnergy -= wakeDrain;

    // -------------------------------------------------------------------------
    // 3. PROCESSO C (Ritmo Circadiano)
    // -------------------------------------------------------------------------

    double circadianFactor = 0.0;
    if (isToday) {
      double hour = now.hour + (now.minute / 60.0);
      // Formula semplificata del ritmo circadiano (Seno spostato)
      circadianFactor = sin(((hour - 10) * pi) / 12) * 10;
    }

    // -------------------------------------------------------------------------
    // 4. IDRATAZIONE (Fattore Moltiplicativo)
    // -------------------------------------------------------------------------

    double waterNeed = (hoursAwake * 0.2);
    if (waterNeed < 0.2) waterNeed = 0.2;

    double hydrationRatio = 1.0;
    bool needsWaterNow = false;

    if (isToday) {
      if (currentInput.waterLiters < waterNeed) {
        double deficit = (waterNeed - currentInput.waterLiters);
        if (deficit > 0.4) {
          hydrationRatio = 0.85; // -15% Efficienza
          needsWaterNow = true;
        } else if (deficit > 0.2) {
          hydrationRatio = 0.95; // -5% Efficienza
        }
      }
    }

    // -------------------------------------------------------------------------
    // CALCOLO FINALE
    // -------------------------------------------------------------------------

    double totalEnergy = homeostaticEnergy + circadianFactor;
    totalEnergy = totalEnergy * hydrationRatio;

    // Safety check: Se ho dormito bene e bevuto, e sono le 10 di mattina, non posso essere morto.
    if (lastNightSleep >= 7 && currentInput.waterLiters >= 0.5 && hoursAwake < 4) {
      if (totalEnergy < 70) totalEnergy = 75;
    }

    String message = "Physiological state stable.";

    if (needsWaterNow) {
      message = "Cognitive efficiency dropped by 15% due to dehydration.";
    } else if (cumulativeDebt > 5) {
      message = "Adenosine levels high due to chronic sleep debt.";
    } else if (circadianFactor < -5 && isToday) {
      message = "Circadian dip detected (Afternoon slump).";
    } else if (circadianFactor > 5 && isToday) {
      message = "Circadian peak active. High alertness window.";
    } else if (totalEnergy < 20) {
      message = "Sleep pressure critical. Reaction times impaired.";
    }

    bool showEnergyChart = isToday;

    return SimulationResult(
      energyPercentage: totalEnergy.clamp(0, 100).toInt(),
      sleepDebtHours: cumulativeDebt, // FIX: Usiamo la variabile corretta
      hydrationStatus: (currentInput.waterLiters / (waterNeed + 0.1) * 100).clamp(0, 100),
      predictionMessage: message,
      isPrediction: isForecast,
      isDayStarted: currentInput.sleepHours > 0 || currentInput.waterLiters > 0,
      needsWaterNow: needsWaterNow,
      showChart: showEnergyChart,
    );
  }
}