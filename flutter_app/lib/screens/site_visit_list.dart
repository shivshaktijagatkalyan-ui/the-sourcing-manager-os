import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'site_visit_verify.dart';

class SiteVisitListScreen extends StatefulWidget {
  const SiteVisitListScreen({super.key});

  @override
  State<SiteVisitListScreen> createState() => _SiteVisitListScreenState();
}

class _SiteVisitListScreenState extends State<SiteVisitListScreen> {
  late Future<List<Map<String, dynamic>>> _futureVisits;

  @override
  void initState() {
    super.initState();
    _futureVisits = _loadVisits();
  }

  Future<List<Map<String, dynamic>>> _loadVisits() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];

    final response = await client
        .from('site_visits')
        .select('*, projects(project_name, area, city), leads_public(alias)')
        .order('scheduled_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  void _refresh() {
    setState(() {
      _futureVisits = _loadVisits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Visits', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureVisits,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final visits = snapshot.data!;

          if (visits.isEmpty) return const Center(child: Text('No site visits scheduled.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              final projectName = visit['projects']?['project_name'] ?? 'Unknown Project';
              final leadAlias = visit['leads_public']?['alias'] ?? 'Lead';
              final scheduledAt = DateTime.tryParse(visit['scheduled_at'] ?? '');
              final status = visit['status'] ?? 'scheduled';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(leadAlias, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$projectName • ${scheduledAt != null ? DateFormat('dd MMM, hh:mm a').format(scheduledAt) : 'No date'}'),
                  trailing: _StatusBadge(status: status),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SiteVisitVerifyScreen(visitId: visit['id'])),
                    );
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status.contains('verified')) color = Colors.green;
    if (status == 'started') color = Colors.orange;
    if (status == 'completed') color = Colors.blue;
    if (status == 'invalid') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
