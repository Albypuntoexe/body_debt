import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/simulation_view_model.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("INITIALIZE SYSTEM")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text("Enter base physiological parameters."),
              const SizedBox(height: 20),
              TextFormField(
                controller: _ageCtrl,
                decoration: const InputDecoration(labelText: "Age (Years)"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _weightCtrl,
                decoration: const InputDecoration(labelText: "Weight (kg)"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _heightCtrl,
                decoration: const InputDecoration(labelText: "Height (cm)"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final vm = context.read<SimulationViewModel>();
                    vm.saveUserProfile(
                      int.parse(_ageCtrl.text),
                      double.parse(_weightCtrl.text),
                      double.parse(_heightCtrl.text),
                      'M',
                    );
                  }
                },
                child: const Text("INITIALIZE BODYDEBT"),
              )
            ],
          ),
        ),
      ),
    );
  }
}