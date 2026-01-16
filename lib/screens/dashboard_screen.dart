import 'dart:math'; // Necessario per il calcolo degli angoli del tachimetro
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
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<SimulationViewModel>(
            builder: (context, vm, _) {
              final date = vm.selectedDate;
              final now = DateTime.now();
              if (vm.isFutureDate) return Text("FORECAST: ${date.day}/${date.month}");
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              return Text(isToday ? "BODYDEBT" : "HISTORY: ${date.day}/${date.month}");
            },
          ),
          centerTitle: true,
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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.circle, size: 10, color: Colors.cyanAccent), SizedBox(width: 4), Text("History", style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 10, color: Colors.grey), SizedBox(width: 4), Text("Future", style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 10, color: Colors.blueAccent), SizedBox(width: 4), Text("Hydrate", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaterTab(BuildContext context, SimulationViewModel vm) {
    double percentage = vm.result.hydrationStatus;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text("HYDRATION LEVEL", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150, height: 150,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  color: Colors.blueAccent,
                ),
              ),
              Column(
                children: [
                  Text("${percentage.toInt()}%", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("of daily need", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            vm.result.needsWaterNow ? "You are behind schedule!" : "Great job, keep it up! 💧",
            style: TextStyle(color: vm.result.needsWaterNow ? Colors.orange : Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text("${vm.input.waterLiters.toStringAsFixed(1)} L", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WaterButton(label: "+ Glass", icon: Icons.local_drink, onTap: () {
                vm.addWaterGlass();
                _showRewardSnackBar(context, "Hydration Boost! +200ml 💧");
              }),
              const SizedBox(width: 20),
              _WaterButton(label: "+ Bottle", icon: Icons.local_cafe, onTap: () {
                vm.updateInputs(water: vm.input.waterLiters + 0.5);
                vm.commitData();
                _showRewardSnackBar(context, "Big Sip! +500ml 🌊");
              }),
            ],
          ),
          const Spacer(),
          const Text("MANUAL ADJUST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
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
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
            child: const Center(child: Text("BODY DEBT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 2))),
          ),
          ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }
          ),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.monitor_weight),
              title: const Text("BMI Calculator"),
              subtitle: const Text("Check your stats"),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BMICalculatorScreen())); }
          ),
          ListTile(
              leading: const Icon(Icons.lightbulb),
              title: const Text("Sleep Guide"),
              subtitle: const Text("Tips for better rest"),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepGuideScreen())); }
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    _openForecastCalendar(context);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CALENDARIO CON PERCENTUALI (Aggiornato)
// ════════════════════════════════════════════════════════════════════════════
class ForecastCalendarScreen extends StatelessWidget {
  const ForecastCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimulationViewModel>();
    final now = DateTime.now();

    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    int firstWeekday = firstDayOfMonth.weekday;
    int emptySlots = firstWeekday - 1;

    final forecasts = vm.getCalendarForecast(14);

