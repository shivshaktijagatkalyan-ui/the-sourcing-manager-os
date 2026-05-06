import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class RiskNotificationsView extends StatefulWidget {
  const RiskNotificationsView({super.key});

  @override
  State<RiskNotificationsView> createState() => _RiskNotificationsViewState();
}

class _RiskNotificationsViewState extends State<RiskNotificationsView> {
  late Future<List<Map<String, dynamic>>> _futureAlerts;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _futureAlerts = _loadAlerts();
  }

  Future<List<Map<String, dynamic>>> _loadAlerts() async {
    if (!AppConfig.isSupabaseConfigured) return _demoAlerts;

    final rows = await Supabase.instance.client
        .from('risk_notifications')
        .select('id, abuse_event_id, organization_id, recipient_user_id, notification_type, severity, reason_code, status, created_at, acknowledged_at')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _acknowledge(String id) async {
    if (!AppConfig.isSupabaseConfigured) return;
    setState(() => _isWorking = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'acknowledge-risk-notification',
        body: {'notification_id': id},
      );
      if (!mounted) return;
      final ok = response.status == 200 && response.data?['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Notification acknowledged.' : 'Acknowledgement blocked.')));
      setState(() {
        _futureAlerts = _loadAlerts();
      });
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _refresh() {
    setState(() {
      _futureAlerts = _loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Notifications'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureAlerts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final alerts = snapshot.data!;
          if (alerts.isEmpty) return const Center(child: Text('No notifications visible for this role.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final status = '${alert['status'] ?? 'open'}';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: _SeverityDot(severity: '${alert['severity'] ?? 'low'}'),
                  title: Text('${alert['notification_type'] ?? 'risk_notification'}'.replaceAll('_', ' ')),
                  subtitle: Text('${alert['reason_code'] ?? 'review_required'}  |  $status'),
                  trailing: status == 'acknowledged'
                      ? const Icon(Icons.check_circle_outline, color: Colors.green)
                      : IconButton(
                          tooltip: 'Acknowledge',
                          onPressed: _isWorking ? null : () => _acknowledge('${alert['id']}'),
                          icon: const Icon(Icons.done),
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

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' => Colors.red,
      'high' => Colors.deepOrange,
      'medium' => Colors.orange,
      _ => Colors.blueGrey,
    };
    return CircleAvatar(radius: 8, backgroundColor: color);
  }
}

const _demoAlerts = [
  {
    'id': 'demo-alert-1',
    'notification_type': 'critical_abuse_event',
    'severity': 'critical',
    'reason_code': 'manual_demo',
    'status': 'open',
  },
];
