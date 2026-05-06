import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class PilotActivityDashboard extends StatefulWidget {
  const PilotActivityDashboard({super.key});

  @override
  State<PilotActivityDashboard> createState() => _PilotActivityDashboardState();
}

class _PilotActivityDashboardState extends State<PilotActivityDashboard> {
  late Future<List<Map<String, dynamic>>> _futureRows;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
  }

  Future<List<Map<String, dynamic>>> _loadRows() async {
    if (!AppConfig.isSupabaseConfigured) return _demoRows;

    final rows = await Supabase.instance.client
        .from('pilot_activity_daily')
        .select('organization_id, activity_date, active_users_count, disabled_users_count, open_disputes_count, critical_events_count, abuse_events_count, locks_created_count, site_visits_verified, gps_failures')
        .order('activity_date', ascending: false)
        .limit(30);
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
        title: const Text('Pilot Activity'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureRows,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No pilot activity visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['activity_date'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActivityChip(label: 'Active Users', value: '${row['active_users_count'] ?? 0}'),
                          _ActivityChip(label: 'Disabled', value: '${row['disabled_users_count'] ?? 0}'),
                          _ActivityChip(label: 'Open Disputes', value: '${row['open_disputes_count'] ?? 0}'),
                          _ActivityChip(label: 'Critical Risk', value: '${row['critical_events_count'] ?? 0}'),
                          _ActivityChip(label: 'Risk Events', value: '${row['abuse_events_count'] ?? 0}'),
                          _ActivityChip(label: 'Locks', value: '${row['locks_created_count'] ?? 0}'),
                          _ActivityChip(label: 'Verified Visits', value: '${row['site_visits_verified'] ?? 0}'),
                          _ActivityChip(label: 'Failed Checks', value: '${row['gps_failures'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final String label;
  final String value;
  const _ActivityChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.analytics_outlined, size: 18),
      label: Text('$label $value'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

const _demoRows = [
  {
    'organization_id': 'demo-org',
    'activity_date': '2026-05-04',
    'active_users_count': 3,
    'disabled_users_count': 0,
    'open_disputes_count': 1,
    'critical_events_count': 0,
    'abuse_events_count': 1,
    'locks_created_count': 2,
    'site_visits_verified': 4,
    'gps_failures': 1,
  },
];
