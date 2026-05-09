import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'broker_detail_screen.dart';
import 'call_status.dart';


class BrokerFollowupQueueScreen extends StatefulWidget {
  const BrokerFollowupQueueScreen({super.key});

  @override
  State<BrokerFollowupQueueScreen> createState() => _BrokerFollowupQueueScreenState();
}

class _BrokerFollowupQueueScreenState extends State<BrokerFollowupQueueScreen> {
  final TrainingRuntime _trainingRuntime = TrainingRuntime.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _followups = [];
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isSupabaseConfigured) {
      _trainingRuntime.addListener(_handleTrainingUpdate);
    }
    _fetchQueue();
  }

  @override
  void dispose() {
    if (!AppConfig.isSupabaseConfigured) {
      _trainingRuntime.removeListener(_handleTrainingUpdate);
    }
    super.dispose();
  }

  void _handleTrainingUpdate() {
    if (mounted) {
      _fetchQueue();
    }
  }

  Future<void> _fetchQueue() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        // Fetch followups with broker metadata
        final query = client
            .from('broker_followups')
            .select('*, brokers_public(broker_alias, company_name, area, category)')
            .eq('assigned_to', client.auth.currentUser!.id)
            .eq('status', _filterStatus)
            .order('due_at', ascending: true);

        final data = await query;
        setState(() {
          _followups = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(milliseconds: 250));
        setState(() {
          _followups = _trainingRuntime
              .followupsForManager(TrainingRuntime.sourcingManagerId)
              .where((row) => row['status'] == _filterStatus)
              .toList();
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

  Future<void> _completeFollowup(String id) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final pilot = await client.from('pilot_users').select('org_id').eq('user_id', client.auth.currentUser!.id).single();
        
        await client.functions.invoke('manage-external-broker', body: {
          'action': 'complete_followup',
          'organization_id': pilot['org_id'],
          'followup_id': id,
        });
        _fetchQueue();
      } else {
        _trainingRuntime.completeBrokerFollowup(id);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _initiateCall(String brokerId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CallStatusDialog(leadId: brokerId, targetType: 'broker'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Today\'s Follow-ups', style: PremiumUI.h1.copyWith(fontSize: 20)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: PremiumUI.sectionShell(
              title: 'Follow-up Automation',
              subtitle: 'Pending broker callbacks, stage nudges, and safe next actions',
              accentColor: PremiumUI.warning,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aaj follow-up due hai. Secure Call se broker ko connect karo, ya complete mark karke pipeline clean rakho.',
                      style: PremiumUI.subtitle.copyWith(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PremiumUI.statusBadge('${_followups.length} open', PremiumUI.warning),
                ],
              ),
            ),
          ),
          _statusTabs(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _followups.isEmpty 
                ? const Center(child: Text('No follow-ups due.', style: TextStyle(color: PremiumUI.muted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _followups.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _followupCard(_followups[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusTabs() {
    return Container(
      color: PremiumUI.panelColor,
      child: Row(
        children: [
          _tab('pending', 'Pending'),
          _tab('completed', 'Completed'),
        ],
      ),
    );
  }

  Widget _tab(String status, String label) {
    final isSelected = _filterStatus == status;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _filterStatus = status);
          _fetchQueue();
        },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isSelected ? PremiumUI.primary : Colors.transparent, width: 2)),
            ),
          child: Text(label.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? PremiumUI.primary : Colors.white24)),
        ),
      ),
    );
  }

  Widget _followupCard(Map<String, dynamic> followup) {
    final broker = followup['brokers_public'];
    final due = DateTime.parse(followup['due_at']);
    final isOverdue = due.isBefore(DateTime.now()) && followup['status'] == 'pending';

    return Container(
      decoration: PremiumUI.glassBox(color: PremiumUI.warning, opacity: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(broker['broker_alias'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(broker['company_name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ),
                if (isOverdue) _badge('OVERDUE', PremiumUI.danger) else _badge('DUE', PremiumUI.accent),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.white38),
                const SizedBox(width: 8),
                Expanded(child: Text(followup['reason'] ?? followup['title'] ?? 'Routine follow-up', style: const TextStyle(fontSize: 13, color: Colors.white70))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _badge((followup['priority'] ?? 'normal').toString(), PremiumUI.statusColor((followup['priority'] ?? 'normal').toString())),
                const SizedBox(width: 8),
                Text(
                  'Due ${due.day}/${due.month} ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: PremiumUI.muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (followup['status'] == 'pending')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _initiateCall(followup['broker_id']),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('SECURE CALL'),
                      style: ElevatedButton.styleFrom(backgroundColor: PremiumUI.secondary, foregroundColor: Colors.white),
                    ),
                  ),
                const SizedBox(width: 8),
                if (followup['status'] == 'pending')
                  IconButton.filledTonal(
                    onPressed: () => _completeFollowup(followup['id']),
                    icon: const Icon(Icons.check),
                    tooltip: 'Mark Complete',
                  ),
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BrokerDetailScreen(brokerId: followup['broker_id'])));
                  },
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Open Profile',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
