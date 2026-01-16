import 'dart:convert';
import 'dart:math';
import '../models/models.dart';
import '../services/preferences_service.dart';

class SimulationRepository {
  final PreferencesService _service;
  static const _keyProfile = 'user_profile_data';
  static const _keyHistory = 'history_log_map';

  SimulationRepository(this._service);

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
  // CORREZIONE 2 & 3: LOGICA NEUTRALE / INERZIALE
  // ════════════════════════════════════════════════════════════════════════════

  /// Calcola l'energia prevista. "Neutrale" significa che il debito non scompare
  /// magicamente, ma nemmeno peggiora.
  int getProjectedWakeUpEnergy(UserProfile profile, DateTime targetDate) {
    if (!profile.isSet) return 100;

    final now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    if (targetDate.isBefore(today)) return 0; // Past

    double idealSleep = (profile.age > 60) ? 7.0 : 8.0;

    // Calcoliamo il debito REALE accumulato fino ad OGGI
    double currentRealDebt = _calculateDebtUntilToday(profile, today);

    // Per i giorni futuri, assumiamo uno scenario di MANTENIMENTO.
    // L'utente dorme il giusto (idealSleep) -> Il debito non aumenta, ma non diminuisce.
    // Rimane costante finché non esce dalla finestra dei 7 giorni.

    // Simuliamo la "rolling window" nel futuro
    double projectedDebt = 0.0;
    final history = _loadHistoryMap();

    for (int i = 7; i > 0; i--) {
      DateTime pastDate = targetDate.subtract(Duration(days: i));

      double slept;
      if (pastDate.isAfter(today)) {
        // Futuro: Assumiamo Maintenance (8h).
        // Questo è neutrale: non aggiunge debito, non recupera aggressivamente.
        slept = idealSleep;
      } else if (pastDate.isAtSameMomentAs(today)) {
        // Oggi: Se c'è log usiamo quello, altrimenti idealSleep (assunzione benevola per previsione)
        String key = _dateToKey(pastDate);
        slept = history.containsKey(key) ? DailyInput.fromMap(history[key]).sleepHours : idealSleep;
      } else {
        // Passato reale
        String key = _dateToKey(pastDate);
        slept = history.containsKey(key) ? DailyInput.fromMap(history[key]).sleepHours : idealSleep;
      }

      double diff = idealSleep - slept;
      if (diff > 0) {
        projectedDebt += diff; // Accumulo debito
      } else {
        projectedDebt += (diff * 0.5); // Recupero lento
      }
    }

    if (projectedDebt < 0) projectedDebt = 0;

    // Calcolo energia base
    double startEnergy = 100.0;
    startEnergy -= (projectedDebt * 5.0);

    return startEnergy.clamp(0, 100).toInt();
  }

