import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteUserScreen extends StatefulWidget {
  const InviteUserScreen({super.key});

  @override
  State<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends State<InviteUserScreen> {
  final _inviteRefController = TextEditingController();
  final _orgController = TextEditingController();
  String _selectedRole = 'broker_agent';
  bool _isLoading = false;

  final List<String> _roles = [
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

  Future<void> _sendInvite() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'invite-user',
        body: {
          'invite_ref': _inviteRefController.text,
          'role_id': _selectedRole,
          'organization_id': _orgController.text.trim(),
        },
      );

      if (response.status != 200) throw Exception(response.data['reason'] ?? 'Failed');

      if (!mounted) return;
      final code = response.data?['invite_code'] ?? 'created';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite created. One-time code: $code')),
      );
      _inviteRefController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite blocked.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Team Member')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create a secure invitation. The invite reference is hashed before storage.'),
            const SizedBox(height: 32),
            TextField(
              controller: _orgController,
              decoration: const InputDecoration(labelText: 'Organization ID', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inviteRefController,
              decoration: const InputDecoration(labelText: 'Invite Reference', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ').toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
              decoration: const InputDecoration(labelText: 'Assigned Role', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendInvite,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Send Invitation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
