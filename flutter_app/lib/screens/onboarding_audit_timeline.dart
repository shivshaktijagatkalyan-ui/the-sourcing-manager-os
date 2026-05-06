import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingAuditTimeline extends StatefulWidget {
  const OnboardingAuditTimeline({super.key});

  @override
  State<OnboardingAuditTimeline> createState() => _OnboardingAuditTimelineState();
}

class _OnboardingAuditTimelineState extends State<OnboardingAuditTimeline> {
  late Future<List<Map<String, dynamic>>> _futureEvents;

  @override
  void initState() {
    super.initState();
    _futureEvents = _loadEvents();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    final rows = await Supabase.instance.client
        .from('onboarding_audit_events')
        .select('id, actor_id, organization_id, target_user_id, event_type, event_context, created_at')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  void _refresh() {
    setState(() => _futureEvents = _loadEvents());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Audit'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureEvents,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final events = snapshot.data!;
          if (events.isEmpty) return const Center(child: Text('No onboarding audit events visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final contextMap = event['event_context'] is Map ? Map<String, dynamic>.from(event['event_context'] as Map) : <String, dynamic>{};
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${event['event_type'] ?? 'event'}'.replaceAll('_', ' ')),
                  subtitle: Text('Org ${_short(event['organization_id'])} | Target ${_short(event['target_user_id'])}'),
                  trailing: Text('${contextMap['status'] ?? ''}'),
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
