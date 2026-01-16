import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';
import '../models/models.dart';
import 'setup_screen.dart';
import 'settings_screen.dart';
import 'energy_chart_painter.dart';

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
      // Prompt opzionale
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsSetup = context.select<SimulationViewModel, bool>((vm) => vm.isSetupRequired);
    if (needsSetup) return const SetupScreen();

    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Parte dal tab centrale (Chart/Info)
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<SimulationViewModel>(
            builder: (context, vm, _) {
              final date = vm.selectedDate;
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

            return Column(
              children: [
                // 1. TOP STATS (SEMPRE VISIBILE)
                _buildTopStats(context, res, vm),

                // 2. TAB BAR
                Container(
                  color: Theme.of(context).cardColor,
                  child: const TabBar(
                    indicatorColor: Colors.cyanAccent,
                    labelColor: Colors.cyanAccent,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(icon: Icon(Icons.bed), text: "SLEEP"),
                      Tab(icon: Icon(Icons.show_chart), text: "CHART"),
                      Tab(icon: Icon(Icons.water_drop), text: "WATER"),
                    ],
                  ),
                ),

                // 3. CONTENUTO TAB
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSleepInputTab(context, vm),
                      _buildChartTab(context, vm, res),
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

  // --- TOP STATS HEADER (VISIBILE SEMPRE) ---
  Widget _buildTopStats(BuildContext context, SimulationResult res, SimulationViewModel vm) {
    Color energyColor = res.energyPercentage > 70 ? Colors.cyanAccent : (res.energyPercentage > 30 ? Colors.amber : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Energia Corrente
          Column(
            children: [
              const Text("CURRENT ENERGY", style: TextStyle(fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text("${res.energyPercentage}%", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: energyColor)),
            ],
          ),
          // Debito Accumulato
          Column(
            children: [
              const Text("SLEEP DEBT", style: TextStyle(fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text("${res.sleepDebtHours.toStringAsFixed(1)}h", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ],
          ),
          // Bedtime Suggerito (o Status se manca)
          Column(
            children: [
              Text(res.suggestedBedTime != null ? "SUGGESTED BED" : "STATUS", style: const TextStyle(fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(
                  res.suggestedBedTime ?? (res.needsWaterNow ? "DRINK!" : "OK"),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 0: SLEEP INPUTS ---
  Widget _buildSleepInputTab(BuildContext context, SimulationViewModel vm) {
    TimeOfDay wake = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay bed = const TimeOfDay(hour: 23, minute: 0);

    if (vm.input.wakeTimeStr != null) {
      wake = TimeOfDay(
          hour: int.parse(vm.input.wakeTimeStr!.split(":")[0]),
          minute: int.parse(vm.input.wakeTimeStr!.split(":")[1])
      );
    }
    if (vm.input.bedTimeStr != null) {
      bed = TimeOfDay(
          hour: int.parse(vm.input.bedTimeStr!.split(":")[0]),
          minute: int.parse(vm.input.bedTimeStr!.split(":")[1])
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("INPUT MODE", style: TextStyle(color: Colors.grey, fontSize: 12)),
          SwitchListTile(
            title: const Text("Precise Scheduling", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Enable to view Energy Chart"),
            value: vm.input.usePreciseTiming,
            activeColor: Colors.cyanAccent,
            onChanged: (val) => vm.togglePreciseMode(val),
          ),
          const Divider(),
          const SizedBox(height: 20),

          if (vm.input.usePreciseTiming) ...[
            _buildTimePickerRow(context, "Went to Bed (Yesterday)", bed, (t) {
              vm.setPreciseSleepTimes(t, wake);
            }),
            const SizedBox(height: 20),
            _buildTimePickerRow(context, "Woke Up (Today)", wake, (t) {
              vm.setPreciseSleepTimes(bed, t);
            }),
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  "Total Sleep: ${vm.input.sleepHours.toStringAsFixed(1)}h",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                ),
              ),
            ),
          ] else ...[
            const Center(child: Text("SIMPLE SLIDER MODE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 20),
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
              activeColor: Colors.cyanAccent,
              onChanged: (v) => vm.updateInputs(sleep: v),
            ),
          ],

          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: vm.commitData,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white
            ),
            child: const Text("SAVE SLEEP LOG"),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerRow(BuildContext context, String label, TimeOfDay time, Function(TimeOfDay) onSelect) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        OutlinedButton(
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) onSelect(t);
          },
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.cyanAccent)),
          child: Text(time.format(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        ),
      ],
    );
  }

  // --- TAB 1: CHART ---
  Widget _buildChartTab(BuildContext context, SimulationViewModel vm, SimulationResult res) {
    if (!vm.input.usePreciseTiming) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Chart Unavailable", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            const Text("Switch to 'Precise Scheduling' in the SLEEP tab\nto generate your daily energy curve.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => DefaultTabController.of(context).animateTo(0),
              child: const Text("Go to Sleep Tab"),
            )
          ],
        ),
      );
    }

    if (res.energyCurve.isEmpty) return const Center(child: Text("Calculating curve..."));

    return Column(
      children: [
        // Messaggio Insight
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(res.predictionMessage, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey), textAlign: TextAlign.center),
        ),

        // GRAFICO
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]
            ),
            child: CustomPaint(
              painter: EnergyChartPainter(
                  points: res.energyCurve,
                  now: DateTime.now(),
                  accentColor: Colors.cyanAccent
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // Legenda
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.circle, size: 8, color: Colors.cyanAccent), SizedBox(width: 4),
              Text("Past", style: TextStyle(fontSize: 10)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 8, color: Colors.grey), SizedBox(width: 4),
              Text("Forecast", style: TextStyle(fontSize: 10)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 8, color: Colors.blueAccent), SizedBox(width: 4),
              Text("Drink Time", style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 2: WATER ---
  Widget _buildWaterTab(BuildContext context, SimulationViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text("HYDRATION LEVEL", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  vm.input.waterLiters.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              const Text(" L", style: TextStyle(fontSize: 24, color: Colors.blueAccent)),
            ],
          ),
          const SizedBox(height: 30),
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
            activeColor: Colors.blueAccent,
            onChanged: (v) => vm.updateInputs(water: v),
          ),
        ],
      ),
    );
  }

  void _showRewardSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text(message, style: const TextStyle(fontWeight: FontWeight.bold))]),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Center(child: Text("BODY DEBT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)))),
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
    if (newDate != null) vm.selectDate(newDate);
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(16),
            color: Colors.blueAccent.withOpacity(0.1)
        ),
        child: Column(children: [Icon(icon, color: Colors.blueAccent, size: 40), const SizedBox(height: 12), Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))]),
      ),
    );
  }
}