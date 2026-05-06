import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingInvitesScreen extends StatefulWidget {
  const PendingInvitesScreen({super.key});

  @override
  State<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends State<PendingInvitesScreen> {
  late Future<List<Map<String, dynamic>>> _futureInvites;

  @override
  void initState() {
    super.initState();
    _futureInvites = _loadInvites();
  }

  Future<List<Map<String, dynamic>>> _loadInvites() async {
    final response = await Supabase.instance.client
        .from('organization_invites')
        .select('id, organization_id, target_role, status, expires_at, created_at')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response as List);
  }

  void _refresh() {
    setState(() {
      _futureInvites = _loadInvites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Invites'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureInvites,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final invites = snapshot.data!;
          if (invites.isEmpty) return const Center(child: Text('No invite records visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: Text('${invite['target_role'] ?? 'role_pending'}'.replaceAll('_', ' ')),
                  subtitle: Text('Invite ${_short(invite['id'])} | ${invite['status'] ?? 'pending'}'),
                  trailing: Text(_dateOnly(invite['expires_at'])),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _short(dynamic value) {
  final text = '${value ?? '-'}';
  return text.length <= 8 ? text : text.substring(0, 8);
}

String _dateOnly(dynamic value) {
  final text = '${value ?? '-'}';
  return text.length >= 10 ? text.substring(0, 10) : text;
}
