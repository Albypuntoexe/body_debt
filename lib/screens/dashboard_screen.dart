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

    final isFuture = context.select<SimulationViewModel, bool>((vm) => vm.isFutureDate);
    final isPast = context.select<SimulationViewModel, bool>((vm) => vm.isPastDate);

    return DefaultTabController(
      length: 3,
      initialIndex: isFuture ? 1 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<SimulationViewModel>(
            builder: (context, vm, _) {
              final date = vm.selectedDate;
              final now = DateTime.now();
              if (vm.isFutureDate) return Text("FORECAST: ${date.day}/${date.month}");
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              return Text(isToday ? "BODY DEBT // LIVE" : "HISTORY: ${date.day}/${date.month}");
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.cyanAccent),
              onPressed: () => _openForecastCalendar(context),
            ),
          ],
        ),
        drawer: _buildDrawer(context),
        body: Consumer<SimulationViewModel>(
          builder: (context, vm, _) {
            final res = vm.result;

            return Column(
              children: [
                _buildTopStats(context, res, vm),

                Container(
                  color: Theme.of(context).cardColor,
                  child: TabBar(
                    indicatorColor: Colors.cyanAccent,
                    labelColor: Colors.cyanAccent,
                    unselectedLabelColor: Colors.grey,
                    onTap: (index) {
                      if (isPast && index == 1) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chart not available for past logs"), duration: Duration(seconds: 1)));
                      }
                    },
                    tabs: [
                      const Tab(icon: Icon(Icons.bed), text: "SLEEP"),
                      Tab(icon: Icon(isPast ? Icons.visibility_off : Icons.show_chart), text: "CHART"),
                      const Tab(icon: Icon(Icons.water_drop), text: "WATER"),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    physics: isFuture ? const NeverScrollableScrollPhysics() : null,
                    children: [
                      isFuture
                          ? _buildLockedTab("Sleep inputs are locked in forecast mode.")
                          : _buildSleepInputTab(context, vm),

                      isPast
                          ? _buildLockedTab("Energy Chart is not available for past days.")
                          : _buildChartTab(context, vm, res),

                      isFuture
                          ? _buildLockedTab("Water logging locked in forecast mode.")
                          : _buildWaterTab(context, vm),
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

  void _openForecastCalendar(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForecastCalendarScreen()));
  }

  Widget _buildLockedTab(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTopStats(BuildContext context, SimulationResult res, SimulationViewModel vm) {
    Color energyColor = res.energyPercentage > 70 ? Colors.cyanAccent : (res.energyPercentage > 30 ? Colors.amber : Colors.redAccent);
    bool isFuture = vm.isFutureDate;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(isFuture ? "PREDICTED WAKE" : "CURRENT ENERGY", style: const TextStyle(fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text("${res.energyPercentage}%", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: energyColor)),
            ],
          ),
          Column(
            children: [
              const Text("SLEEP DEBT", style: TextStyle(fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text("${res.sleepDebtHours.toStringAsFixed(1)}h", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepInputTab(BuildContext context, SimulationViewModel vm) {
    TimeOfDay wake = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay bed = const TimeOfDay(hour: 23, minute: 0);
    if (vm.input.wakeTimeStr != null) {
      wake = TimeOfDay(hour: int.parse(vm.input.wakeTimeStr!.split(":")[0]), minute: int.parse(vm.input.wakeTimeStr!.split(":")[1]));
    }
    if (vm.input.bedTimeStr != null) {
      bed = TimeOfDay(hour: int.parse(vm.input.bedTimeStr!.split(":")[0]), minute: int.parse(vm.input.bedTimeStr!.split(":")[1]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            _buildTimePickerRow(context, "Went to Bed", bed, (t) => vm.setPreciseSleepTimes(t, wake)),
            const SizedBox(height: 20),
            _buildTimePickerRow(context, "Woke Up", wake, (t) => vm.setPreciseSleepTimes(bed, t)),
            const SizedBox(height: 40),
            Center(child: Text("Total Sleep: ${vm.input.sleepHours.toStringAsFixed(1)}h", style: const TextStyle(fontSize: 18, color: Colors.cyanAccent))),
          ] else ...[
            const Center(child: Text("SIMPLE SLIDER MODE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            Slider(value: vm.input.sleepHours, min: 0, max: 14, divisions: 28, activeColor: Colors.cyanAccent, onChanged: (v) => vm.updateInputs(sleep: v)),
          ],
          const SizedBox(height: 40),
          ElevatedButton(onPressed: vm.commitData, child: const Text("SAVE SLEEP LOG")),
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

  // --- CORREZIONE 1: LEGENDA CHART SEMPRE VISIBILE ---
  Widget _buildChartTab(BuildContext context, SimulationViewModel vm, SimulationResult res) {
    if (!vm.input.usePreciseTiming && !vm.isFutureDate) {
      return const Center(child: Text("Chart requires Precise Scheduling or Forecast Mode"));
    }
    if (res.energyCurve.isEmpty) return const Center(child: Text("No Data"));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(res.predictionMessage, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey), textAlign: TextAlign.center),
        ),

        // Grafico Espanso
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
                painter: EnergyChartPainter(points: res.energyCurve, now: DateTime.now(), accentColor: Colors.cyanAccent),
                size: Size.infinite
            ),
          ),
        ),

        // LEGENDA FISSA IN BASSO
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: Theme.of(context).scaffoldBackgroundColor, // Background opaco per leggibilità
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.circle, size: 10, color: Colors.cyanAccent), SizedBox(width: 4),
              Text("History", style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 10, color: Colors.grey), SizedBox(width: 4),
              Text("Future", style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 10, color: Colors.blueAccent), SizedBox(width: 4),
              Text("Hydrate", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaterTab(BuildContext context, SimulationViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text("${vm.input.waterLiters.toStringAsFixed(1)} L", style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WaterButton(label: "+ Glass", icon: Icons.local_drink, onTap: () { vm.addWaterGlass(); }),
              const SizedBox(width: 20),
              _WaterButton(label: "+ Bottle", icon: Icons.local_cafe, onTap: () { vm.updateInputs(water: vm.input.waterLiters + 0.5); vm.commitData(); }),
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Center(child: Text("BODY DEBT"))),
          ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); })
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    _openForecastCalendar(context);
  }
}

// --- CORREZIONE 4: CALENDARIO CON HIGHLIGHT SPECIFICO ---
class ForecastCalendarScreen extends StatelessWidget {
  const ForecastCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimulationViewModel>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(vm.selectedDate.year, vm.selectedDate.month, vm.selectedDate.day);

    final forecasts = vm.getCalendarForecast(14);

    return Scaffold(
      appBar: AppBar(title: const Text("ENERGY FORECAST")),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: 21, // 7 passati + 14 futuri
        itemBuilder: (context, index) {
          DateTime day = today.subtract(const Duration(days: 7)).add(Duration(days: index));
          bool isToday = day.isAtSameMomentAs(today);
          bool isSelected = day.isAtSameMomentAs(selected);
          bool isFuture = day.isAfter(today);

          int? energy;
          if (isFuture) energy = forecasts[day];
          else if (isToday) energy = vm.result.energyPercentage;

          // --- LOGICA COLORI ---
          // Default: Grigio scuro
          Color bgColor = Colors.grey.withOpacity(0.1);
          Border? border;

          // Selezionato: Blu pieno
          if (isSelected) {
            bgColor = Theme.of(context).colorScheme.primary.withOpacity(0.4);
          }

          // Oggi: Bordo Ciano (se selezionato, ha ANCHE il bg blu)
          if (isToday) {
            border = Border.all(color: Colors.cyanAccent, width: 2);
            if (!isSelected) bgColor = Colors.transparent; // Se oggi non è selezionato, solo bordo
          }

          // Badge previsione
          Color badgeColor = Colors.grey;
          if (energy != null) {
            badgeColor = energy > 70 ? Colors.green : (energy > 30 ? Colors.amber : Colors.red);
          }

          return InkWell(
            onTap: () {
              vm.selectDate(day);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: border
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      "${day.day}/${day.month}",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday ? Colors.cyanAccent : Colors.white
                      )
                  ),
                  const SizedBox(height: 8),
                  if (isFuture && energy != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                      child: Text("$energy%", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    )
                  else if (!isFuture)
                    Icon(
                        Icons.history,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey
                    )
                ],
              ),
            ),
          );
        },
      ),
    );
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
        width: 130, padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(16), color: Colors.blueAccent.withOpacity(0.1)),
        child: Column(children: [Icon(icon, color: Colors.blueAccent, size: 40), const SizedBox(height: 12), Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))]),
      ),
    );
  }
}