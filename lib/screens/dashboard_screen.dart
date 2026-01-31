import 'dart:math';
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

// 1. AGGIUNTO MIXIN: WidgetsBindingObserver
class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMorningPrompt();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // FIX: Quando l'app torna attiva, forza l'aggiornamento
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Chiama il nuovo metodo "refreshDataOnResume" che gestisce sia date che dati
      context.read<SimulationViewModel>().refreshDataOnResume();
    }
  }

  void _checkMorningPrompt() {
    final vm = context.read<SimulationViewModel>();
    final hour = DateTime.now().hour;
    if (vm.isSelectedDateToday && hour >= 5 && vm.shouldShowMorningPrompt) {
      // Logic for prompt
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsSetup = context.select<SimulationViewModel, bool>((vm) => vm.isSetupRequired);
    if (needsSetup) return const SetupScreen();

    final isFuture = context.select<SimulationViewModel, bool>((vm) => vm.isFutureDate);
    final isPast = context.select<SimulationViewModel, bool>((vm) => vm.isPastDate);

    final bgDark = const Color(0xFF121212);
    final cardDark = const Color(0xFF1E1E1E);
    final primaryAccent = Colors.cyanAccent;

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          backgroundColor: bgDark,
          elevation: 0,
          title: Consumer<SimulationViewModel>(
            builder: (context, vm, _) {
              final date = vm.selectedDate;
              final now = DateTime.now();
              if (vm.isFutureDate) return _buildDateTitle("FORECAST", date);

              // Verifica robusta per "Oggi"
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

              return isToday
                  ? const Text("BODYDEBT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white))
                  : _buildDateTitle("HISTORY", date);
            },
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              color: primaryAccent,
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
                const SizedBox(height: 10),
                _buildTopStatsModern(context, res, vm),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(25)),
                  child: TabBar(
                    indicator: BoxDecoration(color: primaryAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryAccent.withOpacity(0.5))),
                    labelColor: primaryAccent,
                    unselectedLabelColor: Colors.grey,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    onTap: (index) {
                      if (isPast && index == 1) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chart unavailable for past logs"), backgroundColor: Colors.redAccent));
                      }
                    },
                    tabs: [
                      const Tab(text: "SLEEP"),
                      Tab(text: isPast ? "LOCKED" : "ENERGY"),
                      const Tab(text: "WATER"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    physics: isFuture ? const NeverScrollableScrollPhysics() : null,
                    children: [
                      isFuture ? _buildLockedTab("Inputs locked in forecast mode") : _buildSleepInputTab(context, vm),
                      isPast ? _buildLockedTab("Chart unavailable for history") : _buildChartTab(context, vm, res),
                      isFuture ? _buildLockedTab("Water logging locked") : _buildWaterTab(context, vm),
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

  Widget _buildDateTitle(String prefix, DateTime date) {
    return Column(
      children: [
        Text(prefix, style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey)),
        Text("${date.day}/${date.month}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- WIDGETS ESTRAIBILI (Invariati per brevità, sono identici alla v8.0) ---
  // Copia qui _buildTopStatsModern, _buildSleepInputTab, _buildChartTab, _buildWaterTab
  // dal codice precedente. Non sono cambiati, ma servono per compilare.
  // ... [INSERIRE CODICE WIDGETS] ...

  // (Per brevità ometto i widget lunghi UI che non cambiano logicamente,
  // usa quelli del messaggio precedente v8.0 all'interno di questo file)

  // --------------------------------------------------------------------------

  // Placeholder dei metodi UI per completezza in caso di copy-paste diretto
  Widget _buildTopStatsModern(BuildContext context, SimulationResult res, SimulationViewModel vm) {
    // Usa l'implementazione v8.0
    Color energyColor = res.energyPercentage > 70 ? Colors.cyanAccent : (res.energyPercentage > 30 ? Colors.amberAccent : Colors.redAccent);
    bool isFuture = vm.isFutureDate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF1E1E1E), const Color(0xFF252525)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.bolt, color: energyColor, size: 16), const SizedBox(width: 5), Text(isFuture ? "PREDICTION" : "ENERGY", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))]), const SizedBox(height: 8), Text("${res.energyPercentage}%", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: energyColor))]))),
          const SizedBox(width: 16),
          Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.access_time, color: Colors.redAccent, size: 16), SizedBox(width: 5), Text("SLEEP DEBT", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))]), const SizedBox(height: 8), Text("${res.sleepDebtHours.toStringAsFixed(1)}h", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white))]))),
        ],
      ),
    );
  }

  Widget _buildSleepInputTab(BuildContext context, SimulationViewModel vm) {
    // Usa implementazione v8.0
    TimeOfDay wake = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay bed = const TimeOfDay(hour: 23, minute: 0);
    if (vm.input.wakeTimeStr != null) wake = TimeOfDay(hour: int.parse(vm.input.wakeTimeStr!.split(":")[0]), minute: int.parse(vm.input.wakeTimeStr!.split(":")[1]));
    if (vm.input.bedTimeStr != null) bed = TimeOfDay(hour: int.parse(vm.input.bedTimeStr!.split(":")[0]), minute: int.parse(vm.input.bedTimeStr!.split(":")[1]));
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [Container(decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)), child: SwitchListTile(title: const Text("Precise Scheduling", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), subtitle: const Text("Enable to generate chart", style: TextStyle(color: Colors.grey, fontSize: 12)), value: vm.input.usePreciseTiming, activeColor: Colors.cyanAccent, onChanged: (val) => vm.togglePreciseMode(val))), const SizedBox(height: 20), if (vm.input.usePreciseTiming) ...[Row(children: [Expanded(child: _buildTimeCard(context, "BEDTIME", bed, (t) => vm.setPreciseSleepTimes(t, wake), Icons.bedtime)), const SizedBox(width: 16), Expanded(child: _buildTimeCard(context, "WAKE UP", wake, (t) => vm.setPreciseSleepTimes(bed, t), Icons.wb_sunny))]), const SizedBox(height: 30), Text("TOTAL SLEEP", style: TextStyle(color: Colors.cyanAccent.withOpacity(0.7), letterSpacing: 2, fontSize: 12)), Text("${vm.input.sleepHours.toStringAsFixed(1)}h", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white))] else ...[const Text("MANUAL INPUT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 20), Text("${vm.input.sleepHours.toStringAsFixed(1)} h", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)), Slider(value: vm.input.sleepHours, min: 0, max: 14, divisions: 28, activeColor: Colors.cyanAccent, onChanged: (v) => vm.updateInputs(sleep: v))], const SizedBox(height: 40), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: vm.commitData, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.withOpacity(0.1), foregroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.cyanAccent))), child: const Text("SAVE SLEEP LOG", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))))]));
  }

  Widget _buildTimeCard(BuildContext context, String label, TimeOfDay time, Function(TimeOfDay) onSelect, IconData icon) {
    return GestureDetector(onTap: () async { final t = await showTimePicker(context: context, initialTime: time); if (t != null) onSelect(t); }, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Column(children: [Icon(icon, color: Colors.grey, size: 20), const SizedBox(height: 10), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 5), Text(time.format(context), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))])));
  }

  Widget _buildChartTab(BuildContext context, SimulationViewModel vm, SimulationResult res) {
    if (!vm.input.usePreciseTiming && !vm.isFutureDate) return _buildLockedTab("Precise Scheduling Required");
    if (res.energyCurve.isEmpty) return const Center(child: Text("Calculating...", style: TextStyle(color: Colors.grey)));
    return Column(children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16), child: Text(res.predictionMessage, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70), textAlign: TextAlign.center)), Expanded(child: Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), padding: const EdgeInsets.only(top: 20, right: 20, bottom: 20), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)]), child: CustomPaint(painter: EnergyChartPainter(points: res.energyCurve, now: DateTime.now(), accentColor: Colors.cyanAccent), size: Size.infinite)))]);
  }

  Widget _buildWaterTab(BuildContext context, SimulationViewModel vm) {
    double percentage = vm.result.hydrationStatus;
    Color progressColor = vm.result.needsWaterNow ? Colors.orangeAccent : Colors.cyanAccent;
    return Padding(padding: const EdgeInsets.all(24.0), child: Column(children: [Stack(alignment: Alignment.center, children: [SizedBox(width: 180, height: 180, child: CircularProgressIndicator(value: percentage / 100, strokeWidth: 15, backgroundColor: const Color(0xFF222222), color: progressColor, strokeCap: StrokeCap.round)), Column(children: [Text("${percentage.toInt()}%", style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white)), Text("HYDRATION", style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5), letterSpacing: 2))])]), const SizedBox(height: 20), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: progressColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(vm.result.needsWaterNow ? "⚠️ Drink water now!" : "Hydration Optimal 💧", style: TextStyle(color: progressColor, fontWeight: FontWeight.bold))), const Spacer(), Row(children: [Expanded(child: _WaterButton(label: "+ Glass", sub: "200ml", icon: Icons.local_drink, color: Colors.blueAccent, onTap: () { vm.addWaterGlass(); _showRewardSnackBar(context, "Hydration Boost! +200ml 💧"); })), const SizedBox(width: 16), Expanded(child: _WaterButton(label: "+ Bottle", sub: "500ml", icon: Icons.local_cafe, color: Colors.purpleAccent, onTap: () { vm.updateInputs(water: vm.input.waterLiters + 0.5); vm.commitData(); _showRewardSnackBar(context, "Big Sip! +500ml 🌊"); }))]), const SizedBox(height: 30), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("MANUAL ADJUST", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), Text("${vm.input.waterLiters.toStringAsFixed(1)} L", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))]), SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white, overlayColor: Colors.white12), child: Slider(value: vm.input.waterLiters, max: 5.0, onChanged: (v) => vm.updateInputs(water: v))) ]));
  }

  void _showRewardSnackBar(BuildContext context, String message) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text(message, style: const TextStyle(fontWeight: FontWeight.bold))]), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2))); }

  Widget _buildLockedTab(String msg) { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 60, color: Colors.white.withOpacity(0.1)), const SizedBox(height: 16), Text(msg, style: TextStyle(color: Colors.white.withOpacity(0.3)))])); }

  void _openForecastCalendar(BuildContext context) { Navigator.push(context, MaterialPageRoute(builder: (_) => const ForecastCalendarScreen())); }

  Widget _buildDrawer(BuildContext context) {
    // Implementazione V8.0
    final drawerStyle = TextStyle(fontWeight: FontWeight.w600, color: Colors.white);
    return Drawer(backgroundColor: const Color(0xFF121212), child: ListView(padding: EdgeInsets.zero, children: [DrawerHeader(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.health_and_safety, size: 50, color: Colors.white), SizedBox(height: 10), Text("BODY DEBT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 3, color: Colors.white))])), ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: Text("Settings", style: drawerStyle), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }), const Divider(color: Colors.white10), ListTile(leading: const Icon(Icons.monitor_weight, color: Colors.cyanAccent), title: Text("BMI Calculator", style: drawerStyle), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BMICalculatorScreen())); }), ListTile(leading: const Icon(Icons.lightbulb, color: Colors.amberAccent), title: Text("Sleep Guide", style: drawerStyle), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepGuideScreen())); })]));
  }
}
class _WaterButton extends StatelessWidget { final String label; final String sub; final IconData icon; final Color color; final VoidCallback onTap; const _WaterButton({required this.label, required this.sub, required this.icon, required this.color, required this.onTap}); @override Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(height: 120, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 32), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)), Text(sub, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)))]))); } }
class ForecastCalendarScreen extends StatelessWidget { const ForecastCalendarScreen({super.key}); @override Widget build(BuildContext context) { final vm = context.watch<SimulationViewModel>(); final now = DateTime.now(); final firstDayOfMonth = DateTime(now.year, now.month, 1); final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month); int firstWeekday = firstDayOfMonth.weekday; int emptySlots = firstWeekday - 1; final forecasts = vm.getCalendarForecast(14); return Scaffold(backgroundColor: const Color(0xFF121212), appBar: AppBar(backgroundColor: const Color(0xFF121212), title: const Text("CALENDAR", style: TextStyle(letterSpacing: 2, fontSize: 16)), centerTitle: true), body: Column(children: [Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"].map((d) => Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))).toList())), Expanded(child: GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.75, crossAxisSpacing: 6, mainAxisSpacing: 6), itemCount: daysInMonth + emptySlots, itemBuilder: (context, index) { if (index < emptySlots) return Container(); final dayNum = index - emptySlots + 1; final date = DateTime(now.year, now.month, dayNum); bool isToday = date.day == now.day; bool isSelected = vm.selectedDate.day == date.day && vm.selectedDate.month == date.month; int? energy; if (date.isAfter(now) && !date.isBefore(DateTime(now.year, now.month, now.day)) && date.difference(now).inDays < 14) { energy = forecasts[date]; } else if (isToday) { energy = vm.result.energyPercentage; } Color badgeColor = Colors.grey; if (energy != null) badgeColor = energy > 70 ? Colors.greenAccent[700]! : (energy > 30 ? Colors.orangeAccent : Colors.redAccent); return InkWell(onTap: () { vm.selectDate(date); Navigator.pop(context); }, borderRadius: BorderRadius.circular(10), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: isToday ? Border.all(color: Colors.cyanAccent, width: 2) : null, color: isSelected ? Colors.blueAccent : const Color(0xFF1E1E1E)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("$dayNum", style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? Colors.cyanAccent : Colors.white)), const SizedBox(height: 4), if (energy != null) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)), child: Text("$energy%", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)))]))); }))])); } }
class BMICalculatorScreen extends StatelessWidget { const BMICalculatorScreen({super.key}); @override Widget build(BuildContext context) { final vm = context.read<SimulationViewModel>(); final profile = vm.userProfile; final bmi = profile.bmi; String status = "Normal"; Color color = Colors.green; if (bmi < 18.5) { status = "Underweight"; color = Colors.blueAccent; } else if (bmi >= 25 && bmi < 30) { status = "Overweight"; color = Colors.orangeAccent; } else if (bmi >= 30) { status = "Obese"; color = Colors.redAccent; } return Scaffold(backgroundColor: const Color(0xFF121212), appBar: AppBar(backgroundColor: const Color(0xFF121212), title: const Text("BMI STATUS")), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 300, height: 160, child: CustomPaint(painter: BMIGaugePainter(bmi: bmi), child: Center(child: Padding(padding: const EdgeInsets.only(top: 50), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(bmi.toStringAsFixed(1), style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: color)), Text(status, style: TextStyle(fontSize: 20, color: color.withOpacity(0.8), letterSpacing: 1.5))]))))), const SizedBox(height: 50), Container(padding: const EdgeInsets.all(20), margin: const EdgeInsets.symmetric(horizontal: 30), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)), child: Column(children: [_statRow("Height", "${profile.heightCm} cm"), const Divider(color: Colors.white10, height: 30), _statRow("Weight", "${profile.weightKg} kg")])), const SizedBox(height: 30), TextButton.icon(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }, label: const Text("Edit Profile in Settings", style: TextStyle(color: Colors.grey)))]))); } Widget _statRow(String label, String value) { return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]); } }
class BMIGaugePainter extends CustomPainter { final double bmi; BMIGaugePainter({required this.bmi}); @override void paint(Canvas canvas, Size size) { final center = Offset(size.width / 2, size.height); final radius = size.width / 2; final strokeWidth = 25.0; final rect = Rect.fromCircle(center: center, radius: radius); final paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.butt..strokeWidth = strokeWidth; paint.color = Colors.blueAccent.withOpacity(0.8); canvas.drawArc(rect, pi, 0.45, false, paint); paint.color = Colors.greenAccent.withOpacity(0.8); canvas.drawArc(rect, pi + 0.45, 0.9, false, paint); paint.color = Colors.orangeAccent.withOpacity(0.8); canvas.drawArc(rect, pi + 1.35, 0.6, false, paint); paint.color = Colors.redAccent.withOpacity(0.8); canvas.drawArc(rect, pi + 1.95, 1.2, false, paint); double clampedBMI = bmi.clamp(15.0, 40.0); double normalized = (clampedBMI - 15) / (40 - 15); double angle = pi + (normalized * pi); final needleLength = radius - 5; final needleEnd = Offset(center.dx + needleLength * cos(angle), center.dy + needleLength * sin(angle)); canvas.drawLine(center, needleEnd, Paint()..color = Colors.white..strokeWidth = 6..strokeCap = StrokeCap.round); canvas.drawCircle(center, 10, Paint()..color = Colors.white); } @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true; }
class SleepGuideScreen extends StatelessWidget { const SleepGuideScreen({super.key}); @override Widget build(BuildContext context) { return Scaffold(backgroundColor: const Color(0xFF121212), appBar: AppBar(backgroundColor: const Color(0xFF121212), title: const Text("SLEEP GUIDE")), body: ListView(padding: const EdgeInsets.all(16), children: const [_TipTile(title: "The 90-Minute Rule", desc: "Sleep cycles last about 90 minutes. Try to wake up at the end of a cycle."), _TipTile(title: "Consistency", desc: "Go to bed and wake up at the same time every day."), _TipTile(title: "Caffeine Curfew", desc: "Avoid caffeine 6-8 hours before bed."), _TipTile(title: "Darkness", desc: "Make your room pitch black or use an eye mask.")])); } }
class _TipTile extends StatelessWidget { final String title; final String desc; const _TipTile({required this.title, required this.desc}); @override Widget build(BuildContext context) { return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: ListTile(leading: const Icon(Icons.star, color: Colors.amberAccent), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), subtitle: Text(desc, style: const TextStyle(color: Colors.grey)))); } }