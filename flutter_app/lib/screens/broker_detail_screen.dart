import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'add_lead_from_broker.dart';

class BrokerDetailScreen extends StatefulWidget {
  final String brokerId;
  const BrokerDetailScreen({super.key, required this.brokerId});

  @override
  State<BrokerDetailScreen> createState() => _BrokerDetailScreenState();
}

class _BrokerDetailScreenState extends State<BrokerDetailScreen> {
  final TrainingRuntime _trainingRuntime = TrainingRuntime.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _brokerData;
  Map<String, dynamic>? _activationData;
  List<Map<String, dynamic>> _activityLogs = [];
  List<Map<String, dynamic>> _recentLeads = [];
  List<Map<String, dynamic>> _availableCallers = [];
  int _leadCount = 0;
  int _visitCount = 0;

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
    if (!AppConfig.isSupabaseConfigured) {
      _trainingRuntime.addListener(_handleTrainingUpdate);
    }
    _loadAllData();
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
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        // 1. Fetch Broker Metadata
        final broker = await client
            .from('brokers_public')
            .select('*')
            .eq('id', widget.brokerId)
            .single();
            
        // 2. Fetch Activation Stage
        final activation = await client
            .from('broker_activations')
            .select('*')
            .eq('broker_id', widget.brokerId)
            .maybeSingle();
            
        // 3. Fetch Activity Logs
        final logs = await client
            .from('broker_activity_logs')
            .select('*')
            .eq('broker_id', widget.brokerId)
            .order('created_at', ascending: false)
            .limit(20);
            
        // 4. Fetch Counts
        final leadsResponse = await client
            .from('leads_public')
            .select('id')
            .eq('source_broker_id', widget.brokerId);
            
        final recentLeads = await client
            .from('leads_public')
            .select('*')
            .eq('source_broker_id', widget.brokerId)
            .order('created_at', ascending: false)
            .limit(5);
            
        final visitsResponse = await client
            .from('site_visits')
            .select('id')
            .eq('source_broker_id', widget.brokerId);

        final orgId = broker['organization_id']?.toString();
        List<Map<String, dynamic>> callers = [];
        if (orgId != null && orgId.isNotEmpty) {
          final response = await client.rpc('get_organization_callers', params: {'p_org_id': orgId});
          if (response != null) {
            callers = List<Map<String, dynamic>>.from(response);
          }
        }

