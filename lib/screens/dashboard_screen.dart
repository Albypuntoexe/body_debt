import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';
import '../models/models.dart';
import 'setup_screen.dart';
import 'settings_screen.dart';

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
              // Semplice controllo data
              final now = DateTime.now();
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              return Text(isToday ? "BODY DEBT // LIVE" : "HISTORY LOG");
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
            // Se non c'è dato E non è iniziato il giorno
            final hasNoData = !res.isDayStarted && vm.input.sleepHours == 0;

            return Column(
              children: [
                // TOP SECTION
                Expanded(
                  flex: 4,
                  child: hasNoData
                      ? _buildEmptyState(context, vm)
                      : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Mostra il grafico SOLO se showChart è true (Oggi)
                        if (res.showChart)
                          _buildEnergyCard(context, res)
                        else
                          _buildHistoryModeBanner(context, vm), // Altrimenti Banner Storico

                        const SizedBox(height: 16),

                        // 2. Alert Idratazione (Solo Oggi)
                        if (res.needsWaterNow && vm.isSelectedDateToday)
                          _buildHydrationAlert(),

                        // 3. Insight Box
                        _buildPredictionBox(context, res),
                      ],
                    ),
                  ),
                ),

                // BOTTOM TABS (Sempre visibili per editing)
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

  // --- WIDGETS ---

  // Banner per quando siamo nel passato
  Widget _buildHistoryModeBanner(BuildContext context, SimulationViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.edit_calendar, size: 48, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 16),
          Text(
            "EDITING PAST RECORD: ${vm.selectedDate.day}/${vm.selectedDate.month}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Updating this data will recalculate your Cumulative Sleep Debt for today.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.2),
        border: Border.all(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: const [
          Icon(Icons.water_drop, color: Colors.blueAccent),
          SizedBox(width: 12),
          Expanded(
              child: Text(
                  "Drain Alert: Hydration needed immediately to stop energy loss.",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
              )
          ),
        ],
      ),
    );
  }

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
              vm.isSelectedDateToday ? "Good Morning" : "No Log Found",
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              vm.isSelectedDateToday
                  ? "Start your day by logging last night's rest."
                  : "No data for this day. Add sleep info below to fix your history.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
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
            divisions: 28,
            onChanged: (v) => vm.updateInputs(sleep: v),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text("Add 20min Nap (+0.3h)"),
            onPressed: () => vm.addNap(0.33),
          ),
          const Spacer(),
          if (!vm.result.isPrediction && vm.isSelectedDateToday)
            const Text("Data synced.", style: TextStyle(color: Colors.green))
          else
            ElevatedButton(
              onPressed: vm.commitData,
              child: Text(vm.isSelectedDateToday ? "Save Updates" : "Correct History"),
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
                  onTap: () {
                    vm.addWaterGlass();
                    _showRewardSnackBar(context, "Great job! +200ml added 💧");
                  }
              ),
              const SizedBox(width: 20),
              _WaterButton(
                  label: "+ Bottle (0.5L)",
                  icon: Icons.local_cafe,
                  onTap: () {
                    vm.updateInputs(water: vm.input.waterLiters + 0.5);
                    vm.commitData();
                    _showRewardSnackBar(context, "Hydration boost! +500ml added 🌊");
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

  // NUOVO METODO PER IL FEEDBACK
  void _showRewardSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Rimuove eventuali vecchie snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.green, // Colore positivo
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

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
            vm.markMorningPromptSeen();
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
            const Text("CURRENT ENERGY"),
            const SizedBox(height: 8),
            Text(
              "${res.energyPercentage}%",
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: statusColor,
              ),
            ),
            if (res.isPrediction)
              const Text("PREVIEW MODE", style: TextStyle(fontSize: 10, color: Colors.amber)),
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
          const Text("SYSTEM STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(res.predictionMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
          if (res.sleepDebtHours > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Accumulated Debt: ${res.sleepDebtHours.toStringAsFixed(1)}h",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            )
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Center(child: Text("BODY DEBT"))),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings & Reset"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
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