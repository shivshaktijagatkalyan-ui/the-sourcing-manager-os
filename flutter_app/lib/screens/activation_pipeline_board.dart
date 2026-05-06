import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import 'broker_detail_screen.dart';

class ActivationPipelineBoard extends StatefulWidget {
  const ActivationPipelineBoard({super.key});

  @override
  State<ActivationPipelineBoard> createState() => _ActivationPipelineBoardState();
}

class _ActivationPipelineBoardState extends State<ActivationPipelineBoard> {
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _groupedBrokers = {};

  final List<String> _stages = [
    'not_contacted',
    'first_call_done',
    'project_explained',
    'inventory_shared',
    'offer_shared',
    'interested',
    'meeting_scheduled',
    'lead_expected',
    'active_broker',
    'dead_not_interested',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPipeline();
  }

  Future<void> _fetchPipeline() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        // Fetch brokers with their current activation stage
        final data = await client
            .from('brokers_public')
            .select('*, broker_activations(activation_stage)')
            .order('broker_alias');

        Map<String, List<Map<String, dynamic>>> grouped = {for (var s in _stages) s: []};
        
        for (var broker in data) {
          final activations = broker['broker_activations'] as List?;
          final stage = (activations != null && activations.isNotEmpty) 
              ? activations[0]['activation_stage']?.toString() 
              : 'not_contacted';
          
          if (grouped.containsKey(stage)) {
            grouped[stage]!.add(broker);
          }
        }

        setState(() {
          _groupedBrokers = grouped;
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _groupedBrokers = {for (var s in _stages) s: []};
          _groupedBrokers['interested'] = [
            {'id': 'jitu_1', 'broker_alias': 'Jitu Gupta', 'company_name': 'JSN ENTERPRISES', 'category': 'hot'},
            {'id': '1', 'broker_alias': 'Panvel King', 'company_name': 'Panvel Realty', 'category': 'hot'},
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activation Pipeline'),
        actions: [
          IconButton(onPressed: _fetchPipeline, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            itemCount: _stages.length,
            itemBuilder: (context, index) {
              final stage = _stages[index];
              return _pipelineColumn(stage, _groupedBrokers[stage] ?? []);
            },
          ),
    );
  }

  Widget _pipelineColumn(String stage, List<Map<String, dynamic>> brokers) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _columnHeader(stage, brokers.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: brokers.length,
              itemBuilder: (context, index) => _brokerCard(brokers[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnHeader(String stage, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              stage.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Text(count.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _brokerCard(Map<String, dynamic> broker) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1E293B),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => BrokerDetailScreen(brokerId: broker['id'])));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(broker['broker_alias'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              if (broker['company_name'] != null)
                Text(broker['company_name'], style: const TextStyle(fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniChip(broker['category'] ?? 'new'),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
      child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white38)),
    );
  }
}