        setState(() {
          _brokerData = broker;
          _activationData = activation;
          _activityLogs = List<Map<String, dynamic>>.from(logs);
          _recentLeads = List<Map<String, dynamic>>.from(recentLeads);
          _leadCount = leadsResponse.length;
          _visitCount = visitsResponse.length;
          _availableCallers = List<Map<String, dynamic>>.from(callers);
          _isLoading = false;
        });
      } else {
        // Demo Data
        await Future.delayed(const Duration(milliseconds: 250));
        setState(() {
          _brokerData = _trainingRuntime.brokerById(widget.brokerId);
          _activationData = _trainingRuntime.activationByBrokerId(widget.brokerId);
          _activityLogs = _trainingRuntime.activityLogsForBroker(widget.brokerId);
          _recentLeads = _trainingRuntime.recentLeadsForBroker(widget.brokerId);
          _leadCount = _trainingRuntime.leadCountForBroker(widget.brokerId);
          _visitCount = _trainingRuntime.visitCountForBroker(widget.brokerId);
          _availableCallers = _trainingRuntime.activeCallersForOrganization(
            _brokerData?['organization_id']?.toString() ?? TrainingRuntime.organizationId,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading broker: request_failed')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStage(String newStage) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        // Need Org ID
        final pilot = await client.from('pilot_users').select('org_id').eq('user_id', client.auth.currentUser!.id).single();
        
        await client.functions.invoke('manage-external-broker', body: {
          'action': 'update_activation_stage',
          'organization_id': pilot['org_id'],
          'broker_id': widget.brokerId,
          'project_id': '00000000-0000-0000-0000-000000000000', // Default Project Placeholder or real ID
          'stage': newStage,
          'notes': 'Stage updated to ${newStage.replaceAll('_', ' ')}'
        });
        
        await _loadAllData();
      } else {
        final updated = _trainingRuntime.updateBrokerActivationStage(widget.brokerId, newStage);
        if (!updated && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update failed: request_failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update failed: request_failed')),
        );
      }
    }
  }

  Future<void> _initiateCall() async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        await client.functions.invoke('initiate-broker-call', body: {'broker_id': widget.brokerId});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secure call bridge initiated...')));
      } else {
        final result = await _trainingRuntime.initiateCall(widget.brokerId, type: 'broker');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['ok'] == true ? 'Secure call bridge initiated...' : 'Call failed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_brokerData == null) return const Scaffold(body: Center(child: Text('Broker not found')));

    final broker = _brokerData!;
    final currentStage = _activationData?['activation_stage'] ?? 'not_contacted';

    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(title: Text(broker['broker_alias'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(broker),
            _statsRow(),
            _pipelineSection(currentStage),
            _actionsSection(),
            _leadsSection(),
            _timelineSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _leadsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), border: Border.symmetric(horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECENT LEADS GIVEN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddLeadFromBrokerScreen(
                    sourceBrokerId: widget.brokerId,
                    sourceBrokerAlias: _brokerData!['broker_alias'],
                  ))).then((_) => _loadAllData());
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('ADD LEAD', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentLeads.isEmpty)
            const Text('No leads received from this broker yet.', style: TextStyle(fontSize: 12, color: Colors.white24))
          else
            ..._recentLeads.map((lead) => _leadTile(lead)),
        ],
      ),
    );
  }

  Widget _leadTile(Map<String, dynamic> lead) {
    final visitReady = _canScheduleVisit(lead);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showLeadActions(lead),
        child: Row(
          children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _safeLeadAlias(lead),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('${lead['area'] ?? '-'} • ₹${lead['budget_max'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
            if (lead['assigned_caller_id'] != null)
              const Icon(Icons.person_outline, size: 14, color: Colors.blue)
            else
              const Icon(Icons.person_add_outlined, size: 14, color: Colors.white24),
            if (visitReady) ...[
              const SizedBox(width: 8),
              const Icon(Icons.event_available, size: 14, color: Colors.orange),
            ],
            const SizedBox(width: 8),
            _chip(lead['lead_status'] ?? 'unknown', Colors.white24),
          ],
        ),
      ),
    );
  }

  void _showLeadActions(Map<String, dynamic> lead) {
    final canSchedule = _canScheduleVisit(lead);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lead Actions: ${_safeLeadAlias(lead)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canSchedule)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Schedule Site Visit'),
                subtitle: const Text('Interested lead can move to field verification.'),
                onTap: () async {
                  Navigator.pop(context);
                  await _scheduleSiteVisitFromLead(lead);
                },
              ),
            if (canSchedule && _availableCallers.isNotEmpty) const Divider(),
            if (_availableCallers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No callers found in organization.'),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Assign to Caller', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ..._availableCallers.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${c['full_name']}'),
                    onTap: () => _assignLead('${lead['id']}', '${c['user_id']}'),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _assignLead(String leadId, String callerId) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        await client.functions.invoke('manage-caller-workflow', body: {
          'action': 'assign_lead_to_caller',
          'lead_id': leadId,
          'caller_id': callerId,
        });
        await _loadAllData();
      } else {
        final assigned = _trainingRuntime.assignLeadToCaller(leadId, callerId);
        if (!assigned && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: caller_not_authorized')),
          );
          setState(() => _isLoading = false);
          return;
        }
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

  bool _canScheduleVisit(Map<String, dynamic> lead) {
    final lastOutcome = '${lead['last_call_outcome'] ?? ''}';
    final status = '${lead['lead_status'] ?? ''}';
    return lastOutcome == 'interested' || status == 'interested';
  }

  Future<void> _scheduleSiteVisitFromLead(Map<String, dynamic> lead) async {
    final scheduledAt = await _pickScheduleDateTime();
    if (scheduledAt == null) return;

    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final pilot = await client
            .from('pilot_users')
            .select('org_id')
            .eq('user_id', client.auth.currentUser!.id)
            .single();

        final projectId = lead['project_id'] ?? _activationData?['project_id'];
        if (projectId == null) {
          throw Exception('missing_project_id');
        }

        await client.functions.invoke('lead-from-broker', body: {
          'action': 'schedule_visit_from_lead',
          'organization_id': pilot['org_id'],
          'lead_id': lead['id'],
          'source_broker_id': lead['source_broker_id'] ?? widget.brokerId,
          'project_id': projectId,
          'scheduled_at': scheduledAt.toIso8601String(),
        });
        await _loadAllData();
      } else {
        final scheduled = _trainingRuntime.scheduleSiteVisitFromLead(
          '${lead['id']}',
          scheduledAt: scheduledAt,
        );
        if (!scheduled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: schedule_failed')),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to schedule: request_failed')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<DateTime?> _pickScheduleDateTime() async {
    final initial = DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;

    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 11, minute: 0),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showLogActivityDialog() {
    final noteController = TextEditingController();
    String type = 'note_added';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log Activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: [
                  'note_added', 'call_connected', 'project_pitch', 
                  'inventory_shared', 'offer_shared', 'meeting_scheduled'
                ].map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('_', ' ').toUpperCase()))).toList(),
                onChanged: (v) => setDialogState(() => type = v!),
                decoration: const InputDecoration(labelText: 'Activity Type'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Safe Notes',
                  helperText: 'Number screen par kabhi nahi dikhega',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logActivity(type, noteController.text);
              },
              child: const Text('Save Activity'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logActivity(String type, String notes) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final pilot = await client.from('pilot_users').select('org_id').eq('user_id', client.auth.currentUser!.id).single();
        
        await client.functions.invoke('manage-external-broker', body: {
          'action': 'log_activity',
          'organization_id': pilot['org_id'],
          'broker_id': widget.brokerId,
          'activity_type': type,
          'notes': notes,
        });
        await _loadAllData();
      } else {
        final logged = _trainingRuntime.logBrokerActivity(widget.brokerId, type, notes);
        if (!logged && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to log: request_failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log: request_failed')),
        );
      }
    }
  }

  void _showFollowupDialog() {
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Follow-up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Due Date'),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: priority,
                items: ['low', 'normal', 'high', 'urgent'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                onChanged: (v) => setDialogState(() => priority = v!),
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _createFollowup(selectedDate, noteController.text, priority);
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFollowup(DateTime due, String reason, String priority) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final pilot = await client.from('pilot_users').select('org_id').eq('user_id', client.auth.currentUser!.id).single();
        
        await client.functions.invoke('manage-external-broker', body: {
          'action': 'create_followup',
          'organization_id': pilot['org_id'],
          'broker_id': widget.brokerId,
          'due_at': due.toIso8601String(),
          'reason': reason,
          'priority': priority,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow-up scheduled.')));
      } else {
        final created = _trainingRuntime.createBrokerFollowup(
          brokerId: widget.brokerId,
          dueAt: due,
          reason: reason,
          priority: priority,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(created ? 'Follow-up scheduled.' : 'Failed to schedule: request_failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to schedule: request_failed')),
        );
      }
    }
  }

  Widget _header(Map<String, dynamic> broker) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF6366F1),
            child: Text(broker['broker_alias'][0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Text(broker['broker_alias'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (broker['company_name'] != null)
            Text(broker['company_name'], style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip(broker['category'] ?? 'new', Colors.blue),
              const SizedBox(width: 8),
              _chip(broker['area'] ?? 'Unknown', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: const Color(0xFF0F172A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat('Leads', _leadCount.toString()),
          _stat('Visits', _visitCount.toString()),
          _stat('Score', '85%'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1)),
      ],
    );
  }

  Widget _pipelineSection(String currentStage) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACTIVATION PIPELINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _stages.map((s) {
                final isCompleted = _stages.indexOf(s) <= _stages.indexOf(currentStage);
                final isCurrent = s == currentStage;
                return GestureDetector(
                  onTap: () => _updateStage(s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF6366F1) : (isCompleted ? const Color(0xFF6366F1).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isCurrent ? const Color(0xFF6366F1) : (isCompleted ? const Color(0xFF6366F1).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1))),
                    ),
                    child: Text(s.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 10, color: isCurrent || isCompleted ? Colors.white : Colors.white24, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT ACTIONS', style: PremiumUI.subtitle.copyWith(color: Colors.white, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _initiateCall,
                  icon: const Icon(Icons.call),
                  label: const Text('SECURE CALL'),
                  style: ElevatedButton.styleFrom(backgroundColor: PremiumUI.secondary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _showLogActivityDialog,
                icon: const Icon(Icons.note_add_outlined),
                tooltip: 'Log Activity',
                padding: const EdgeInsets.all(16),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _showFollowupDialog,
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Set Follow-up',
                padding: const EdgeInsets.all(16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Secure Call, activity logging, aur follow-up automation se broker pipeline deterministic rahegi.',
            style: PremiumUI.subtitle.copyWith(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _timelineSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACTIVITY TIMELINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          if (_activityLogs.isEmpty)
            const Text('No activities logged yet.', style: TextStyle(color: Colors.white24))
          else
            ..._activityLogs.map((log) => _timelineItem(log)),
        ],
      ),
    );
  }

  Widget _timelineItem(Map<String, dynamic> log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const Icon(Icons.circle, size: 12, color: Color(0xFF6366F1)),
              Container(width: 2, height: 40, color: Colors.white10),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log['activity_type'].toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(_formatDate(log['created_at']), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(log['notes_safe'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.parse(iso);
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _safeLeadAlias(Map<String, dynamic> lead) {
    final alias = lead['alias'] ?? lead['lead_alias'];
    if (alias == null || alias.toString().trim().isEmpty) return 'Lead';
    return alias.toString();
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
