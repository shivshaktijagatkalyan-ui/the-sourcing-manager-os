import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class AbuseEventDetailScreen extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? initialEvent;

  const AbuseEventDetailScreen({super.key, this.eventId, this.initialEvent});

  @override
  State<AbuseEventDetailScreen> createState() => _AbuseEventDetailScreenState();
}

class _AbuseEventDetailScreenState extends State<AbuseEventDetailScreen> {
  late Future<List<Map<String, dynamic>>> _futureEvents;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _futureEvents = _loadEvents();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    if (!AppConfig.isSupabaseConfigured) {
      return widget.initialEvent == null ? _demoEvents : [widget.initialEvent!];
    }

    final client = Supabase.instance.client;
    if (widget.eventId != null) {
      final rows = await client
          .from('abuse_events')
          .select('id, actor_id, organization_id, lead_id, site_visit_id, event_type, severity, risk_score_delta, evidence_ref, status, created_at, resolved_at, resolved_by')
          .eq('id', widget.eventId!)
          .limit(1);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    final rows = await client
        .from('abuse_events')
        .select('id, actor_id, organization_id, lead_id, site_visit_id, event_type, severity, risk_score_delta, evidence_ref, status, created_at, resolved_at, resolved_by')
        .order('created_at', ascending: false)
        .limit(25);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _resolve(String eventId, String resolution) async {
    if (!AppConfig.isSupabaseConfigured) return;
    setState(() => _isResolving = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'resolve-abuse-event',
        body: {'abuse_event_id': eventId, 'status': resolution},
      );
      if (!mounted) return;
      final ok = response.status == 200 && response.data?['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Event updated.' : 'Event update blocked.')));
      setState(() {
        _futureEvents = _loadEvents();
      });
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abuse Event Detail')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureEvents,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final events = snapshot.data!;
          if (events.isEmpty) return const Center(child: Text('No risk events visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final evidence = event['evidence_ref'] is Map ? Map<String, dynamic>.from(event['evidence_ref'] as Map) : <String, dynamic>{};
              final status = '${event['status'] ?? 'open'}';
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _SeverityBadge(severity: '${event['severity'] ?? 'low'}'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${event['event_type'] ?? 'risk_event'}'.replaceAll('_', ' '),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DetailLine(label: 'Event ID', value: '${event['id']}'),
                      _DetailLine(label: 'Status', value: status),
                      _DetailLine(label: 'Actor ID', value: _safeValue(event['actor_id'])),
                      _DetailLine(label: 'Organization ID', value: _safeValue(event['organization_id'])),
                      _DetailLine(label: 'Visit ID', value: _safeValue(event['site_visit_id'])),
                      _DetailLine(label: 'Risk Delta', value: '${event['risk_score_delta'] ?? 0}'),
                      if (evidence.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text('Evidence Reference', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...evidence.entries.map((entry) => _DetailLine(label: entry.key, value: '${entry.value}')),
                      ],
                      if (status != 'resolved' && status != 'dismissed') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isResolving ? null : () => _resolve('${event['id']}', 'dismissed'),
                                icon: const Icon(Icons.close),
                                label: const Text('Dismiss'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isResolving ? null : () => _resolve('${event['id']}', 'resolved'),
                                icon: const Icon(Icons.check),
                                label: const Text('Resolve'),
                              ),
                            ),
                          ],
                        ),
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

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' => Colors.red,
      'high' => Colors.deepOrange,
      'medium' => Colors.orange,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(severity.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label, style: const TextStyle(color: Colors.white60))),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 2)),
        ],
      ),
    );
  }
}

String _safeValue(dynamic value) => value == null ? '-' : '$value';

const _demoEvents = [
  {
    'id': 'demo-risk-1',
    'event_type': 'gps_outside_geofence_repeated',
    'severity': 'high',
    'risk_score_delta': -0.4,
    'status': 'open',
    'actor_id': 'demo-user',
    'organization_id': 'demo-org',
    'evidence_ref': {'source': 'demo', 'count': 3},
  },
];
