import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  final _orgController = TextEditingController();
  final _targetController = TextEditingController();
  String _selectedRole = 'caller';

  static const _roles = [
    'platform_admin',
    'developer_admin',
    'broker_owner',
    'broker_agent',
    'sourcing_manager',
    'caller',
    'compliance_admin',
    'dispute_admin',
    'finance_admin',
    'read_only_auditor',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('role_assignments')
          .select('user_id, role_id, status, organization_id')
          .order('assigned_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(response as List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role list blocked.')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignRole() async {
    final response = await Supabase.instance.client.functions.invoke(
      'assign-role',
      body: {
        'organization_id': _orgController.text.trim(),
        'target_user_id': _targetController.text.trim(),
        'role_id': _selectedRole,
      },
    );
    if (!mounted) return;
    final ok = response.status == 200 && response.data?['ok'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Role assigned.' : 'Role assignment blocked.')));
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organization Members')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _orgController, decoration: const InputDecoration(labelText: 'Organization ID', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _targetController, decoration: const InputDecoration(labelText: 'Target User ID', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role.replaceAll('_', ' ')))).toList(),
                  onChanged: (value) => setState(() => _selectedRole = value ?? 'caller'),
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _assignRole,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Assign Role'),
                ),
                const Divider(height: 32),
                ..._users.map((user) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(_short(user['user_id'])),
                      subtitle: Text('Role: ${user['role_id']} | ${user['status']}'),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

String _short(dynamic value) {
  final text = '${value ?? '-'}';
  return text.length <= 8 ? text : text.substring(0, 8);
}
