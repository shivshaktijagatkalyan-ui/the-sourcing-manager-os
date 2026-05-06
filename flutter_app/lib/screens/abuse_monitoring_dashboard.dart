import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import 'abuse_event_detail.dart';
import 'org_risk_summary_screen.dart';
import 'pilot_activity_dashboard.dart';
import 'risk_notifications_view.dart';
import 'trust_score_history_screen.dart';
import 'user_risk_summary_screen.dart';

class AbuseMonitoringDashboard extends StatefulWidget {
  const AbuseMonitoringDashboard({super.key});

  @override
  State<AbuseMonitoringDashboard> createState() => _AbuseMonitoringDashboardState();
}

class _AbuseMonitoringDashboardState extends State<AbuseMonitoringDashboard> {
  late Future<_OpsDashboardData> _futureData;
  bool _isRunningSummary = false;

  @override
  void initState() {
    super.initState();
    _futureData = _loadData();
  }

  Future<_OpsDashboardData> _loadData() async {
    if (!AppConfig.isSupabaseConfigured) return _OpsDashboardData.demo();

    final client = Supabase.instance.client;
    final events = await client
        .from('abuse_events')
        .select('id, actor_id, organization_id, event_type, severity, risk_score_delta, status, created_at')
        .order('created_at', ascending: false)
        .limit(8);
    final alerts = await client
        .from('risk_notifications')
        .select('id, notification_type, severity, reason_code, status, created_at')
        .order('created_at', ascending: false)
        .limit(8);
    final orgSummary = await client
        .from('org_risk_summary')
        .select('org_id, open_event_count, critical_open_count, high_open_count, last_event_at, average_trust_score')
        .limit(1);
    final userSummary = await client
        .from('user_risk_summary')
        .select('user_id, organization_id, open_event_count, critical_open_count, last_event_at, trust_score')
        .order('critical_open_count', ascending: false)
        .limit(5);

    return _OpsDashboardData(
      events: List<Map<String, dynamic>>.from(events as List),
      alerts: List<Map<String, dynamic>>.from(alerts as List),
      orgSummary: List<Map<String, dynamic>>.from(orgSummary as List),
      userSummary: List<Map<String, dynamic>>.from(userSummary as List),
    );
  }

  void _refresh() {
    setState(() {
      _futureData = _loadData();
    });
  }

