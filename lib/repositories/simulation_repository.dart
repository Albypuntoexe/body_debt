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
  // ENGINE V8.0: Dynamic Update Fix
  // ════════════════════════════════════════════════════════════════════════════

  SimulationResult runSimulation(UserProfile profile, DailyInput currentInput, DateTime targetDate, {bool isForecast = false}) {
    if (!profile.isSet) return SimulationResult.initial;

    final history = _loadHistoryMap();
    final now = DateTime.now();
    bool isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
    double idealSleep = (profile.age > 60) ? 7.0 : 8.0;

    // 1. DEBITO STORICO
    double cumulativeDebt = 0.0;
    if (history.isNotEmpty) {
      for (int i = 3; i > 0; i--) {
        DateTime pastDate = targetDate.subtract(Duration(days: i));
        String key = _dateToKey(pastDate);
        double slept = history.containsKey(key) ? DailyInput.fromMap(history[key]).sleepHours : idealSleep;
        double diff = idealSleep - slept;
        cumulativeDebt += diff > 0 ? diff : 0;
      }
    }

    // 2. TIMING
    double lastNightSleep = currentInput.sleepHours;
    DateTime wakeUpTime = DateTime(targetDate.year, targetDate.month, targetDate.day, 8, 0);

    if (currentInput.usePreciseTiming && currentInput.wakeTimeStr != null && currentInput.bedTimeStr != null) {
      try {
        int wakeH = int.parse(currentInput.wakeTimeStr!.split(":")[0]);
        int wakeM = int.parse(currentInput.wakeTimeStr!.split(":")[1]);
        int bedH = int.parse(currentInput.bedTimeStr!.split(":")[0]);
        int bedM = int.parse(currentInput.bedTimeStr!.split(":")[1]);

        wakeUpTime = DateTime(targetDate.year, targetDate.month, targetDate.day, wakeH, wakeM);

        double bedDouble = bedH + (bedM / 60.0);
        double wakeDouble = wakeH + (wakeM / 60.0);

        if (wakeDouble > bedDouble) {
          lastNightSleep = wakeDouble - bedDouble;
        } else {
          lastNightSleep = (24.0 - bedDouble) + wakeDouble;
        }
      } catch (e) {
        // Fallback in caso di parse error
        lastNightSleep = currentInput.sleepHours;
      }
    }

    // 3. CALCOLO STATO ATTUALE
    double hoursAwake = 0.0;
    if (isToday) {
      hoursAwake = now.difference(wakeUpTime).inMinutes / 60.0;
      if (hoursAwake < 0) hoursAwake = 0;
    }

    double waterNeed = (hoursAwake / 1.5) * 0.2;
    if (waterNeed < 0.2) waterNeed = 0.2;

    // Calcoliamo l'energia corrente ANCHE se non c'è timing preciso (per la card header)
    double currentEnergy = _calculateEnergyAtMoment(
        cumulativeDebt, lastNightSleep, hoursAwake, currentInput.waterLiters, waterNeed, idealSleep, now.hour + (now.minute/60.0)
    );

    bool needsWaterNow = false;
    if (isToday && currentInput.waterLiters < waterNeed && (waterNeed - currentInput.waterLiters > 0.25)) {
      needsWaterNow = true;
    }

    // 4. GENERAZIONE CURVA (Solo se Precise Timing)
    List<EnergyPoint> curve = [];
    String? suggestedBedTime;

    if (currentInput.usePreciseTiming && isToday) {
      DateTime iterator = wakeUpTime;
      DateTime endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);

      int waterIntervalCounter = 0;

      while (iterator.isBefore(endOfDay)) {
        double iterHoursAwake = iterator.difference(wakeUpTime).inMinutes / 60.0;
        if (iterHoursAwake < 0) iterHoursAwake = 0;

        // Fabbisogno d'acqua a quell'ora specifica del grafico
        double iterWaterNeed = (iterHoursAwake / 1.5) * 0.2;

        // CRUCIALE: Per i punti futuri, usiamo l'acqua ATTUALE bevuta dall'utente.
        // Se l'utente ha appena bevuto 2L, currentInput.waterLiters è alto.
        // Questo farà sì che la curva futura si alzi perché il deficit diminuisce.
        double waterToUse = currentInput.waterLiters;

        // Se siamo nel passato profondo (es. grafico alle 10:00 e ora sono le 18:00),
        // idealmente dovremmo sapere quanto avevi bevuto alle 10:00. Non avendo storico orario,
        // approssimiamo dicendo: "Nel passato eri ideale, nel futuro dipendi da quanto hai bevuto oggi".
        if (iterator.isBefore(now.subtract(const Duration(minutes: 30)))) {
          waterToUse = iterWaterNeed; // Assumiamo passato ideale per pulizia grafico
        }

        double e = _calculateEnergyAtMoment(
            cumulativeDebt, lastNightSleep, iterHoursAwake, waterToUse, iterWaterNeed, idealSleep, iterator.hour + (iterator.minute/60.0)
        );

        bool isWaterTime = false;
        // Marker acqua ogni 90 min circa
        if (iterHoursAwake > 0 && iterHoursAwake % 1.5 < 0.5 && waterIntervalCounter > 2) {
          isWaterTime = true;
          waterIntervalCounter = 0;
        }
        waterIntervalCounter++;

        curve.add(EnergyPoint(
          time: iterator,
          energyLevel: e.toInt(),
          isPast: iterator.isBefore(now),
          isWaterTime: isWaterTime,
        ));

        iterator = iterator.add(const Duration(minutes: 30));
      }

      if (cumulativeDebt > 2 || lastNightSleep < 6) {
        suggestedBedTime = "21:30";
      } else {
        suggestedBedTime = "23:00";
      }
    }

    String message = "Systems nominal.";
    if (needsWaterNow) message = "Hydration low. Drink to boost chart.";
    else if (currentEnergy < 30) message = "Energy critical.";
    else if (cumulativeDebt > 5) message = "Recovery sleep needed.";

    return SimulationResult(
      energyPercentage: currentEnergy.clamp(0, 100).toInt(),
      sleepDebtHours: cumulativeDebt,
      hydrationStatus: (currentInput.waterLiters / (waterNeed + 0.01) * 100).clamp(0, 100),
      predictionMessage: message,
      isPrediction: isForecast,
      isDayStarted: currentInput.sleepHours > 0 || currentInput.usePreciseTiming,
      needsWaterNow: needsWaterNow,
      showChart: currentInput.usePreciseTiming,
      energyCurve: curve,
      suggestedBedTime: suggestedBedTime,
    );
  }

  double _calculateEnergyAtMoment(double histDebt, double lastSleep, double hAwake, double waterIn, double waterReq, double idealSleep, double clockHour) {
    double energy = 100.0;

    // 1. Debito
    energy -= (histDebt * 5.0);
    // 2. Stanotte
    if (lastSleep < idealSleep) energy -= (idealSleep - lastSleep) * 5.0;
    // 3. Wake Drain
    energy -= (hAwake * 3.5);
    // 4. Circadiano
    double circ = sin(((clockHour - 10) * pi) / 12) * 10;

    // 5. Idratazione
    double hydRatio = 1.0;
    if (waterIn < waterReq) {
      double def = waterReq - waterIn;
      if (def > 0.4) hydRatio = 0.85;
      else if (def > 0.1) hydRatio = 0.95;
    } else {
      // Piccolo bonus se idratato bene
      hydRatio = 1.02;
    }

    double total = (energy + circ) * hydRatio;

    // Safety Net
    if (lastSleep >= 6 && waterIn >= 0.5 && hAwake < 4 && total < 60) total = 65;

    return total.clamp(0, 100);
  }
}