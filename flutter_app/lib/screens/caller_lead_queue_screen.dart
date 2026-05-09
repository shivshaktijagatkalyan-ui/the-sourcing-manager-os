import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isSupabaseConfigured) {
      _trainingRuntime.addListener(_handleTrainingUpdate);
    }
    _fetchLeads();
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
      _fetchLeads();
    }
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser!.id;
        
        final data = await client
            .from('leads_public')
            .select('*, brokers_public(broker_alias, company_name)')
            .eq('assigned_caller_id', userId)
            .order('call_priority', ascending: false); // Basic fetch, we will smart-sort in memory

        final now = DateTime.now();
        final sortedLeads = List<Map<String, dynamic>>.from(data);
        
        // Smart Sort: 
        // 1. Callbacks Due (callback_at <= now)
        // 2. High Priority New Leads
        // 3. Normal Priority New Leads
        // 4. Everything else
        sortedLeads.sort((a, b) {
          final aCallback = DateTime.tryParse(a['callback_at'] ?? '')?.toLocal();
          final bCallback = DateTime.tryParse(b['callback_at'] ?? '')?.toLocal();
          final aIsDue = aCallback != null && aCallback.isBefore(now);
          final bIsDue = bCallback != null && bCallback.isBefore(now);

          if (aIsDue && !bIsDue) return -1;
          if (!aIsDue && bIsDue) return 1;
          
          if (a['call_priority'] == 'high' && b['call_priority'] != 'high') return -1;
          if (a['call_priority'] != 'high' && b['call_priority'] == 'high') return 1;

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
          _leads = _trainingRuntime.callerAssignedLeads(TrainingRuntime.callerRahulId);
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
        title: Text('Assigned Leads', style: PremiumUI.h1.copyWith(fontSize: 20)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchLeads,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumUI.sectionShell(
                  title: 'Caller Queue',
                  subtitle: 'Assigned leads only. Number screen par kabhi nahi dikhega.',
                  accentColor: PremiumUI.secondary,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Secure Call ke baad outcome update karo. Interested lead turant sourcing manager ke action bucket mein jayega.',
                          style: PremiumUI.subtitle.copyWith(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PremiumUI.statusBadge('${_leads.length} assigned', PremiumUI.accent),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._leads.map((lead) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _leadCard(lead),
                    )),
              ],
            ),
          ),
    );
  }

  Widget _leadCard(Map<String, dynamic> lead) {
    final broker = lead['brokers_public']?['broker_alias'] ?? 'Direct';
    final company = lead['brokers_public']?['company_name'] ?? '';
    
    final outcome = (lead['last_call_outcome'] ?? lead['lead_status'] ?? 'pending').toString();

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
                    Text(lead['alias'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Source Broker: $broker${company.isEmpty ? '' : ' • $company'}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
                _priorityBadge(lead['call_priority'] ?? 'normal'),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.white38),
                const SizedBox(width: 8),
                Text(lead['area'] ?? 'N/A', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.currency_rupee, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text('${(lead['budget_min'] ?? 0) ~/ 100000}L - ${(lead['budget_max'] ?? 0) ~/ 100000}L', style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PremiumUI.statusBadge((lead['lead_status'] ?? 'new').toString(), PremiumUI.statusColor((lead['lead_status'] ?? 'new').toString())),
                PremiumUI.statusBadge(outcome.replaceAll('_', ' '), PremiumUI.statusColor(outcome)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _initiateCall(lead['id']),
                    icon: const Icon(Icons.phone),
                    label: const Text('SECURE CALL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumUI.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => _showOutcomeDialog(lead),
                  icon: const Icon(Icons.edit_note),
                  tooltip: 'Update outcome',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    return PremiumUI.statusBadge(priority, PremiumUI.statusColor(priority));
  }

  Future<void> _initiateCall(String leadId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CallStatusDialog(leadId: leadId, targetType: 'lead'),
    );
  }

  void _showOutcomeDialog(Map<String, dynamic> lead) {
    final notesController = TextEditingController();
    String outcome = 'interested';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Call Outcome: ${lead['alias']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: outcome,
                items: [
                  'interested',
                  'not_interested',
                  'call_later',
                  'not_reachable',
                  'wrong_lead',
                  'visit_scheduled',
                  'budget_mismatch',
                  'location_mismatch',
                ].map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase()))).toList(),
                onChanged: (val) => setDialogState(() => outcome = val!),
                decoration: const InputDecoration(labelText: 'Outcome'),
              ),
              if (outcome == 'call_later')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    title: const Text('Callback Time', style: TextStyle(fontSize: 12)),
                    subtitle: const Text('Default: 2 hours later', style: TextStyle(fontSize: 10)),
                    trailing: const Icon(Icons.calendar_today, size: 16),
                    onTap: () {
                      // In a real app, show a time picker. For pilot, we default to +2 hours.
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Callback set for 2 hours from now.')));
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Call Notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () => _submitOutcome(lead['id'], outcome, notesController.text),
              child: const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOutcome(String leadId, String outcome, String notes) async {
    Navigator.pop(context); // Close dialog
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        await client.functions.invoke('manage-caller-workflow', body: {
          'action': 'update_call_outcome',
          'lead_id': leadId,
          'outcome': outcome,
          'notes': notes,
          if (outcome == 'call_later') 'next_followup_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        });
        await _fetchLeads();
      } else {
        final updated = _trainingRuntime.updateCallerOutcome(leadId, outcome, notes: notes);
        if (!updated && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: outcome_update_failed')),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: request_failed')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
