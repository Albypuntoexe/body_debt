import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimulationViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("SETTINGS")),
      body: ListView(
        children: [
          // PUNTO 1: Profilo nelle impostazioni
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text("MY PROFILE", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Physiological Data"),
            subtitle: Text("${vm.userProfile.age}y • ${vm.userProfile.heightCm}cm • ${vm.userProfile.weightKg}kg"),
            trailing: const Icon(Icons.edit),
            onTap: () => _showEditProfileDialog(context, vm),
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text("PREFERENCES", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text("Hydration Reminders"),
            subtitle: const Text("Receive alerts when you are behind"),
            secondary: const Icon(Icons.notifications_active),
            activeColor: Theme.of(context).colorScheme.primary,
            value: vm.areNotificationsEnabled,
            onChanged: (val) => vm.toggleNotifications(val),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Factory Reset"),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Erase Everything?"),
                  content: const Text("All data will be lost."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                    TextButton(
                        onPressed: () {
                          vm.resetApp();
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text("RESET", style: TextStyle(color: Colors.red))
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, SimulationViewModel vm) {
    final weightCtrl = TextEditingController(text: vm.userProfile.weightKg.toString());
    final heightCtrl = TextEditingController(text: vm.userProfile.heightCm.toString());

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: "Weight (kg)"), keyboardType: TextInputType.number),
              TextField(controller: heightCtrl, decoration: const InputDecoration(labelText: "Height (cm)"), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  double? w = double.tryParse(weightCtrl.text);
                  double? h = double.tryParse(heightCtrl.text);
                  if (w != null && h != null) {
                    // Manteniamo età e sesso invariati per ora
                    vm.saveUserProfile(vm.userProfile.age, w, h, vm.userProfile.gender);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Save")
            ),
          ],
        )
    );
  }
}