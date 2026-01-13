import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/simulation_repository.dart';

class SimulationViewModel extends ChangeNotifier {
  final SimulationRepository _repository;

  // State
  UserProfile _userProfile = UserProfile.empty;
  DailyInput _currentInput = const DailyInput(); // The inputs (sliders)
  SimulationResult _result = SimulationResult.initial;

  bool _isWhatIfMode = false;

  SimulationViewModel(this._repository) {
    _init();
  }

  // Getters
  SimulationResult get result => _result;
  DailyInput get input => _currentInput;
  bool get isWhatIfMode => _isWhatIfMode;
  UserProfile get userProfile => _userProfile;

  void _init() {
    _userProfile = _repository.loadProfile();
    // Run initial simulation on defaults
    _calculate();
  }

  // --- Commands ---

  /// Updates inputs from UI (Sliders) and re-runs logic immediately
  void updateInputs({double? sleep, double? water}) {
    _currentInput = _currentInput.copyWith(
      sleepHours: sleep,
      waterLiters: water,
    );

    // Automatically triggers "What If" calculation
    _isWhatIfMode = true;
    _calculate();
  }

  /// The internal calculation call
  void _calculate() {
    // Pass isForecast: true because we are simulating the slider changes
    _result = _repository.runSimulation(_userProfile, _currentInput, isForecast: _isWhatIfMode);
    notifyListeners();
  }

  /// "Commit" the data (The user actually did this)
  Future<void> commitDay() async {
    await _repository.saveLog(_currentInput);
    _isWhatIfMode = false;
    // Re-run as "Real" reality
    _result = _repository.runSimulation(_userProfile, _currentInput, isForecast: false);
    notifyListeners();
  }
}