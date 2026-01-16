import 'dart:convert';
import 'package:flutter/material.dart'; // Per TimeOfDay

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
  bool get isSet => age > 0;

  Map<String, dynamic> toMap() => {'age': age, 'weightKg': weightKg, 'heightCm': heightCm, 'gender': gender};
  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    age: map['age'] ?? 25,
    weightKg: map['weightKg']?.toDouble() ?? 70.0,
    heightCm: map['heightCm']?.toDouble() ?? 175.0,
    gender: map['gender'] ?? 'M',
  );
  String toJson() => json.encode(toMap());
  factory UserProfile.fromJson(String source) => UserProfile.fromMap(json.decode(source));
}

class DailyInput {
  final double sleepHours;
  final double waterLiters;
  final double activityLevel;

  // NUOVI CAMPI PER ORARI PRECISI
  final String? wakeTimeStr; // Formato "HH:mm"
  final String? bedTimeStr;  // Formato "HH:mm"
  final bool usePreciseTiming; // Se false, usiamo solo sleepHours (slider)

  const DailyInput({
    this.sleepHours = 0,
    this.waterLiters = 0,
    this.activityLevel = 1.2,
    this.wakeTimeStr,
    this.bedTimeStr,
    this.usePreciseTiming = false,
  });

  DailyInput copyWith({
    double? sleepHours,
    double? waterLiters,
    double? activityLevel,
    String? wakeTimeStr,
    String? bedTimeStr,
    bool? usePreciseTiming,
  }) {
    return DailyInput(
      sleepHours: sleepHours ?? this.sleepHours,
      waterLiters: waterLiters ?? this.waterLiters,
      activityLevel: activityLevel ?? this.activityLevel,
      wakeTimeStr: wakeTimeStr ?? this.wakeTimeStr,
      bedTimeStr: bedTimeStr ?? this.bedTimeStr,
      usePreciseTiming: usePreciseTiming ?? this.usePreciseTiming,
    );
  }

  Map<String, dynamic> toMap() => {
    'sleepHours': sleepHours,
    'waterLiters': waterLiters,
    'activityLevel': activityLevel,
    'wakeTimeStr': wakeTimeStr,
    'bedTimeStr': bedTimeStr,
    'usePreciseTiming': usePreciseTiming,
  };

  factory DailyInput.fromMap(Map<String, dynamic> map) => DailyInput(
    sleepHours: map['sleepHours']?.toDouble() ?? 0.0,
    waterLiters: map['waterLiters']?.toDouble() ?? 0.0,
    activityLevel: map['activityLevel']?.toDouble() ?? 1.2,
    wakeTimeStr: map['wakeTimeStr'],
    bedTimeStr: map['bedTimeStr'],
    usePreciseTiming: map['usePreciseTiming'] ?? false,
  );
}

// Classe per i punti del grafico
class EnergyPoint {
  final DateTime time;
  final int energyLevel;
  final bool isPast;     // Se è passato (linea solida) o futuro (tratteggiata)
  final bool isWaterTime; // Se qui bisogna bere

  EnergyPoint({required this.time, required this.energyLevel, required this.isPast, this.isWaterTime = false});
}

class SimulationResult {
  final int energyPercentage;
  final double sleepDebtHours;
  final double hydrationStatus;
  final String predictionMessage;
  final bool isPrediction;
  final bool isDayStarted;
  final bool needsWaterNow;
  final bool showChart;

  // NUOVI CAMPI OUT
  final List<EnergyPoint> energyCurve; // La lista di punti per il grafico
  final String? suggestedBedTime;      // Suggerimento orario nanna

  const SimulationResult({
    required this.energyPercentage,
    required this.sleepDebtHours,
    required this.hydrationStatus,
    required this.predictionMessage,
    this.isPrediction = false,
    this.isDayStarted = false,
    this.needsWaterNow = false,
    this.showChart = true,
    this.energyCurve = const [],
    this.suggestedBedTime,
  });

  static const initial = SimulationResult(
    energyPercentage: 100,
    sleepDebtHours: 0,
    hydrationStatus: 100,
    predictionMessage: "Ready.",
    isDayStarted: false,
    needsWaterNow: false,
    showChart: true,
  );
}