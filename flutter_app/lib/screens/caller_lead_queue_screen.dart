import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
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
            .order('call_priority', ascending: false)
            .order('created_at', ascending: true);

        setState(() {
          _leads = List<Map<String, dynamic>>.from(data);
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
      appBar: AppBar(title: const Text('Assigned Leads')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchLeads,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _leads.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _leadCard(_leads[index]),
            ),
          ),
    );
  }

  Widget _leadCard(Map<String, dynamic> lead) {
    final broker = lead['brokers_public']?['broker_alias'] ?? 'Direct';
    final company = lead['brokers_public']?['company_name'] ?? '';
    
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
                    Text(lead['alias'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Source: $broker ($company)', style: const TextStyle(fontSize: 11, color: Colors.white54)),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _initiateCall(lead['id']),
                    icon: const Icon(Icons.phone),
                    label: const Text('SECURE CALL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => _showOutcomeDialog(lead),
                  icon: const Icon(Icons.edit_note),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    Color color = Colors.grey;
    if (priority == 'high' || priority == 'urgent') color = Colors.red;
    if (priority == 'normal') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
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
