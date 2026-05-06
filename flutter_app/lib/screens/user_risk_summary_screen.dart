import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class UserRiskSummaryScreen extends StatefulWidget {
  const UserRiskSummaryScreen({super.key});

  @override
  State<UserRiskSummaryScreen> createState() => _UserRiskSummaryScreenState();
}

class _UserRiskSummaryScreenState extends State<UserRiskSummaryScreen> {
  late Future<List<Map<String, dynamic>>> _futureRows;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
  }

  Future<List<Map<String, dynamic>>> _loadRows() async {
    if (!AppConfig.isSupabaseConfigured) return _demoRows;

    final rows = await Supabase.instance.client
        .from('user_risk_summary')
        .select('user_id, organization_id, open_event_count, critical_open_count, last_event_at, trust_score')
        .order('critical_open_count', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  void _refresh() {
    setState(() {
      _futureRows = _loadRows();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Risk Summary'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureRows,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No user risk summary visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: Text('User ${_shortId(row['user_id'])}'),
                  subtitle: Text('Open: ${row['open_event_count'] ?? 0}  |  Critical: ${row['critical_open_count'] ?? 0}'),
                  trailing: Text('${row['trust_score'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _shortId(dynamic id) {
  final text = '${id ?? '-'}';
  if (text.length <= 8) return text;
  return text.substring(0, 8);
}

const _demoRows = [
  {
    'user_id': 'demo-user',
    'organization_id': 'demo-org',
    'open_event_count': 1,
    'critical_open_count': 0,
    'trust_score': 3.0,
  },
];
