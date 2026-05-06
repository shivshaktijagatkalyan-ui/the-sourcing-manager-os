import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class OrgRiskSummaryScreen extends StatefulWidget {
  const OrgRiskSummaryScreen({super.key});

  @override
  State<OrgRiskSummaryScreen> createState() => _OrgRiskSummaryScreenState();
}

class _OrgRiskSummaryScreenState extends State<OrgRiskSummaryScreen> {
  late Future<List<Map<String, dynamic>>> _futureRows;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
  }

  Future<List<Map<String, dynamic>>> _loadRows() async {
    if (!AppConfig.isSupabaseConfigured) return _demoRows;

    final rows = await Supabase.instance.client
        .from('org_risk_summary')
        .select('org_id, open_event_count, critical_open_count, high_open_count, last_event_at, average_trust_score')
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
        title: const Text('Org Risk Summary'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureRows,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No organization risk summary visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) => _OrgRiskCard(row: rows[index]),
          );
        },
      ),
    );
  }
}

class _OrgRiskCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _OrgRiskCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Org ${_shortId(row['org_id'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(label: 'Open', value: '${row['open_event_count'] ?? 0}', color: Colors.orange),
                _Metric(label: 'Critical', value: '${row['critical_open_count'] ?? 0}', color: Colors.red),
                _Metric(label: 'High', value: '${row['high_open_count'] ?? 0}', color: Colors.deepOrange),
                _Metric(label: 'Avg Trust', value: '${row['average_trust_score'] ?? '-'}', color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
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
    'org_id': 'demo-org',
    'open_event_count': 1,
    'critical_open_count': 0,
    'high_open_count': 1,
    'average_trust_score': 3.0,
  },
];
