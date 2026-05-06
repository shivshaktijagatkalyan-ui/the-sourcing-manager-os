import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';

class BrokerSourcedSiteVisitsScreen extends StatefulWidget {
  const BrokerSourcedSiteVisitsScreen({super.key});

  @override
  State<BrokerSourcedSiteVisitsScreen> createState() => _BrokerSourcedSiteVisitsScreenState();
}

class _BrokerSourcedSiteVisitsScreenState extends State<BrokerSourcedSiteVisitsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        final data = await client
            .from('site_visits')
            .select('*, brokers_public(broker_alias), leads_public(alias)')
            .not('source_broker_id', 'is', null)
            .order('scheduled_at', ascending: false);

        setState(() {
          _visits = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _visits = [
            {
              'id': 'v1',
              'scheduled_at': DateTime.now().toIso8601String(),
              'status': 'gps_verified',
              'gps_status': 'verified',
              'photo_verification_status': 'pending',
              'brokers_public': {'broker_alias': 'Panvel King'},
              'leads_public': {'lead_alias': 'L-542'}
            }
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: request_failed')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broker Site Visits')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchVisits,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _visits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _visitCard(_visits[index]),
            ),
          ),
    );
  }

  Widget _visitCard(Map<String, dynamic> visit) {
    final broker = visit['brokers_public']?['broker_alias'] ?? 'Unknown Broker';
    final lead = visit['leads_public']?['alias'] ?? 'Unknown Lead';
    final date = DateTime.parse(visit['scheduled_at']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Source: $broker', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
                _statusBadge(visit['status']),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white38),
                const SizedBox(width: 8),
                Text('${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                _verificationIcon(Icons.location_on, visit['gps_status'] == 'verified'),
                const SizedBox(width: 8),
                _verificationIcon(Icons.camera_alt, visit['photo_verification_status'] == 'verified'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'completed' || status == 'gps_verified' || status == 'photo_verified') color = Colors.green;
    if (status == 'scheduled') color = Colors.blue;
    if (status == 'rejected' || status == 'invalid') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _verificationIcon(IconData icon, bool verified) {
    return Icon(icon, size: 16, color: verified ? Colors.green : Colors.white12);
  }
}
