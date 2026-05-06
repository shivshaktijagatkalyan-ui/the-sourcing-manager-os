import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import 'broker_detail_screen.dart';

class BrokerCrmListScreen extends StatefulWidget {
  const BrokerCrmListScreen({super.key});

  @override
  State<BrokerCrmListScreen> createState() => _BrokerCrmListScreenState();
}

class _BrokerCrmListScreenState extends State<BrokerCrmListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _brokers = [];
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _fetchBrokers();
  }

  Future<void> _fetchBrokers() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        // Fetch brokers with their activation status for the current project context
        // In a real multi-project app, we'd filter by current project ID.
        var query = client.from('brokers_public').select('*, broker_activations(activation_stage)');
        
        if (_filterCategory != 'all') {
          if (_filterCategory == 'today') {
            // This would ideally join broker_followups
            // For now, filtering by presence of followups due today is complex in one query without a custom RPC
            // We'll filter the list locally or use a simplified query
          } else {
            query = query.eq('category', _filterCategory);
          }
        }

        final data = await query.order('created_at', ascending: false);
        setState(() {
          _brokers = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _brokers = [
            {'id': 'jitu_1', 'broker_alias': 'Jitu Gupta', 'company_name': 'JSN ENTERPRISES', 'area': 'Mira Road', 'category': 'hot', 'interest_level': 'high', 'city': 'Mumbai', 'broker_activations': [{'activation_stage': 'interested'}]},
            {'id': '1', 'broker_alias': 'Panvel King', 'company_name': 'Panvel Realty', 'area': 'Panvel', 'category': 'hot', 'interest_level': 'high', 'city': 'Navi Mumbai', 'broker_activations': [{'activation_stage': 'interested'}]},
            {'id': '2', 'broker_alias': 'Wise Partner', 'company_name': 'Wadhwa Agents', 'area': 'Kamothe', 'category': 'active', 'interest_level': 'medium', 'city': 'Navi Mumbai', 'broker_activations': [{'activation_stage': 'active_broker'}]},
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

  Future<void> _initiateCall(String brokerId) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final response = await client.functions.invoke('initiate-broker-call', body: {'broker_id': brokerId});
        final data = response.data as Map<String, dynamic>;
        
        if (data['ok'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secure call bridge queued... Connecting...'), backgroundColor: Colors.green));
        } else {
          _showCallError(data['reason'] ?? 'server_error');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo: Call bridge initiated')));
      }
    } catch (e) {
      _showCallError('request_failed');
    }
  }

  void _showCallError(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $reason'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broker CRM'),
        actions: [
          IconButton(onPressed: _fetchBrokers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _brokers.isEmpty 
                ? const Center(child: Text('No brokers found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _brokers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final broker = _brokers[index];
                      return _brokerCard(broker);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip('all', 'All'),
          _filterChip('today', 'Today'),
          _filterChip('hot', 'Hot'),
          _filterChip('warm', 'Warm'),
          _filterChip('active', 'Active'),
          _filterChip('new', 'New'),
          _filterChip('inactive', 'Inactive'),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _filterCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _filterCategory = value);
            _fetchBrokers();
          }
        },
      ),
    );
  }

  Widget _brokerCard(Map<String, dynamic> broker) {
    final category = broker['category'] ?? 'new';
    final interest = broker['interest_level'] ?? 'unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(broker['broker_alias'] ?? 'Unknown Broker', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (broker['company_name'] != null)
                        Text(broker['company_name'], style: const TextStyle(fontSize: 14, color: Colors.white54)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _badge(category, _getCategoryColor(category)),
                    const SizedBox(height: 4),
                    _activationBadge(broker),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.white54),
                const SizedBox(width: 4),
                Text('${broker['area'] ?? '-'}, ${broker['city'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                const Icon(Icons.star_border, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(interest.toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BrokerDetailScreen(brokerId: broker['id'])),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _initiateCall(broker['id']),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Secure Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child: Text('Contact protected. Calls are encrypted.', style: TextStyle(fontSize: 10, color: Colors.white24))),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _activationBadge(Map<String, dynamic> broker) {
    final activations = broker['broker_activations'] as List?;
    final stage = (activations != null && activations.isNotEmpty) 
        ? activations[0]['activation_stage']?.toString() 
        : 'not_contacted';
        
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        stage!.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'hot': return Colors.red;
      case 'warm': return Colors.orange;
      case 'active': return Colors.green;
      case 'new': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