    return Scaffold(
      appBar: AppBar(title: const Text("CALENDAR")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                  .map((d) => Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))
                  .toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.7, crossAxisSpacing: 4, mainAxisSpacing: 4),
              itemCount: daysInMonth + emptySlots,
              itemBuilder: (context, index) {
                if (index < emptySlots) return Container();

                final dayNum = index - emptySlots + 1;
                final date = DateTime(now.year, now.month, dayNum);

                bool isToday = date.day == now.day;
                bool isSelected = vm.selectedDate.day == date.day && vm.selectedDate.month == date.month;

                int? energy;
                bool isForecastable = !date.isBefore(DateTime(now.year, now.month, now.day)) &&
                    date.difference(now).inDays < 14;

                if (date.isAfter(now) && isForecastable) {
                  energy = forecasts[date];
                } else if (isToday) {
                  energy = vm.result.energyPercentage;
                }

                Color badgeColor = Colors.grey;
                if (energy != null) badgeColor = energy > 70 ? Colors.greenAccent[700]! : (energy > 30 ? Colors.orangeAccent : Colors.redAccent);

                return InkWell(
                  onTap: () {
                    vm.selectDate(date);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: isToday ? Border.all(color: Colors.cyanAccent, width: 2) : null,
                      color: isSelected ? Colors.blueAccent.withOpacity(0.5) : Colors.grey.withOpacity(0.1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("$dayNum", style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? Colors.cyanAccent : Colors.white)),
                        const SizedBox(height: 4),
                        if (energy != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                            child: Text("$energy%", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                          )
                        else
                          const Icon(Icons.circle, size: 6, color: Colors.grey)
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BMI TACHIMETRO (Nuovo)
// ════════════════════════════════════════════════════════════════════════════
class BMICalculatorScreen extends StatelessWidget {
  const BMICalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SimulationViewModel>();
    final profile = vm.userProfile;
    final bmi = profile.bmi;

    String status = "Normal";
    Color color = Colors.green;
    if (bmi < 18.5) { status = "Underweight"; color = Colors.blueAccent; }
    else if (bmi >= 25 && bmi < 30) { status = "Overweight"; color = Colors.orangeAccent; }
    else if (bmi >= 30) { status = "Obese"; color = Colors.redAccent; }

    return Scaffold(
      appBar: AppBar(title: const Text("BMI CALCULATOR")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // GAUGE CUSTOM
            SizedBox(
              width: 300,
              height: 160,
              child: CustomPaint(
                painter: BMIGaugePainter(bmi: bmi),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(bmi.toStringAsFixed(1), style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color)),
                        Text(status, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Height: ${profile.heightCm}cm | Weight: ${profile.weightKg}kg",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
                child: const Text("Update Profile in Settings")
            )
          ],
        ),
      ),
    );
  }
}

class BMIGaugePainter extends CustomPainter {
  final double bmi;
  BMIGaugePainter({required this.bmi});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final strokeWidth = 20.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Disegna archi colorati
    // Scala BMI sul tachimetro: da 15 (min) a 40 (max)
    // Angoli: da 180 gradi (PI) a 360 gradi (2*PI)

    // Underweight (<18.5) -> Blue
    paint.color = Colors.blueAccent;
    canvas.drawArc(rect, pi, 0.45, false, paint); // approx segment

    // Normal (18.5 - 25) -> Green
    paint.color = Colors.green;
    canvas.drawArc(rect, pi + 0.45, 0.9, false, paint);

    // Overweight (25 - 30) -> Orange
    paint.color = Colors.orange;
    canvas.drawArc(rect, pi + 1.35, 0.6, false, paint);

    // Obese (>30) -> Red
    paint.color = Colors.red;
    canvas.drawArc(rect, pi + 1.95, 1.2, false, paint); // fino alla fine

    // Lancetta
    double minBMI = 15;
    double maxBMI = 40;
    double clampedBMI = bmi.clamp(minBMI, maxBMI);
    double normalized = (clampedBMI - minBMI) / (maxBMI - minBMI); // 0.0 a 1.0
    double angle = pi + (normalized * pi); // Da 180 a 360

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final needleLength = radius - 10;
    final needleEnd = Offset(
      center.dx + needleLength * cos(angle),
      center.dy + needleLength * sin(angle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 8, needlePaint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- Sleep Guide Screen (Invariato) ---
class SleepGuideScreen extends StatelessWidget {
  const SleepGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SLEEP GUIDE")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TipTile(title: "The 90-Minute Rule", desc: "Sleep cycles last about 90 minutes. Try to wake up at the end of a cycle to feel refreshed."),
          _TipTile(title: "Consistency is Key", desc: "Going to bed at the same time every day trains your circadian rhythm."),
          _TipTile(title: "Hydration Impact", desc: "Dehydration reduces melatonin production. Drink water throughout the day, but stop 1h before bed."),
          _TipTile(title: "Digital Sunset", desc: "Blue light from screens tricks your brain into thinking it's daytime. Avoid screens 1h before sleep."),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final String title;
  final String desc;
  const _TipTile({required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline, color: Colors.cyanAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
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