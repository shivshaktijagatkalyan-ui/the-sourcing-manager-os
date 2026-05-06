import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class TrustScoreHistoryScreen extends StatefulWidget {
  const TrustScoreHistoryScreen({super.key});

  @override
  State<TrustScoreHistoryScreen> createState() => _TrustScoreHistoryScreenState();
}

class _TrustScoreHistoryScreenState extends State<TrustScoreHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _futureRows;
  bool _isRunningDecay = false;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
  }

  Future<List<Map<String, dynamic>>> _loadRows() async {
    if (!AppConfig.isSupabaseConfigured) return _demoRows;

    final rows = await Supabase.instance.client
        .from('trust_score_snapshots')
        .select('id, entity_id, entity_type, organization_id, score_before, score_after, score_delta, reason_code, components_json, calculated_at')
        .order('calculated_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _runDecay() async {
    if (!AppConfig.isSupabaseConfigured) return;
    setState(() => _isRunningDecay = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'run-trust-decay',
        body: {'inactivity_days': 30},
      );
      if (!mounted) return;
      final ok = response.status == 200 && response.data?['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Trust decay run completed.' : 'Trust decay blocked.')));
      setState(() {
        _futureRows = _loadRows();
      });
    } finally {
      if (mounted) setState(() => _isRunningDecay = false);
    }
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
        title: const Text('Trust Score History'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          IconButton(
            tooltip: 'Run trust decay',
            onPressed: _isRunningDecay ? null : _runDecay,
            icon: _isRunningDecay
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.trending_down_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureRows,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No trust history visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final components = row['components_json'] is Map ? Map<String, dynamic>.from(row['components_json'] as Map) : <String, dynamic>{};
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['reason_code'] ?? 'trust_update'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Entity ${_shortId(row['entity_id'])}  |  ${row['entity_type'] ?? 'user'}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ScoreChip(label: 'Before', value: '${row['score_before'] ?? '-'}'),
                          _ScoreChip(label: 'After', value: '${row['score_after'] ?? '-'}'),
                          _ScoreChip(label: 'Delta', value: '${row['score_delta'] ?? 0}'),
                        ],
                      ),
                      if (components.isNotEmpty) ...[
                        const Divider(height: 24),
                        ...components.entries.map((entry) => Text('${entry.key}: ${entry.value}', style: const TextStyle(color: Colors.white70))),
                      ],
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

class _ScoreChip extends StatelessWidget {
  final String label;
  final String value;
  const _ScoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label $value'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    'id': 'demo-snapshot-1',
    'entity_id': 'demo-user',
    'entity_type': 'user',
    'score_before': 3.2,
    'score_after': 3.0,
    'score_delta': -0.2,
    'reason_code': 'inactivity_decay',
    'components_json': {'inactive_days': 30, 'verified_event_count': 0},
  },
];
