import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';
import '../models/models.dart';
import 'setup_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Check if we need Setup
    final needsSetup = context.select<SimulationViewModel, bool>((vm) => vm.isSetupRequired);
    if (needsSetup) return const SetupScreen();

    return Scaffold(
      appBar: AppBar(
        title: Consumer<SimulationViewModel>(
          builder: (context, vm, _) {
            // Display Selected Date
            final date = vm.selectedDate;
            final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month;
            return Text(isToday ? "BODY DEBT // TODAY" : "LOG: ${date.day}/${date.month}");
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Consumer<SimulationViewModel>(
        builder: (context, vm, _) {
          final res = vm.result;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEnergyCard(context, res),
                const SizedBox(height: 24),
                _buildPredictionBox(context, res),
                const SizedBox(height: 24),

                Text("INPUTS FOR: ${vm.selectedDate.day}/${vm.selectedDate.month}",
                    style: Theme.of(context).textTheme.titleSmall),

                _buildSlider(context, "Sleep (Hours)", vm.input.sleepHours, 0, 14,
                        (v) => vm.updateInputs(sleep: v)),

                _buildSlider(context, "Water (Liters)", vm.input.waterLiters, 0, 6,
                        (v) => vm.updateInputs(water: v)),

                const SizedBox(height: 20),

                // Only show save button if changes are made or needed
                ElevatedButton.icon(
                  onPressed: vm.commitData,
                  icon: const Icon(Icons.save_alt, color: Colors.black),
                  label: const Text("COMMIT LOG TO DISK"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Center(child: Text("SETTINGS"))),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Factory Reset (Cancel All)"),
            onTap: () {
              Navigator.pop(context); // Close drawer
              context.read<SimulationViewModel>().resetApp();
            },
          )
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final vm = context.read<SimulationViewModel>();
    final newDate = await showDatePicker(
      context: context,
      initialDate: vm.selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(), // Cannot predict future inputs, only log past/present
    );
    if (newDate != null) {
      vm.selectDate(newDate);
    }
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
            const Text("BODY BATTERY"),
            Text("${res.energyPercentage}%",
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: statusColor)),
            Text(res.isPrediction ? "[ SIMULATION MODE ]" : "[ LOGGED DATA ]",
                style: const TextStyle(fontSize: 10, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionBox(BuildContext context, SimulationResult res) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(res.predictionMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text("Sleep Debt: ${res.sleepDebtHours.toStringAsFixed(1)}h"),
          Text("Hydration: ${res.hydrationStatus.toStringAsFixed(0)}%"),
        ],
      ),
    );
  }

  Widget _buildSlider(BuildContext context, String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text(value.toStringAsFixed(1))
        ]),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}