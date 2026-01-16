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

  // Helper Date
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
    return !_morningCheckDone && !_result.isDayStarted;
  }

  Future<void> _init() async {
    _userProfile = _repository.loadProfile();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentInput = _repository.loadLogForDate(_selectedDate);
    if (_currentInput.sleepHours > 0) _morningCheckDone = true;
    _calculate(save: false);
    _isLoading = false;
    notifyListeners();
  }

  // --- CALENDAR FORECAST HELPER ---
  // Ritorna l'energia prevista per i prossimi X giorni
  Map<DateTime, int> getCalendarForecast(int daysAhead) {
    Map<DateTime, int> forecast = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Inizia da domani
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
      // Se futuro, resetta input a default per mostrare la previsione pulita
      _currentInput = const DailyInput(sleepHours: 8.0, waterLiters: 2.0, usePreciseTiming: true);
    } else {
      _currentInput = _repository.loadLogForDate(_selectedDate);
    }

    _calculate(save: false);
    notifyListeners();
  }

  Future<void> saveUserProfile(int age, double weight, double height, String gender) async {
    _userProfile = UserProfile(age: age, weightKg: weight, heightCm: height, gender: gender);
    await _repository.saveProfile(_userProfile);
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
    if (isFutureDate) return; // Non modificare input futuri
    _currentInput = _currentInput.copyWith(sleepHours: sleep, waterLiters: water, activityLevel: activity);
    _isWhatIfMode = true;
    _calculate(save: false);
    notifyListeners();
  }

  void _calculate({required bool save}) {
    _result = _repository.runSimulation(_userProfile, _currentInput, _selectedDate, isForecast: _isWhatIfMode);
    if (save && !isFutureDate) { // Non salvare log futuri su disco
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