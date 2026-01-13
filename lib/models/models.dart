import 'dart:convert';

// --- User Profile (Setup) ---
class UserProfile {
  final int age;
  final double weightKg;
  final double heightCm;
  final String gender;

  const UserProfile({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    this.gender = 'M',
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  static const empty = UserProfile(age: 0, weightKg: 0, heightCm: 0);
  bool get isSet => age > 0; // Check if user has completed setup

  // Serialization for Disk Storage
  Map<String, dynamic> toMap() {
    return {
      'age': age,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'gender': gender,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      age: map['age'] ?? 25,
      weightKg: map['weightKg']?.toDouble() ?? 70.0,
      heightCm: map['heightCm']?.toDouble() ?? 175.0,
      gender: map['gender'] ?? 'M',
    );
  }

  String toJson() => json.encode(toMap());
  factory UserProfile.fromJson(String source) => UserProfile.fromMap(json.decode(source));
}

// --- Daily Inputs (Sleep & Water) ---
class DailyInput {
  final double sleepHours;
  final double waterLiters;
  final double activityLevel;

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

  // Serialization
  Map<String, dynamic> toMap() {
    return {
      'sleepHours': sleepHours,
      'waterLiters': waterLiters,
      'activityLevel': activityLevel,
    };
  }

  factory DailyInput.fromMap(Map<String, dynamic> map) {
    return DailyInput(
      sleepHours: map['sleepHours']?.toDouble() ?? 0.0,
      waterLiters: map['waterLiters']?.toDouble() ?? 0.0,
      activityLevel: map['activityLevel']?.toDouble() ?? 1.2,
    );
  }
}

// --- Simulation Result ---
class SimulationResult {
  final int energyPercentage;
  final double sleepDebtHours;
  final double hydrationStatus;
  final String predictionMessage;
  final bool isPrediction;
  final bool isDayStarted; // NUOVO: true se abbiamo dati validi per oggi

  const SimulationResult({
    required this.energyPercentage,
    required this.sleepDebtHours,
    required this.hydrationStatus,
    required this.predictionMessage,
    this.isPrediction = false,
    this.isDayStarted = false,
  });

  static const initial = SimulationResult(
    energyPercentage: 100,
    sleepDebtHours: 0,
    hydrationStatus: 100,
    predictionMessage: "Ready to start.",
    isDayStarted: false,
  );
}