  Future<void> _runSummary() async {
    if (!AppConfig.isSupabaseConfigured) return;
    setState(() => _isRunningSummary = true);
    try {
      final response = await Supabase.instance.client.functions.invoke('generate-risk-summary', body: const {});
      if (!mounted) return;
      if (response.status != 200 || response.data?['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Risk summary blocked.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Risk summary refreshed.')));
        _refresh();
      }
    } finally {
      if (mounted) setState(() => _isRunningSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ops Control Room', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Generate risk summary',
            onPressed: _isRunningSummary ? null : _runSummary,
            icon: _isRunningSummary
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      body: FutureBuilder<_OpsDashboardData>(
        future: _futureData,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DashboardStats(data: data),
                const SizedBox(height: 16),
                _OpsActionGrid(onRefresh: _refresh),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Open Risk Events',
                  actionLabel: 'All',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AbuseEventDetailScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                ...data.events.map((event) => _EventTile(event: event, onChanged: _refresh)),
                if (data.events.isEmpty) const _EmptyState(text: 'No risk events visible for this role.'),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Risk Notifications',
                  actionLabel: 'Open',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RiskNotificationsView()),
                  ),
                ),
                const SizedBox(height: 8),
                ...data.alerts.map((alert) => _AlertTile(alert: alert)),
                if (data.alerts.isEmpty) const _EmptyState(text: 'No notifications visible for this role.'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  final _OpsDashboardData data;
  const _DashboardStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final org = data.orgSummary.isEmpty ? <String, dynamic>{} : data.orgSummary.first;
    final openEvents = org['open_event_count'] ?? data.events.where((event) => event['status'] == 'open').length;
    final critical = org['critical_open_count'] ?? data.events.where((event) => event['severity'] == 'critical').length;
    final high = org['high_open_count'] ?? data.events.where((event) => event['severity'] == 'high').length;
    final score = org['average_trust_score'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cards = [
          _StatCard(label: 'Open Events', value: '$openEvents', icon: Icons.warning_amber_outlined, color: Colors.orange),
          _StatCard(label: 'Critical', value: '$critical', icon: Icons.report_outlined, color: Colors.red),
          _StatCard(label: 'High Risk', value: '$high', icon: Icons.priority_high_outlined, color: Colors.deepOrange),
          _StatCard(label: 'Avg Trust', value: score == null ? '-' : '$score', icon: Icons.verified_user_outlined, color: Colors.green),
        ];

        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWide ? 2.4 : 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}

class _OpsActionGrid extends StatelessWidget {
  final VoidCallback onRefresh;
  const _OpsActionGrid({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _OpsAction('Org Risk', Icons.domain_verification_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrgRiskSummaryScreen()))),
      _OpsAction('User Risk', Icons.manage_accounts_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserRiskSummaryScreen()))),
      _OpsAction('Trust History', Icons.timeline_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrustScoreHistoryScreen()))),
      _OpsAction('Pilot Activity', Icons.query_stats_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PilotActivityDashboard()))),
      _OpsAction('Notifications', Icons.notifications_active_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiskNotificationsView()))),
      _OpsAction('Event Detail', Icons.fact_check_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AbuseEventDetailScreen()))),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth >= 720 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth >= 720 ? 3.2 : 2.4,
          children: actions.map((action) => _ActionButton(action: action)).toList(),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final _OpsAction action;
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: action.onTap,
      icon: Icon(action.icon),
      label: Text(action.label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onChanged;
  const _EventTile({required this.event, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final severity = '${event['severity'] ?? 'low'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: _SeverityIcon(severity: severity),
        title: Text('${event['event_type'] ?? 'risk_event'}'.replaceAll('_', ' ')),
        subtitle: Text('Status: ${event['status'] ?? 'open'}  |  Delta: ${event['risk_score_delta'] ?? 0}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AbuseEventDetailScreen(eventId: '${event['id']}', initialEvent: event),
            ),
          );
          onChanged();
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: _SeverityIcon(severity: '${alert['severity'] ?? 'low'}'),
        title: Text('${alert['notification_type'] ?? 'risk_notification'}'.replaceAll('_', ' ')),
        subtitle: Text('${alert['reason_code'] ?? 'review_required'}  |  ${alert['status'] ?? 'open'}'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const _SectionHeader({required this.title, required this.actionLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _SeverityIcon extends StatelessWidget {
  final String severity;
  const _SeverityIcon({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' => Colors.red,
      'high' => Colors.deepOrange,
      'medium' => Colors.orange,
      _ => Colors.blueGrey,
    };
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Icon(Icons.shield_outlined, color: color, size: 18),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _OpsAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OpsAction(this.label, this.icon, this.onTap);
}

class _OpsDashboardData {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> orgSummary;
  final List<Map<String, dynamic>> userSummary;

  const _OpsDashboardData({
    required this.events,
    required this.alerts,
    required this.orgSummary,
    required this.userSummary,
  });

  factory _OpsDashboardData.demo() {
    return const _OpsDashboardData(
      events: [
        {
          'id': 'demo-risk-1',
          'event_type': 'gps_outside_geofence_repeated',
          'severity': 'high',
          'risk_score_delta': -0.4,
          'status': 'open',
        },
      ],
      alerts: [
        {
          'id': 'demo-alert-1',
          'notification_type': 'critical_abuse_event',
          'severity': 'critical',
          'reason_code': 'manual_demo',
          'status': 'open',
        },
      ],
      orgSummary: [
        {
          'open_event_count': 1,
          'critical_open_count': 1,
          'high_open_count': 1,
          'average_trust_score': 3.0,
        },
      ],
      userSummary: [],
    );
  }
}
