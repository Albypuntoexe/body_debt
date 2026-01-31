import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/simulation_repository.dart';
import '../services/notification_service.dart';

class SimulationViewModel extends ChangeNotifier {
  final SimulationRepository _repository;
  final NotificationService _notifications;

  UserProfile _userProfile = UserProfile.empty;
  DailyInput _currentInput = const DailyInput();
  SimulationResult _result = SimulationResult.initial;

  DateTime _selectedDate = DateTime.now();
  bool _isWhatIfMode = false;
  bool _isLoading = true;
  bool _morningCheckDone = false;

  Timer? _refreshTimer;
  DateTime _lastSystemCheck = DateTime.now();

  SimulationViewModel(this._repository, this._notifications) {
    _init();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (isSelectedDateToday && _result.isDayStarted && !_isWhatIfMode) {
        _calculate(save: false);
        if (_result.needsWaterNow && _notifications.areNotificationsEnabled) {
          _notifications.showHydrationReminder();
        }
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FIX: GESTIONE CAMBIO DATA (Time Travel Safe)
  // ════════════════════════════════════════════════════════════════════════════
  void refreshDataOnResume() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastCheckDay = DateTime(_lastSystemCheck.year, _lastSystemCheck.month, _lastSystemCheck.day);

    // Se la data del sistema è diversa dall'ultima volta che l'app era attiva
    bool dateChanged = today.isAfter(lastCheckDay) || today.isBefore(lastCheckDay);

    if (dateChanged) {
      print("📅 System Date Changed detected! Resetting to Today.");

      // 1. Aggiorna la data selezionata a OGGI
      _selectedDate = today;

      // 2. Resetta il flag del buongiorno (così te lo richiede)
      _morningCheckDone = false;

      // 3. Carica i dati REALI dal disco per oggi (che saranno vuoti se è un nuovo giorno)
      //    NON usare logiche di forecast qui.
      _currentInput = _repository.loadLogForDate(today);

      // 4. Se è un nuovo giorno vuoto, assicurati che sia davvero pulito
      if (_currentInput.sleepHours == 0 && !_currentInput.usePreciseTiming) {
        _currentInput = const DailyInput(); // Reset totale
      }

      _isWhatIfMode = false;
      _calculate(save: false);

    } else {
      // Se è lo stesso giorno, ricarica solo per sicurezza (sync background)
      if (isSelectedDateToday && !_isWhatIfMode) {
        _currentInput = _repository.loadLogForDate(_selectedDate);
        _calculate(save: false);
      }
    }
    _lastSystemCheck = now;
  }

  // ... Getters invariati ...
  SimulationResult get result => _result;
  DailyInput get input => _currentInput;
  UserProfile get userProfile => _userProfile;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isSetupRequired => !_userProfile.isSet;
  bool get areNotificationsEnabled => _notifications.areNotificationsEnabled;

  bool get isSelectedDateToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  bool get isFutureDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return sel.isAfter(today);
  }

  bool get isPastDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return sel.isBefore(today);
  }

  bool get shouldShowMorningPrompt {
    if (!isSelectedDateToday) return false;
    // Mostra solo se non abbiamo ancora fatto il check E non ci sono dati di sonno inseriti
    return !_morningCheckDone && _currentInput.sleepHours == 0;
  }

  Future<void> _init() async {
    _userProfile = _repository.loadProfile();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    // Caricamento iniziale
    _currentInput = _repository.loadLogForDate(_selectedDate);

    // Se trovo già dati (es. riapro l'app alle 14:00), non mostrare il prompt
    if (_currentInput.sleepHours > 0 || _currentInput.usePreciseTiming) {
      _morningCheckDone = true;
    }

    _calculate(save: false);
    _isLoading = false;
    notifyListeners();
  }

  Map<DateTime, int> getCalendarForecast(int daysAhead) {
    Map<DateTime, int> forecast = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int i = 1; i <= daysAhead; i++) {
      DateTime target = today.add(Duration(days: i));
      int energy = _repository.getProjectedWakeUpEnergy(_userProfile, target);
      forecast[target] = energy;
    }
    return forecast;
  }

  Future<void> toggleNotifications(bool value) async {
    await _notifications.toggleNotifications(value);
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _isWhatIfMode = false;

    if (isFutureDate) {
      // Forecast Mode: Usa default ottimistici per la visualizzazione
      _currentInput = const DailyInput(sleepHours: 8.0, waterLiters: 2.0, usePreciseTiming: true);
    } else {
      // History/Today Mode: Carica dati reali
      _currentInput = _repository.loadLogForDate(_selectedDate);
    }

    _calculate(save: false);
    notifyListeners();
  }

  Future<void> saveUserProfile(int age, double weight, double height, String gender) async {
    _userProfile = UserProfile(age: age, weightKg: weight, heightCm: height, gender: gender);
    await _repository.saveProfile(_userProfile);
    _calculate(save: false);
    notifyListeners();
  }

  void markMorningPromptSeen() { _morningCheckDone = true; notifyListeners(); }
  void answerMorningPrompt(double sleep) { updateInputs(sleep: sleep); commitData(); _morningCheckDone = true; }
  void addWaterGlass() { updateInputs(water: _currentInput.waterLiters + 0.2); commitData(); }
  void addNap(double hours) { updateInputs(sleep: _currentInput.sleepHours + hours); commitData(); }

  void setPreciseSleepTimes(TimeOfDay bedTime, TimeOfDay wakeTime) {
    String bedStr = "${bedTime.hour.toString().padLeft(2,'0')}:${bedTime.minute.toString().padLeft(2,'0')}";
    String wakeStr = "${wakeTime.hour.toString().padLeft(2,'0')}:${wakeTime.minute.toString().padLeft(2,'0')}";
    double bedDouble = bedTime.hour + bedTime.minute/60.0;
    double wakeDouble = wakeTime.hour + wakeTime.minute/60.0;
    double totalHours = (wakeDouble > bedDouble) ? wakeDouble - bedDouble : (24 - bedDouble) + wakeDouble;

    _currentInput = _currentInput.copyWith(bedTimeStr: bedStr, wakeTimeStr: wakeStr, sleepHours: totalHours, usePreciseTiming: true);
    _isWhatIfMode = true;
    _calculate(save: false);
    notifyListeners();
  }

  void togglePreciseMode(bool enable) {
    _currentInput = _currentInput.copyWith(usePreciseTiming: enable);
    _calculate(save: false);
    notifyListeners();
  }

  void updateInputs({double? sleep, double? water, double? activity}) {
    if (isFutureDate) return;
    _currentInput = _currentInput.copyWith(sleepHours: sleep, waterLiters: water, activityLevel: activity);
    _isWhatIfMode = true;
    _calculate(save: false);
    notifyListeners();
  }

  void _calculate({required bool save}) {
    _result = _repository.runSimulation(_userProfile, _currentInput, _selectedDate, isForecast: _isWhatIfMode);

    // FIX: Non salvare mai su disco se stiamo solo guardando il futuro
    if (save && !isFutureDate) {
      _repository.saveLogForDate(_selectedDate, _currentInput);
    }
    notifyListeners();
  }

  Future<void> commitData() async {
    if (isFutureDate) return;
    _isWhatIfMode = false;
    await _repository.saveLogForDate(_selectedDate, _currentInput);
    _calculate(save: true);
    notifyListeners();
  }

  Future<void> resetApp() async {
    await _repository.clearAllData();
    _isWhatIfMode = false; _morningCheckDone = false; _currentInput = const DailyInput(); _result = SimulationResult.initial; _userProfile = UserProfile.empty;
    await _init();
    notifyListeners();
  }
}