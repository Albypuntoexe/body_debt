import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';
import '../models/models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BODY DEBT // SIMULATOR'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<SimulationViewModel>(
        builder: (context, vm, _) {
          final res = vm.result;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 1. Main Energy Gauge ---
                _buildEnergyCard(context, res),

                const SizedBox(height: 24),

                // --- 2. Prediction Box ---
                _buildPredictionBox(context, res),

                const SizedBox(height: 24),

                // --- 3. "What If" Controls (Input) ---
                Text("SIMULATION CONTROLS", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),

                _buildSlider(
                  context,
                  "Sleep (Hours)",
                  vm.input.sleepHours,
                  0, 12,
                      (val) => vm.updateInputs(sleep: val),
                ),

                _buildSlider(
                  context,
                  "Water (Liters)",
                  vm.input.waterLiters,
                  0, 5,
                      (val) => vm.updateInputs(water: val),
                ),

                const SizedBox(height: 20),

                // --- 4. Commit Button ---
                if (vm.isWhatIfMode)
                  ElevatedButton.icon(
                    onPressed: vm.commitDay,
                    icon: const Icon(Icons.check, color: Colors.black),
                    label: const Text("MAKE IT REAL (LOG TODAY)"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnergyCard(BuildContext context, SimulationResult res) {
    Color statusColor = res.energyPercentage > 70
        ? Theme.of(context).colorScheme.primary
        : (res.energyPercentage > 40 ? Colors.amber : Colors.red);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("PREDICTED ENERGY"),
            const SizedBox(height: 8),
            Text(
              "${res.energyPercentage}%",
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: statusColor,
              ),
            ),
            if (res.isPrediction)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(4)
                ),
                child: const Text("WHAT-IF SCENARIO ACTIVE", style: TextStyle(fontSize: 10)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionBox(BuildContext context, SimulationResult res) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(left: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("FUTURE OUTCOME", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(res.predictionMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text("Sleep Debt: ${res.sleepDebtHours.toStringAsFixed(1)}h"),
          Text("Hydration: ${res.hydrationStatus.toStringAsFixed(0)}%"),
        ],
      ),
    );
  }

  Widget _buildSlider(BuildContext context, String label, double value, double min, double max, Function(double) onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label),
                Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max * 2).toInt(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}