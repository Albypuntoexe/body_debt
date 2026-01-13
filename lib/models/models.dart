import 'package:flutter/foundation.dart';

// --- User Profile (Setup) ---
class UserProfile {
  final int age;
  final double weightKg;
  final double heightCm;
  final String gender; // 'M' or 'F'

  const UserProfile({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    this.gender = 'M',
  });

  // Calculate BMI automatically within the model logic
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  static const empty = UserProfile(age: 25, weightKg: 70, heightCm: 175);
}

// --- Daily Inputs (Sleep & Water) ---
class DailyInput {
  final double sleepHours;
  final double waterLiters;
  final double activityLevel; // 1.0 to 2.0 multiplier

  const DailyInput({
    this.sleepHours = 0,
    this.waterLiters = 0,
    this.activityLevel = 1.2,
  });

  DailyInput copyWith({double? sleepHours, double? waterLiters, double? activityLevel}) {
    return DailyInput(
      sleepHours: sleepHours ?? this.sleepHours,
      waterLiters: waterLiters ?? this.waterLiters,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }
}

// --- The Simulation Result (Output) ---
class SimulationResult {
  final int energyPercentage;    // 0-100%
  final double sleepDebtHours;   // Cumulative debt
  final double hydrationStatus;  // % of requirement
  final String predictionMessage; // "If you continue..."
  final bool isPrediction;       // true if this is a "What If" scenario

  const SimulationResult({
    required this.energyPercentage,
    required this.sleepDebtHours,
    required this.hydrationStatus,
    required this.predictionMessage,
    this.isPrediction = false,
  });

  static const initial = SimulationResult(
    energyPercentage: 100,
    sleepDebtHours: 0,
    hydrationStatus: 100,
    predictionMessage: "System balanced.",
  );
}