import '../models/models.dart';
import '../services/preferences_service.dart';

class SimulationRepository {
  final PreferencesService _service;

  // Keys
  static const _keyWeight = 'user_weight';
  static const _keySleep = 'last_sleep';
  static const _keyWater = 'last_water';

  SimulationRepository(this._service);

  /// 1. Load User Data
  UserProfile loadProfile() {
    // In a real app, check if keys exist. Returning default for demo.
    return UserProfile(
      weightKg: _service.getDouble(_keyWeight) ?? 70,
      heightCm: 175,
      age: 25,
    );
  }

  /// 2. The CORE ENGINE: Calculates BodyDebt based on inputs
  /// This implements the "Causal" and "Predictive" logic.
  SimulationResult runSimulation(UserProfile profile, DailyInput input, {bool isForecast = false}) {

    // --- Logic 1: Sleep Debt ---
    // Rule: Need 8 hours. Every missing hour is 12.5% energy loss.
    // Recovery: You only recover 50% of surplus sleep.
    double requiredSleep = 8.0;
    double sleepDifference = input.sleepHours - requiredSleep;

    // Calculate simple accumulated debt (simplified for this specific day/scenario)
    double debt = sleepDifference < 0 ? -sleepDifference : 0;

    // --- Logic 2: Hydration ---
    // Rule: Base 2.5L + Activity.
    double requiredWater = 2.5 * input.activityLevel;
    double hydrationPct = (input.waterLiters / requiredWater).clamp(0.0, 1.0);

    // --- Logic 3: Energy Calculation ---
    // Start at 100%. Subtract penalties.
    double energy = 100.0;

    // Sleep Penalty
    if (input.sleepHours < requiredSleep) {
      energy -= (requiredSleep - input.sleepHours) * 10; // -10% per hour lost
    }

    // Dehydration Penalty (Exponential decay)
    if (hydrationPct < 0.8) {
      energy -= (1.0 - hydrationPct) * 40; // Severe penalty for dehydration
    }

    // --- Logic 4: Prediction String ---
    String message = "Stable.";
    if (energy < 50) {
      message = isForecast
          ? "CRITICAL: If you do this, tomorrow you will crash."
          : "System Failure imminent. Rest required.";
    } else if (input.waterLiters < 1.0) {
      message = "Warning: Dehydration will reduce cognitive function by -15%.";
    } else if (sleepDifference > 0) {
      message = "Recovering: Energy +${(sleepDifference * 5).toInt()}% restored.";
    }

    return SimulationResult(
      energyPercentage: energy.clamp(0, 100).toInt(),
      sleepDebtHours: debt,
      hydrationStatus: hydrationPct * 100,
      predictionMessage: message,
      isPrediction: isForecast,
    );
  }

  /// Save today's actual data
  Future<void> saveLog(DailyInput input) async {
    await _service.setDouble(_keySleep, input.sleepHours);
    await _service.setDouble(_keyWater, input.waterLiters);
  }
}