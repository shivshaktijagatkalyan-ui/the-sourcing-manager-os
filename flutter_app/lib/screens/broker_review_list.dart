import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/training_runtime.dart';

class BrokerReviewListScreen extends StatefulWidget {
  const BrokerReviewListScreen({super.key});

  @override
  State<BrokerReviewListScreen> createState() => _BrokerReviewListScreenState();
}

class _BrokerReviewListScreenState extends State<BrokerReviewListScreen> {
  late Future<List<Map<String, dynamic>>> _futurePending;

  @override
  void initState() {
    super.initState();
    _futurePending = _loadPending();
  }

  Future<List<Map<String, dynamic>>> _loadPending() async {
    if (AppConfig.isTrainingMode) {
      final visits = TrainingRuntime.instance.siteVisitsForManager(TrainingRuntime.sourcingManagerId);
      return visits.where((v) => v['status'] == 'broker_review_pending').toList();
    }
    final client = Supabase.instance.client;
    final response = await client
        .from('site_visits')
        .select('*, projects(project_name), leads_public(alias)')
        .eq('status', 'broker_review_pending')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _processReview(String visitId, String action, {String? reason}) async {
    try {
      if (AppConfig.isTrainingMode) {
        await TrainingRuntime.instance.brokerReviewSiteVisit(visitId, action);
        if (!mounted) return;
        setState(() {
          _futurePending = _loadPending();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visit ${action}ed successfully.')));
        return;
      }

      final client = Supabase.instance.client;
      final response = await client.functions.invoke('broker-review-site-visit', body: {
        'site_visit_id': visitId,
        'action': action,
        'reason': reason,
      });

      if (response.status != 200) throw Exception(response.data['error']);
      
      if (!mounted) return;
      setState(() {
        _futurePending = _loadPending();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visit ${action}ed successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showRejectDialog(String visitId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Visit Evidence'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processReview(visitId, 'reject', reason: controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit Review Queue')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futurePending,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;

          if (items.isEmpty) return const Center(child: Text('No visits pending review.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['leads_public']['alias'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const Icon(Icons.verified, color: Colors.blue),
                        ],
                      ),
                      Text('Project: ${item['projects']['project_name']}', style: const TextStyle(color: Colors.white70)),
                      const Divider(height: 24),
                      Text('GPS Distance: ${item['distance_from_project_meters']?.toStringAsFixed(1)}m', style: const TextStyle(fontSize: 12)),
                      Text('Photo Hash: ${item['photo_sha256']?.substring(0, 16)}...', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showRejectDialog(item['id']),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _processReview(item['id'], 'approve'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      )
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
