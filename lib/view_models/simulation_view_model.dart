import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/simulation_repository.dart';

class SimulationViewModel extends ChangeNotifier {
  final SimulationRepository _repository;

  // State
  UserProfile _userProfile = UserProfile.empty;
  DailyInput _currentInput = const DailyInput();
  SimulationResult _result = SimulationResult.initial;

  // Logic State
  DateTime _selectedDate = DateTime.now();
  bool _isWhatIfMode = false;
  bool _isLoading = true;

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

  // --- Initialization ---
  Future<void> _init() async {
    _userProfile = _repository.loadProfile();
    // Load today's data by default
    _currentInput = _repository.loadLogForDate(_selectedDate);
    _calculate(save: false);
    _isLoading = false;
    notifyListeners();
  }

  // --- Setup / Onboarding ---
  Future<void> saveUserProfile(int age, double weight, double height, String gender) async {
    _userProfile = UserProfile(age: age, weightKg: weight, heightCm: height, gender: gender);
    await _repository.saveProfile(_userProfile);
    notifyListeners();
  }

  // --- Calendar Logic ---
  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    _isWhatIfMode = false; // Reset prediction mode when changing dates

    // Load data from disk for that specific day
    _currentInput = _repository.loadLogForDate(date);

    _calculate(save: false);
    notifyListeners();
  }

  // --- Input & Simulation ---
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
    // If we are just sliding sliders, it's a forecast.
    // If we loaded from disk, it's not a forecast.
    bool forecast = _isWhatIfMode;

    _result = _repository.runSimulation(_userProfile, _currentInput, isForecast: forecast);

    if (save) {
      // Actually save to disk
      _repository.saveLogForDate(_selectedDate, _currentInput);
    }
  }

  // --- Actions ---
  Future<void> commitData() async {
    _isWhatIfMode = false;
    // Save current input to the selected date
    await _repository.saveLogForDate(_selectedDate, _currentInput);

    // Re-run as "Real"
    _calculate(save: true);
    notifyListeners();
  }

  Future<void> resetApp() async {
    await _repository.clearAllData();
    _userProfile = UserProfile.empty;
    _currentInput = const DailyInput();
    _result = SimulationResult.initial;
    notifyListeners();
  }
}