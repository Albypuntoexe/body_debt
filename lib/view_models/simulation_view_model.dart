import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/simulation_repository.dart';
import '../services/notification_service.dart';

class SimulationViewModel extends ChangeNotifier {
  final SimulationRepository _repository;
  final NotificationService _notifications;

  // State
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

  // Getters
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

  bool get shouldShowMorningPrompt {
    if (!isSelectedDateToday) return false;
    return !_morningCheckDone && !_result.isDayStarted;
  }

  // --- Initialization ---
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

  // --- Actions ---

  Future<void> toggleNotifications(bool value) async {
    await _notifications.toggleNotifications(value);
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _isWhatIfMode = false;
    _currentInput = _repository.loadLogForDate(_selectedDate);
    _calculate(save: false);
    notifyListeners();
  }

  Future<void> saveUserProfile(int age, double weight, double height, String gender) async {
    _userProfile = UserProfile(age: age, weightKg: weight, heightCm: height, gender: gender);
    await _repository.saveProfile(_userProfile);
    notifyListeners();
  }

  void markMorningPromptSeen() { _morningCheckDone = true; notifyListeners(); }

  void answerMorningPrompt(double sleep) {
    updateInputs(sleep: sleep);
    commitData();
    _morningCheckDone = true;
  }

  void addWaterGlass() {
    updateInputs(water: _currentInput.waterLiters + 0.2);
    commitData();
  }

  void addNap(double hours) {
    updateInputs(sleep: _currentInput.sleepHours + hours);
    commitData();
  }

  void updateInputs({double? sleep, double? water, double? activity}) {
    _currentInput = _currentInput.copyWith(
        sleepHours: sleep,
        waterLiters: water,
        activityLevel: activity
    );
    _isWhatIfMode = true;
    _calculate(save: false);
    notifyListeners();
  }

  void _calculate({required bool save}) {
    // Passiamo _selectedDate al repository per il calcolo storico
    _result = _repository.runSimulation(
        _userProfile,
        _currentInput,
        _selectedDate,
        isForecast: _isWhatIfMode
    );

    if (save) {
      _repository.saveLogForDate(_selectedDate, _currentInput);
    }
  }

  Future<void> commitData() async {
    _isWhatIfMode = false;
    await _repository.saveLogForDate(_selectedDate, _currentInput);
    _calculate(save: true);
    notifyListeners();
  }

  Future<void> resetApp() async {
    await _repository.clearAllData();
    _isWhatIfMode = false;
    _morningCheckDone = false;
    _currentInput = const DailyInput();
    _result = SimulationResult.initial;
    _userProfile = UserProfile.empty;
    await _init();
    notifyListeners();
  }
}