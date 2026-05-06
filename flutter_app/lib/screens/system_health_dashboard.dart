import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SystemHealthDashboard extends StatefulWidget {
  const SystemHealthDashboard({super.key});

  @override
  State<SystemHealthDashboard> createState() => _SystemHealthDashboardState();
}

class _SystemHealthDashboardState extends State<SystemHealthDashboard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _healthEvents = [];
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _fetchHealthData();
  }

  Future<void> _fetchHealthData() async {
    try {
      final client = Supabase.instance.client;
      
      // 1. Fetch recent health events
      final events = await client
          .from('system_health_events')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      final efFailures = await client.from('edge_function_failures').select('id');
      final pFailures = await client.from('provider_failures').select('id');
      final rlEvents = await client.from('rate_limit_events').select('id');

      if (!mounted) return;
      setState(() {
        _healthEvents = List<Map<String, dynamic>>.from(events);
        _counts = {
          'edge_failures': (efFailures as List).length,
          'provider_failures': (pFailures as List).length,
          'rate_limits': (rlEvents as List).length,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Health & Reliability')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryGrid(),
                  const SizedBox(height: 32),
                  const Text('Recent Health Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildEventsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('EF Failures', _counts['edge_failures'].toString(), Colors.redAccent),
        _buildStatCard('Provider Issues', _counts['provider_failures'].toString(), Colors.orangeAccent),
        _buildStatCard('Rate Limits', _counts['rate_limits'].toString(), Colors.blueAccent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_healthEvents.isEmpty) return const Text('No health events recorded.');
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _healthEvents.length,
      itemBuilder: (context, index) {
        final event = _healthEvents[index];
        final severity = '${event['severity'] ?? 'low'}';
        return ListTile(
          leading: Icon(Icons.warning, color: _getSeverityColor(severity)),
          title: Text('${event['event_type'] ?? 'health_event'}'),
          subtitle: Text('${event['event_message'] ?? ''}'),
          trailing: Text('${event['status'] ?? 'open'}'.toUpperCase(), style: const TextStyle(fontSize: 10)),
        );
      },
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.amber;
      default: return Colors.blue;
    }
  }
}
