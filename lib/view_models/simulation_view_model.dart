import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/simulation_repository.dart';

class SimulationViewModel extends ChangeNotifier {
  final SimulationRepository _repository;

  // State
  UserProfile _userProfile = UserProfile.empty;
  DailyInput _currentInput = const DailyInput();
  SimulationResult _result = SimulationResult.initial;

  DateTime _selectedDate = DateTime.now();
  bool _isWhatIfMode = false; // "Simulation Mode"
  bool _isLoading = true;

  // Morning Check Logic
  bool _morningCheckDone = false;

  SimulationViewModel(this._repository) {
    _init();
  }

  // Getters
  SimulationResult get result => _result;
  DailyInput get input => _currentInput;
  UserProfile get userProfile => _userProfile;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isSetupRequired => !_userProfile.isSet;

  /// Helper: Check if the currently selected date in the dashboard is TODAY
  bool get isSelectedDateToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  /// Strict Logic for Morning Prompt:
  /// 1. Only if looking at TODAY
  /// 2. Only if prompt not already shown/skipped (_morningCheckDone)
  /// 3. Only if day hasn't started yet (no data logged)
  bool get shouldShowMorningPrompt {
    if (!isSelectedDateToday) return false;
    return !_morningCheckDone && !_result.isDayStarted;
  }

  Future<void> _init() async {
    _userProfile = _repository.loadProfile();
    // Normalize date to remove time part for accurate comparison
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    _currentInput = _repository.loadLogForDate(_selectedDate);

    // Check if we already have data for today to skip prompt
    if (_currentInput.sleepHours > 0) {
      _morningCheckDone = true;
    }

    _calculate(save: false);
    _isLoading = false;
    notifyListeners();
  }

  // --- Morning Prompt Logic ---
  void markMorningPromptSeen() {
    _morningCheckDone = true;
    notifyListeners();
  }

  void answerMorningPrompt(double sleepHours) {
    updateInputs(sleep: sleepHours);
    commitData(); // Auto-save
    _morningCheckDone = true;
  }

  // --- Incremental Actions ---

  void addWaterGlass() {
    // 1 Glass = 200ml = 0.2 Liters
    double newVal = _currentInput.waterLiters + 0.2;
    updateInputs(water: newVal);
    commitData();
  }

  void addNap(double hours) {
    double newVal = _currentInput.sleepHours + hours;
    updateInputs(sleep: newVal);
    commitData();
  }

  // --- Standard Methods ---

  Future<void> selectDate(DateTime date) async {
    // Normalize date (strip time)
    _selectedDate = DateTime(date.year, date.month, date.day);
    _isWhatIfMode = false;

    // If we switch to a past date, we don't want the prompt logic to interfere.
    // If we switch back to TODAY, the prompt might trigger if data is empty.

    _currentInput = _repository.loadLogForDate(_selectedDate);
    _calculate(save: false);
    notifyListeners();
  }

  Future<void> saveUserProfile(int age, double weight, double height, String gender) async {
    _userProfile = UserProfile(age: age, weightKg: weight, heightCm: height, gender: gender);
    await _repository.saveProfile(_userProfile);
    notifyListeners();
  }

  Future<void> resetApp() async {
    await _repository.clearAllData();
    _userProfile = UserProfile.empty;
    _currentInput = const DailyInput();
    _result = SimulationResult.initial;
    _morningCheckDone = false;
    notifyListeners();
  }

  void updateInputs({double? sleep, double? water, double? activity}) {
    _currentInput = _currentInput.copyWith(
      sleepHours: sleep,
      waterLiters: water,
      activityLevel: activity,
    );
    _isWhatIfMode = true;
    _calculate(save: false);
    notifyListeners();
  }

  void _calculate({required bool save}) {
    _result = _repository.runSimulation(
        _userProfile,
        _currentInput,
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
}