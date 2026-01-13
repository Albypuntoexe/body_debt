import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';
import '../models/models.dart';
import 'setup_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMorningPrompt();
    });
  }

  void _checkMorningPrompt() {
    final vm = context.read<SimulationViewModel>();
    final hour = DateTime.now().hour;

    // Mostra il prompt SOLO se è OGGI, sono passate le 5 del mattino, e non è stato ancora mostrato
    if (vm.isSelectedDateToday && hour >= 5 && vm.shouldShowMorningPrompt) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildMorningDialog(ctx, vm),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsSetup = context.select<SimulationViewModel, bool>((vm) => vm.isSetupRequired);
    if (needsSetup) return const SetupScreen();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<SimulationViewModel>(
            builder: (context, vm, _) {
              final date = vm.selectedDate;
              final now = DateTime.now();
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              return Text(isToday ? "TODAY'S BALANCE" : "HISTORY: ${date.day}/${date.month}");
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
        // CORREZIONE QUI:
        // La struttura principale è SEMPRE la colonna con le Tab in basso.
        // Cambia solo il contenuto della metà superiore.
        body: Consumer<SimulationViewModel>(
          builder: (context, vm, _) {
            final res = vm.result;
            final hasNoData = !res.isDayStarted && vm.input.sleepHours == 0;

            return Column(
              children: [
                // --- TOP SECTION (Grafici O Empty State) ---
                Expanded(
                  flex: 4,
                  child: hasNoData
                      ? _buildEmptyState(context, vm) // Mostra messaggio se vuoto
                      : SingleChildScrollView(        // Mostra grafici se ci sono dati
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEnergyCard(context, res),
                        const SizedBox(height: 16),
                        _buildPredictionBox(context, res),
                      ],
                    ),
                  ),
                ),

                // --- BOTTOM SECTION (TABS - SEMPRE VISIBILI) ---
                const Divider(height: 1),
                Container(
                  color: Theme.of(context).cardColor,
                  child: const TabBar(
                    indicatorColor: Colors.blueAccent,
                    tabs: [
                      Tab(icon: Icon(Icons.bed), text: "SLEEP & NAPS"),
                      Tab(icon: Icon(Icons.water_drop), text: "HYDRATION"),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TabBarView(
                    children: [
                      _buildSleepTab(context, vm),
                      _buildWaterTab(context, vm),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS ESTRAIBILI ---

  // Nuovo Widget per gestire lo stato vuoto nella parte superiore
  Widget _buildEmptyState(BuildContext context, SimulationViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                vm.isSelectedDateToday ? Icons.wb_sunny_outlined : Icons.history_toggle_off,
                size: 64,
                color: Colors.grey
            ),
            const SizedBox(height: 16),
            Text(
              vm.isSelectedDateToday ? "Good Morning" : "No Data Recorded",
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              vm.isSelectedDateToday
                  ? "Start your day by logging last night's rest."
                  : "No logs found for this date. Use the Sleep tab below to add history.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // Mostra il pulsante rapido SOLO se è oggi, altrimenti usa le tab sotto
            if (vm.isSelectedDateToday)
              ElevatedButton(
                onPressed: () => _checkMorningPrompt(),
                child: const Text("Log Sleep Now"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepTab(BuildContext context, SimulationViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text("TOTAL SLEEP (HOURS)"),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  vm.input.sleepHours.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)
              ),
              const Text(" h", style: TextStyle(fontSize: 24)),
            ],
          ),
          Slider(
            value: vm.input.sleepHours,
            min: 0,
            max: 14,
            divisions: 28, // 0.5 steps
            label: vm.input.sleepHours.toString(),
            onChanged: (v) => vm.updateInputs(sleep: v),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text("Add 20min Nap (+0.3h)"),
            onPressed: () => vm.addNap(0.33),
          ),
          const Spacer(),
          // Mostra il tasto salva se siamo in modalità predizione O se stiamo modificando la storia
          if (!vm.result.isPrediction && vm.isSelectedDateToday)
            const Text("Data synced.", style: TextStyle(color: Colors.green))
          else
            ElevatedButton(
              onPressed: vm.commitData,
              child: Text(vm.isSelectedDateToday ? "Save Updates" : "Save History Log"),
            ),
        ],
      ),
    );
  }

  Widget _buildWaterTab(BuildContext context, SimulationViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text("HYDRATION LEVEL"),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  vm.input.waterLiters.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueAccent)
              ),
              const Text(" L", style: TextStyle(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WaterButton(
                  label: "+ Glass (200ml)",
                  icon: Icons.local_drink,
                  onTap: vm.addWaterGlass
              ),
              const SizedBox(width: 20),
              _WaterButton(
                  label: "+ Bottle (0.5L)",
                  icon: Icons.local_cafe,
                  onTap: () {
                    vm.updateInputs(water: vm.input.waterLiters + 0.5);
                    vm.commitData();
                  }
              ),
            ],
          ),
          const Spacer(),
          const Text("Manual Adjust:", style: TextStyle(fontSize: 10)),
          Slider(
            value: vm.input.waterLiters,
            max: 5.0,
            onChanged: (v) => vm.updateInputs(water: v),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS SECONDARI ---

  Widget _buildMorningDialog(BuildContext context, SimulationViewModel vm) {
    double tempSleep = 7.0;
    return AlertDialog(
      title: const Text("Good Morning! ☀️"),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How much did you sleep last night?"),
              const SizedBox(height: 20),
              Text("${tempSleep.toStringAsFixed(1)} hours", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Slider(
                value: tempSleep,
                min: 0,
                max: 12,
                divisions: 24,
                onChanged: (v) => setState(() => tempSleep = v),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            vm.markMorningPromptSeen(); // Skip
            Navigator.pop(context);
          },
          child: const Text("Skip"),
        ),
        FilledButton(
          onPressed: () {
            vm.answerMorningPrompt(tempSleep);
            Navigator.pop(context);
          },
          child: const Text("Save & Start Day"),
        ),
      ],
    );
  }

  Widget _buildEnergyCard(BuildContext context, SimulationResult res) {
    Color statusColor = res.energyPercentage > 70
        ? Colors.greenAccent
        : (res.energyPercentage > 40 ? Colors.amber : Colors.orangeAccent);

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
              const Text("PREVIEW MODE - TAP SAVE TO CONFIRM", style: TextStyle(fontSize: 10, color: Colors.amber)),
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
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("INSIGHT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(res.predictionMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
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
            title: const Text("Reset All Data"),
            onTap: () {
              Navigator.pop(context);
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
      lastDate: DateTime.now(),
    );
    if (newDate != null) {
      vm.selectDate(newDate);
    }
  }
}

class _WaterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _WaterButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.blueAccent.withOpacity(0.1),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}