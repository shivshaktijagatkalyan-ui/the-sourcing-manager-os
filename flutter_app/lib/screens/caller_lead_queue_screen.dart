import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'call_status.dart';

class CallerLeadQueueScreen extends StatefulWidget {
  const CallerLeadQueueScreen({super.key});

  @override
  State<CallerLeadQueueScreen> createState() => _CallerLeadQueueScreenState();
}

class _CallerLeadQueueScreenState extends State<CallerLeadQueueScreen> {
  final TrainingRuntime _trainingRuntime = TrainingRuntime.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leads = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isSupabaseConfigured || AppConfig.isTrainingMode) {
      _trainingRuntime.addListener(_handleTrainingUpdate);
    }
    _fetchLeads();
  }

  @override
  void dispose() {
    if (!AppConfig.isSupabaseConfigured || AppConfig.isTrainingMode) {
      _trainingRuntime.removeListener(_handleTrainingUpdate);
    }
    super.dispose();
  }

  void _handleTrainingUpdate() {
    if (mounted) {
      _fetchLeads();
    }
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser!.id;

        final data = await client
            .from('leads_public')
            .select('*, brokers_public(broker_alias, company_name)')
            .eq('assigned_caller_id', userId)
            .order('call_priority', ascending: false);

        final now = DateTime.now();
        final sortedLeads = List<Map<String, dynamic>>.from(data);

        sortedLeads.sort((a, b) {
          final aCallback =
              DateTime.tryParse(a['callback_at'] ?? '')?.toLocal();
          final bCallback =
              DateTime.tryParse(b['callback_at'] ?? '')?.toLocal();
          final aIsDue = aCallback != null && aCallback.isBefore(now);
          final bIsDue = bCallback != null && bCallback.isBefore(now);

          if (aIsDue && !bIsDue) return -1;
          if (!aIsDue && bIsDue) return 1;

          if (a['call_priority'] == 'high' && b['call_priority'] != 'high') {
            return -1;
          }
          if (a['call_priority'] != 'high' && b['call_priority'] == 'high') {
            return 1;
          }

          if (a['lead_status'] == 'new' && b['lead_status'] != 'new') return -1;
          if (a['lead_status'] != 'new' && b['lead_status'] == 'new') return 1;

          return 0;
        });

        setState(() {
          _leads = sortedLeads;
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(milliseconds: 250));
        setState(() {
          _leads = _trainingRuntime
              .callerAssignedLeads(TrainingRuntime.callerRahulId);
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
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('SECURE QUEUE',
            style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PremiumUI.primary))
          : RefreshIndicator(
              onRefresh: _fetchLeads,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildQueueStats(),
                  const SizedBox(height: 16),
                  ..._leads.asMap().entries.map(
                      (entry) => _buildAnimatedCard(entry.value, entry.key)),
                ],
              ),
            ),
    );
  }

  Widget _buildQueueStats() {
    return PremiumUI.sectionShell(
      title: 'SECURE AGENT QUEUE',
      subtitle: 'Zero-Trust Protocol Active. Numbers remain encrypted.',
      accentColor: PremiumUI.accent,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Call bridge creates a secure tunnel to the lead. Update outcome immediately to maintain trust score.',
              style: PremiumUI.subtitle.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),
          PremiumUI.statusBadge('${_leads.length} LEADS', PremiumUI.accent),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard(Map<String, dynamic> lead, int index) {
    // Simple staggered animation simulation
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _leadCard(lead),
    );
  }

  Widget _leadCard(Map<String, dynamic> lead) {
    final broker = lead['brokers_public']?['broker_alias'] ?? 'Direct';
    final company = lead['brokers_public']?['company_name'] ?? '';
    final outcome =
        (lead['last_call_outcome'] ?? lead['lead_status'] ?? 'pending')
            .toString();
    final dataScore = lead['data_quality_score'] ?? 0;

    return Container(
      decoration: PremiumUI.glassBox(color: PremiumUI.accent, opacity: 0.05),
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
                    Text(lead['alias'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(
                        'Source: $broker${company.isEmpty ? '' : ' • $company'}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54)),
                  ],
                ),
                Row(
                  children: [
                    if (dataScore > 0) ...[
                      Icon(Icons.query_stats,
                          size: 12,
                          color: dataScore > 70
                              ? PremiumUI.secondary
                              : PremiumUI.warning),
                      const SizedBox(width: 4),
                      Text('$dataScore%',
                          style: TextStyle(
                              fontSize: 10,
                              color: dataScore > 70
                                  ? PremiumUI.secondary
                                  : PremiumUI.warning,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                    ],
                    _priorityBadge(lead['call_priority'] ?? 'normal'),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.white38),
                const SizedBox(width: 8),
                Text(lead['area'] ?? 'N/A',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(width: 20),
                const Icon(Icons.currency_rupee,
                    size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                    '${(lead['budget_min'] ?? 0) ~/ 100000}L - ${(lead['budget_max'] ?? 0) ~/ 100000}L',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PremiumUI.statusBadge(
                    (lead['lead_status'] ?? 'new').toString().toUpperCase(),
                    PremiumUI.statusColor(
                        (lead['lead_status'] ?? 'new').toString())),
                PremiumUI.statusBadge(
                    outcome.replaceAll('_', ' ').toUpperCase(),
                    PremiumUI.statusColor(outcome)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _initiateCall(lead['id']),
                      icon: const Icon(Icons.phone_locked),
                      label: const Text('SECURE CALL',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumUI.secondary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _showOutcomeSheet(lead),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.edit_note, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    return PremiumUI.statusBadge(
        priority.toUpperCase(), PremiumUI.statusColor(priority));
  }

  Future<void> _initiateCall(String leadId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CallStatusDialog(leadId: leadId, targetType: 'lead'),
    );
  }

  void _showOutcomeSheet(Map<String, dynamic> lead) {
    String selectedOutcome = lead['last_call_outcome'] ?? 'interested';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PremiumUI.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in_outlined,
                      color: PremiumUI.secondary),
                  const SizedBox(width: 12),
                  Text('UPDATE OUTCOME',
                      style: PremiumUI.h1.copyWith(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Lead: ${lead['alias']}', style: PremiumUI.subtitle),
              const SizedBox(height: 24),
              const Text('SELECT CALL OUTCOME',
                  style: TextStyle(
                      color: PremiumUI.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _buildOutcomePicker(selectedOutcome,
                  (val) => setSheetState(() => selectedOutcome = val)),
              const SizedBox(height: 20),
              const Text('CALL NOTES (SAFE METADATA)',
                  style: TextStyle(
                      color: PremiumUI.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  hintText: 'Enter brief call summary...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _submitOutcome(
                        lead['id'], selectedOutcome, notesController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumUI.secondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SUBMIT OUTCOME',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomePicker(String current, Function(String) onSelected) {
    final outcomes = [
      {
        'val': 'interested',
        'icon': Icons.thumb_up_outlined,
        'color': PremiumUI.secondary
      },
      {
        'val': 'call_later',
        'icon': Icons.more_time,
        'color': PremiumUI.warning
      },
      {
        'val': 'not_interested',
        'icon': Icons.thumb_down_outlined,
        'color': PremiumUI.danger
      },
      {
        'val': 'not_reachable',
        'icon': Icons.phone_disabled,
        'color': PremiumUI.muted
      },
      {
        'val': 'wrong_lead',
        'icon': Icons.error_outline,
        'color': PremiumUI.danger
      },
      {
        'val': 'visit_scheduled',
        'icon': Icons.calendar_today,
        'color': PremiumUI.accent
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: outcomes.map((o) {
        final isSelected = current == o['val'];
        final color = o['color'] as Color;
        return InkWell(
          onTap: () => onSelected(o['val'] as String),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? color : Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(o['icon'] as IconData,
                    size: 16, color: isSelected ? color : Colors.white38),
                const SizedBox(width: 8),
                Text(
                  (o['val'] as String).replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                      color: isSelected ? color : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _submitOutcome(
      String leadId, String outcome, String notes) async {
    setState(() => _isLoading = true);
    final idempotencyKey = _uuid.v4();

    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final client = Supabase.instance.client;
        await client.functions.invoke('manage-caller-workflow', body: {
          'action': 'update_call_outcome',
          'idempotency_key': idempotencyKey,
          'lead_id': leadId,
          'outcome': outcome,
          'notes': notes,
          if (outcome == 'call_later')
            'next_followup_at':
                DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        });
        await _fetchLeads();
      } else {
        final updated =
            _trainingRuntime.updateCallerOutcome(leadId, outcome, notes: notes);
        if (!updated && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: outcome_update_failed')));
          setState(() => _isLoading = false);
          return;
        }
        await _fetchLeads();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: request_failed')));
        setState(() => _isLoading = false);
      }
    }
  }
}