  double _calculateDebtUntilToday(UserProfile profile, DateTime today) {
    double debt = 0;
    double idealSleep = (profile.age > 60) ? 7.0 : 8.0;
    final history = _loadHistoryMap();

    for (int i = 7; i > 0; i--) {
      DateTime d = today.subtract(Duration(days: i));
      String key = _dateToKey(d);
      double slept = history.containsKey(key) ? DailyInput.fromMap(history[key]).sleepHours : idealSleep;
      double diff = idealSleep - slept;
      debt += diff > 0 ? diff : (diff * 0.5);
    }
    return debt < 0 ? 0 : debt;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STANDARD SIMULATION (Invariata ma coerente)
  // ════════════════════════════════════════════════════════════════════════════

  SimulationResult runSimulation(UserProfile profile, DailyInput currentInput, DateTime targetDate, {bool isForecast = false}) {
    if (!profile.isSet) return SimulationResult.initial;

    final history = _loadHistoryMap();
    final now = DateTime.now();
    DateTime todayDate = DateTime(now.year, now.month, now.day);
    DateTime targetDateClean = DateTime(targetDate.year, targetDate.month, targetDate.day);

    bool isToday = targetDateClean.isAtSameMomentAs(todayDate);
    bool isFuture = targetDateClean.isAfter(todayDate);

    double idealSleep = (profile.age > 60) ? 7.0 : 8.0;

    // 1. DEBITO STORICO
    double cumulativeDebt = 0.0;
    if (history.isNotEmpty || isFuture) {
      for (int i = 3; i > 0; i--) {
        DateTime pastDate = targetDate.subtract(Duration(days: i));
        double slept;

        if (pastDate.isAfter(todayDate)) {
          slept = idealSleep; // Assunzione neutrale futura
        } else if (pastDate.isAtSameMomentAs(todayDate)) {
          // Se stiamo simulando domani, e guardiamo a ieri (che è oggi), usiamo l'input corrente
          // Ma attenzione: runSimulation viene chiamato ANCHE per oggi.
          // Se pastDate == todayDate, non dovremmo essere qui (il loop parte da ieri)
          // MA se targetDate è domani, pastDate=oggi. Quindi usiamo currentInput se disponibile
          // Altrimenti usiamo logica history.
          // Semplificazione: se è la data corrente di simulazione, usiamo input
          slept = idealSleep; // Fallback safe
        } else {
          String key = _dateToKey(pastDate);
          slept = history.containsKey(key) ? DailyInput.fromMap(history[key]).sleepHours : idealSleep;
        }

        double diff = idealSleep - slept;
        cumulativeDebt += diff > 0 ? diff : 0;
      }
    }

    // 2. TIMING
    double lastNightSleep = currentInput.sleepHours;
    DateTime wakeUpTime = DateTime(targetDate.year, targetDate.month, targetDate.day, 8, 0);
    bool usePrecise = currentInput.usePreciseTiming;

    if (isFuture) {
      lastNightSleep = idealSleep;
      wakeUpTime = DateTime(targetDate.year, targetDate.month, targetDate.day, 7, 30);
      usePrecise = true;
    } else if (usePrecise && currentInput.wakeTimeStr != null && currentInput.bedTimeStr != null) {
      try {
        int wakeH = int.parse(currentInput.wakeTimeStr!.split(":")[0]);
        int wakeM = int.parse(currentInput.wakeTimeStr!.split(":")[1]);
        int bedH = int.parse(currentInput.bedTimeStr!.split(":")[0]);
        int bedM = int.parse(currentInput.bedTimeStr!.split(":")[1]);
        wakeUpTime = DateTime(targetDate.year, targetDate.month, targetDate.day, wakeH, wakeM);

        double bedDouble = bedH + (bedM / 60.0);
        double wakeDouble = wakeH + (wakeM / 60.0);
        if (wakeDouble > bedDouble) lastNightSleep = wakeDouble - bedDouble;
        else lastNightSleep = (24.0 - bedDouble) + wakeDouble;
      } catch (e) {
        lastNightSleep = currentInput.sleepHours;
      }
    }

    // 3. STATO
    double hoursAwake = 0.0;
    if (isToday) {
      hoursAwake = now.difference(wakeUpTime).inMinutes / 60.0;
      if (hoursAwake < 0) hoursAwake = 0;
    } else if (isFuture) {
      hoursAwake = 0;
    }

    double waterNeed = (hoursAwake / 1.5) * 0.2;
    if (waterNeed < 0.2) waterNeed = 0.2;

    double waterInputForCalc = isFuture ? waterNeed : currentInput.waterLiters;

    double currentEnergy = _calculateEnergyAtMoment(
        cumulativeDebt, lastNightSleep, hoursAwake, waterInputForCalc, waterNeed, idealSleep, now.hour + (now.minute/60.0)
    );

    bool needsWaterNow = false;
    if (isToday && currentInput.waterLiters < waterNeed && (waterNeed - currentInput.waterLiters > 0.25)) {
      needsWaterNow = true;
    }

    // 4. CURVA
    List<EnergyPoint> curve = [];
    String? suggestedBedTime;

    if ((usePrecise && isToday) || isFuture) {
      DateTime iterator = wakeUpTime;
      DateTime endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
      int waterIntervalCounter = 0;

      while (iterator.isBefore(endOfDay)) {
        double iterHoursAwake = iterator.difference(wakeUpTime).inMinutes / 60.0;
        if (iterHoursAwake < 0) iterHoursAwake = 0;
        double iterWaterNeed = (iterHoursAwake / 1.5) * 0.2;

        double waterToUse = isFuture ? iterWaterNeed : currentInput.waterLiters;
        if (isToday && iterator.isAfter(now)) {
          waterToUse = currentInput.waterLiters;
        }

        double e = _calculateEnergyAtMoment(
            cumulativeDebt, lastNightSleep, iterHoursAwake, waterToUse, iterWaterNeed, idealSleep, iterator.hour + (iterator.minute/60.0)
        );

        bool isWaterTime = false;
        if (iterHoursAwake > 0 && iterHoursAwake % 1.5 < 0.5 && waterIntervalCounter > 2) {
          isWaterTime = true;
          waterIntervalCounter = 0;
        }
        waterIntervalCounter++;

        curve.add(EnergyPoint(
          time: iterator,
          energyLevel: e.toInt(),
          isPast: iterator.isBefore(now) && isToday,
          isWaterTime: isWaterTime,
        ));

        iterator = iterator.add(const Duration(minutes: 30));
      }

      suggestedBedTime = (cumulativeDebt > 2 || lastNightSleep < 6) ? "21:30" : "23:00";
    }

    String message = "Systems nominal.";
    if (isFuture) message = "Future projection (Status Quo).";
    else if (needsWaterNow) message = "Hydration low.";
    else if (currentEnergy < 30) message = "Energy critical.";

    DateTime todayStart = DateTime(now.year, now.month, now.day);
    bool isPast = targetDateClean.isBefore(todayStart);

    return SimulationResult(
      energyPercentage: currentEnergy.clamp(0, 100).toInt(),
      sleepDebtHours: cumulativeDebt,
      hydrationStatus: (currentInput.waterLiters / (waterNeed + 0.01) * 100).clamp(0, 100),
      predictionMessage: message,
      isPrediction: isForecast || isFuture,
      isDayStarted: currentInput.sleepHours > 0 || usePrecise || isFuture,
      needsWaterNow: needsWaterNow,
      showChart: (usePrecise && isToday) || isFuture,
      energyCurve: isPast ? [] : curve,
      suggestedBedTime: suggestedBedTime,
    );
  }

  double _calculateEnergyAtMoment(double histDebt, double lastSleep, double hAwake, double waterIn, double waterReq, double idealSleep, double clockHour) {
    double energy = 100.0;
    energy -= (histDebt * 5.0);
    if (lastSleep < idealSleep) energy -= (idealSleep - lastSleep) * 5.0;
    energy -= (hAwake * 3.5);
    double circ = sin(((clockHour - 10) * pi) / 12) * 10;

    double hydRatio = 1.0;
    if (waterIn < waterReq) {
      double def = waterReq - waterIn;
      if (def > 0.4) hydRatio = 0.85;
      else if (def > 0.1) hydRatio = 0.95;
    } else {
      hydRatio = 1.02;
    }

    double total = (energy + circ) * hydRatio;
    if (lastSleep >= 6 && waterIn >= 0.5 && hAwake < 4 && total < 60) total = 65;
    return total.clamp(0, 100);
  }
}