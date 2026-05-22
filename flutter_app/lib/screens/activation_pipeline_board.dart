import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import 'broker_detail_screen.dart';
import 'add_lead_from_broker.dart';

class ActivationPipelineBoard extends StatefulWidget {
  const ActivationPipelineBoard({super.key});

  @override
  State<ActivationPipelineBoard> createState() => _ActivationPipelineBoardState();
}

class _ActivationPipelineBoardState extends State<ActivationPipelineBoard> {
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _groupedBrokers = {};

  final List<Map<String, String>> _stages = [
    {'id': 'not_contacted', 'label': 'NOT CONTACTED'},
    {'id': 'first_call_done', 'label': 'FIRST CALL DONE'},
    {'id': 'project_explained', 'label': 'PROJECT EXPLAINED'},
    {'id': 'inventory_shared', 'label': 'INVENTORY SHARED'},
    {'id': 'offer_shared', 'label': 'OFFER SHARED'},
    {'id': 'interested', 'label': 'INTERESTED'},
    {'id': 'meeting_scheduled', 'label': 'MEETING SCHEDULED'},
    {'id': 'lead_expected', 'label': 'LEAD EXPECTED'},
    {'id': 'active_broker', 'label': 'ACTIVE BROKER'},
    {'id': 'dead_not_interested', 'label': 'NOT INTERESTED'},
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
        
        final data = await client
            .from('brokers_public')
            .select('*, broker_activations(activation_stage)')
            .order('broker_alias');

        Map<String, List<Map<String, dynamic>>> grouped = {for (var s in _stages) s['id']!: []};
        
        for (var broker in data) {
          final activations = broker['broker_activations'] as List?;
          final stage = (activations != null && activations.isNotEmpty) 
              ? activations[0]['activation_stage']?.toString() 
              : 'not_contacted';
          
          if (grouped.containsKey(stage)) {
            grouped[stage]!.add(broker);
          } else {
            grouped['not_contacted']!.add(broker);
          }
        }

        setState(() {
          _groupedBrokers = grouped;
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 1));
        Map<String, List<Map<String, dynamic>>> grouped = {for (var s in _stages) s['id']!: []};
        grouped['interested'] = [
          {'id': 'jitu_1', 'broker_alias': 'Jitu Gupta', 'company_name': 'JSN ENTERPRISES', 'category': 'hot'},
          {'id': 'p1', 'broker_alias': 'Panvel King', 'company_name': 'Panvel Realty', 'category': 'hot'},
        ];
        grouped['not_contacted'] = [
          {'id': 'b1', 'broker_alias': 'Rahul Broker', 'company_name': 'Rahul Realty', 'category': 'new'},
        ];
        setState(() {
          _groupedBrokers = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: PremiumUI.danger));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBrokerStage(String brokerId, String newStage) async {
    // Optimistic update
    String? oldStage;
    Map<String, dynamic>? brokerObj;

    setState(() {
      for (var stage in _groupedBrokers.keys) {
        final list = _groupedBrokers[stage]!;
        final idx = list.indexWhere((b) => b['id'].toString() == brokerId);
        if (idx != -1) {
          oldStage = stage;
          brokerObj = list.removeAt(idx);
          break;
        }
      }
      if (brokerObj != null) {
        _groupedBrokers[newStage]!.add(brokerObj!);
      }
    });

    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        await client.from('broker_activations').upsert({
          'broker_id': brokerId,
          'activation_stage': newStage,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved ${brokerObj?['broker_alias']} to ${newStage.replaceAll('_', ' ')}'),
            duration: const Duration(seconds: 1),
            backgroundColor: PremiumUI.secondary,
          )
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _groupedBrokers[newStage]!.removeWhere((b) => b['id'].toString() == brokerId);
        if (oldStage != null && brokerObj != null) {
          _groupedBrokers[oldStage!]!.add(brokerObj!);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: PremiumUI.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: Text('ACTIVATION PIPELINE', style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchPipeline, icon: const Icon(Icons.refresh, color: PremiumUI.primary)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: PremiumUI.primary))
        : Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _stages.length,
                itemBuilder: (context, index) {
                  final stageId = _stages[index]['id']!;
                  final stageLabel = _stages[index]['label']!;
                  return _pipelineColumn(stageId, stageLabel, _groupedBrokers[stageId] ?? []);
                },
              ),
          ),
    );
  }

  Widget _pipelineColumn(String stageId, String label, List<Map<String, dynamic>> brokers) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _updateBrokerStage(details.data, stageId),
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: isOver ? PremiumUI.primary.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isOver ? PremiumUI.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _columnHeader(label, brokers.length, stageId),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: brokers.length,
                  itemBuilder: (context, index) => _brokerDraggable(brokers[index], stageId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _columnHeader(String label, int count, String stageId) {
    final color = PremiumUI.statusColor(stageId == 'active_broker' ? 'active' : stageId == 'interested' ? 'hot' : 'pending');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
          PremiumUI.statusBadge(count.toString(), color),
        ],
      ),
    );
  }

  Widget _brokerDraggable(Map<String, dynamic> broker, String currentStageId) {
    return LongPressDraggable<String>(
      data: broker['id'].toString(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 270,
          child: _brokerCard(broker, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _brokerCard(broker),
      ),
      child: _brokerCard(broker),
    );
  }

  Widget _brokerCard(Map<String, dynamic> broker, {bool isDragging = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: PremiumUI.glassCard(
        opacity: isDragging ? 0.2 : 0.08,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => BrokerDetailScreen(brokerId: broker['id'])));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        broker['broker_alias'] ?? 'Unknown Broker',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (broker['category'] == 'hot')
                      const Icon(Icons.local_fire_department, color: PremiumUI.hot, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  broker['company_name'] ?? 'Freelance Broker',
                  style: const TextStyle(fontSize: 11, color: PremiumUI.muted, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _quickAction(Icons.call, PremiumUI.warning, () {
                      // Trigger Secure Call Logic
                    }),
                    const SizedBox(width: 8),
                    _quickAction(Icons.person_add_alt_1, PremiumUI.secondary, () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AddLeadFromBrokerScreen(sourceBrokerId: broker['id'], sourceBrokerAlias: broker['broker_alias'])));
                    }),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                      child: const Text('DRAG TO MOVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white30)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 16),
        onPressed: onTap,
      ),
    );
  }
}
