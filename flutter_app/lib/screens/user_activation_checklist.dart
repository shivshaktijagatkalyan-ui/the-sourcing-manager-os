import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserActivationChecklist extends StatefulWidget {
  const UserActivationChecklist({super.key});

  @override
  State<UserActivationChecklist> createState() => _UserActivationChecklistState();
}

class _UserActivationChecklistState extends State<UserActivationChecklist> {
  final _orgController = TextEditingController();
  final _userController = TextEditingController();
  bool _profileComplete = false;
  bool _complianceApproved = false;
  bool _pilotApproved = false;
  bool _isWorking = false;
  List<Map<String, dynamic>> _checks = [];

  Future<void> _activate() async {
    setState(() => _isWorking = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'activate-user',
        body: {
          'organization_id': _orgController.text.trim(),
          'target_user_id': _userController.text.trim(),
          'profile_completed': _profileComplete,
          'compliance_approved': _complianceApproved,
          'pilot_approved': _pilotApproved,
        },
      );
      if (!mounted) return;
      final ok = response.status == 200 && response.data?['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'User activated.' : 'Activation blocked.')));
      await _loadChecks();
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _loadChecks() async {
    if (_orgController.text.trim().isEmpty || _userController.text.trim().isEmpty) return;
    final rows = await Supabase.instance.client
        .from('user_activation_checks')
        .select('check_name, passed, checked_at')
        .eq('organization_id', _orgController.text.trim())
        .eq('user_id', _userController.text.trim())
        .order('check_name');
    if (!mounted) return;
    setState(() => _checks = List<Map<String, dynamic>>.from(rows as List));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Activation Checklist')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _orgController, decoration: const InputDecoration(labelText: 'Organization ID', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _userController, decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SwitchListTile(value: _profileComplete, onChanged: (value) => setState(() => _profileComplete = value), title: const Text('Profile fields complete')),
          SwitchListTile(value: _complianceApproved, onChanged: (value) => setState(() => _complianceApproved = value), title: const Text('Compliance checks approved')),
          SwitchListTile(value: _pilotApproved, onChanged: (value) => setState(() => _pilotApproved = value), title: const Text('Pilot status approved')),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isWorking ? null : _activate,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(_isWorking ? 'Checking...' : 'Activate User'),
          ),
          const SizedBox(height: 20),
          const Text('Latest Checks', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._checks.map((check) => ListTile(
                leading: Icon(check['passed'] == true ? Icons.check_circle : Icons.cancel, color: check['passed'] == true ? Colors.green : Colors.red),
                title: Text('${check['check_name']}'.replaceAll('_', ' ')),
                subtitle: Text('${check['checked_at'] ?? '-'}'),
              )),
        ],
      ),
    );
  }
}
