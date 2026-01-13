import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SETTINGS")),
      body: Consumer<SimulationViewModel>(
        builder: (context, vm, _) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text("Hydration Reminders"),
                subtitle: const Text("Receive alerts when you are behind on water"),
                secondary: const Icon(Icons.notifications_active),
                activeColor: Theme.of(context).colorScheme.primary,
                value: vm.areNotificationsEnabled,
                onChanged: (val) => vm.toggleNotifications(val),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("App Version"),
                trailing: const Text("v3.5 (Real-time Drain)"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Factory Reset"),
                subtitle: const Text("Delete all data, history, and profile."),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Erase Everything?"),
                      content: const Text("This action cannot be undone. All your history will be lost."),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel")
                        ),
                        TextButton(
                            onPressed: () {
                              vm.resetApp();
                              Navigator.pop(ctx); // Chiude dialog
                              Navigator.pop(context); // Torna alla Dashboard
                            },
                            child: const Text("RESET DATA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}