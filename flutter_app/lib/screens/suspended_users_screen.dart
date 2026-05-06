import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuspendedUsersScreen extends StatefulWidget {
  const SuspendedUsersScreen({super.key});

  @override
  State<SuspendedUsersScreen> createState() => _SuspendedUsersScreenState();
}

class _SuspendedUsersScreenState extends State<SuspendedUsersScreen> {
  final _orgController = TextEditingController();
  final _userController = TextEditingController();
  final _reasonController = TextEditingController(text: 'operator_review');
  late Future<List<Map<String, dynamic>>> _futureRows;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
  }

  Future<List<Map<String, dynamic>>> _loadRows() async {
    final rows = await Supabase.instance.client
        .from('user_suspensions')
        .select('id, user_id, reason, starts_at, ends_at')
        .order('created_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _suspend() async {
    setState(() => _isWorking = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'suspend-user',
        body: {
          'organization_id': _orgController.text.trim(),
          'target_user_id': _userController.text.trim(),
          'reason_code': _reasonController.text.trim(),
        },
      );
      if (!mounted) return;
      final ok = response.status == 200 && response.data?['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'User suspended.' : 'Suspension blocked.')));
      setState(() => _futureRows = _loadRows());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suspended Users')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _orgController, decoration: const InputDecoration(labelText: 'Organization ID', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _userController, decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _reasonController, decoration: const InputDecoration(labelText: 'Reason Code', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isWorking ? null : _suspend,
            icon: const Icon(Icons.block),
            label: Text(_isWorking ? 'Submitting...' : 'Suspend User'),
          ),
          const Divider(height: 32),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureRows,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snapshot.data!;
              if (rows.isEmpty) return const Text('No suspension records visible for this role.');
              return Column(
                children: rows
                    .map((row) => ListTile(
                          leading: const Icon(Icons.block),
                          title: Text('User ${_short(row['user_id'])}'),
                          subtitle: Text('${row['reason'] ?? 'review'} | ${row['starts_at'] ?? '-'}'),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _short(dynamic value) {
  final text = '${value ?? '-'}';
  return text.length <= 8 ? text : text.substring(0, 8);
}
