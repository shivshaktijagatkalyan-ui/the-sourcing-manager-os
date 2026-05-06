import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'caller_lead_queue_screen.dart';

class CallerDashboardScreen extends StatefulWidget {
  const CallerDashboardScreen({super.key});

  @override
  State<CallerDashboardScreen> createState() => _CallerDashboardScreenState();
}

class _CallerDashboardScreenState extends State<CallerDashboardScreen> {
  final TrainingRuntime _trainingRuntime = TrainingRuntime.instance;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _assignedLeads = [];

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isSupabaseConfigured) {
      _trainingRuntime.addListener(_handleTrainingUpdate);
    }
    _fetchStats();
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
      _fetchStats();
    }
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser!.id;
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

        final pending = await client.from('leads_public').select('id').eq('assigned_caller_id', userId).eq('lead_status', 'new');
        final completedToday = await client.from('call_attempts').select('id').eq('caller_id', userId).gte('created_at', startOfDay);
        final interested = await client.from('leads_public').select('id').eq('assigned_caller_id', userId).eq('last_call_outcome', 'interested');
        final callLater = await client.from('leads_public').select('id').eq('assigned_caller_id', userId).eq('last_call_outcome', 'call_later');
        final visitScheduled = await client.from('leads_public').select('id').eq('assigned_caller_id', userId).eq('lead_status', 'visit_scheduled');

        final leads = await client
            .from('leads_public')
            .select('id, alias, area, city, property_name, lead_status, last_call_outcome, budget_min, budget_max, brokers_public(broker_alias, company_name)')
            .eq('assigned_caller_id', userId)
            .limit(5);

        setState(() {
          _stats = {
            'pending_calls': pending.length,
            'completed_today': completedToday.length,
            'interested_leads': interested.length,
            'call_later': callLater.length,
            'visit_scheduled': visitScheduled.length,
            'assigned_today': pending.length + completedToday.length,
          };
          _assignedLeads = List<Map<String, dynamic>>.from(leads);
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _stats = _trainingRuntime.callerDashboardStats(TrainingRuntime.callerRahulId);
          _assignedLeads = _trainingRuntime.callerAssignedLeads(TrainingRuntime.callerRahulId).map((lead) {
            final budgetMin = (lead['budget_min'] ?? 0) as num;
            final budgetMax = (lead['budget_max'] ?? 0) as num;
            return {
              ...lead,
              'source': lead['brokers_public']?['company_name'] ?? 'JSN Enterprise',
              'project': lead['property_name'] ?? 'The Wadhwa Wise City',
              'budget': '₹${(budgetMin / 100000).toStringAsFixed(0)}L–₹${(budgetMax / 100000).toStringAsFixed(0)}L',
              'status': lead['lead_status'],
            };
          }).toList();
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
        title: Text('CALLER WORKSPACE', style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _buildStatusBadge('AGENT_SECURE', PremiumUI.accent),
          IconButton(onPressed: _fetchStats, icon: const Icon(Icons.refresh, size: 20)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),
                    _buildKPIGrid(),
                    const SizedBox(height: 32),
                    PremiumUI.sectionShell(
                      title: 'Today\'s Call Queue',
                      subtitle: 'Assigned leads only. Secure Call never shows the number.',
                      accentColor: PremiumUI.accent,
                      child: _buildQueueSummary(),
                    ),
                    const SizedBox(height: 24),
                    _buildMainActionButton(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('TODAY\'S ASSIGNED LEADS'),
                    const SizedBox(height: 12),
                    ..._assignedLeads.map((l) => _buildLeadCard(l)),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello, Rahul', style: PremiumUI.h1),
        const SizedBox(height: 4),
        Text('You have ${_stats['pending_calls']} calls pending for today.', style: PremiumUI.subtitle),
      ],
    );
  }

  Widget _buildKPIGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _miniKPI('Assigned', '${_stats['assigned_today'] ?? 0}', PremiumUI.accent),
        _miniKPI('Pending', _stats['pending_calls'].toString(), PremiumUI.warning),
        _miniKPI('Completed', _stats['completed_today'].toString(), PremiumUI.secondary),
        _miniKPI('Interested', _stats['interested_leads'].toString(), PremiumUI.hot),
        _miniKPI('Call Later', _stats['call_later'].toString(), PremiumUI.warning),
        _miniKPI('Visit Scheduled', '${_stats['visit_scheduled'] ?? 0}', PremiumUI.secondary),
      ],
    );
  }

  Widget _buildQueueSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Pending Calls', '${_stats['pending_calls'] ?? 0}', PremiumUI.warning),
        _summaryRow('Interested Leads', '${_stats['interested_leads'] ?? 0}', PremiumUI.hot),
        _summaryRow('Call Later Follow-ups', '${_stats['call_later'] ?? 0}', PremiumUI.accent),
        _summaryRow('Visit Scheduled Leads', '${_stats['visit_scheduled'] ?? 0}', PremiumUI.secondary),
      ],
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          PremiumUI.statusBadge(value, color),
        ],
      ),
    );
  }

  Widget _miniKPI(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: PremiumUI.glassBox(color: color, opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: PremiumUI.h1.copyWith(fontSize: 22, color: color)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: PremiumUI.subtitle.copyWith(fontSize: 9, color: Colors.white70, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildMainActionButton() {
    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (c) => const CallerLeadQueueScreen()));
        await _fetchStats();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [PremiumUI.secondary, PremiumUI.secondary.withValues(alpha: 0.7)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: PremiumUI.secondary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_in_talk, color: Colors.white),
              const SizedBox(width: 12),
              Text('START CALLING QUEUE', style: PremiumUI.h1.copyWith(fontSize: 14, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> l) {
    final source = l['source'] ??
        ((l['brokers_public'] is Map<String, dynamic>)
            ? ((l['brokers_public']['company_name'] ?? l['brokers_public']['broker_alias'])?.toString())
            : 'Assigned broker');
    final project = l['project'] ?? l['property_name'] ?? 'Wadhwa Wise City';
    final budget = l['budget'] ??
        '₹${(((l['budget_min'] ?? 0) as num) / 100000).toStringAsFixed(0)}L–₹${(((l['budget_max'] ?? 0) as num) / 100000).toStringAsFixed(0)}L';
    final status = l['status'] ?? l['lead_status'] ?? 'new';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: PremiumUI.glassBox(color: PremiumUI.accent, opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l['alias'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              _buildStatusBadge(status.toString(), PremiumUI.statusColor(status.toString())),
            ],
          ),
          const SizedBox(height: 12),
          Text('Project: $project', style: PremiumUI.subtitle.copyWith(color: Colors.white70, fontSize: 11)),
          Text('Source Broker: ${source ?? 'Assigned broker'}', style: PremiumUI.subtitle.copyWith(fontSize: 10)),
          const SizedBox(height: 12),
          Row(
            children: [
              _leadMeta(Icons.location_on, l['area']),
              const SizedBox(width: 16),
              _leadMeta(Icons.payments, budget),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (c) => const CallerLeadQueueScreen()));
                  await _fetchStats();
                },
                icon: const Icon(Icons.call, size: 16, color: PremiumUI.secondary),
                label: const Text('SECURE CALL', style: TextStyle(color: PremiumUI.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leadMeta(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text, style: PremiumUI.subtitle.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: PremiumUI.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: PremiumUI.subtitle.copyWith(color: Colors.white, letterSpacing: 1.5, fontSize: 11)),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text.toUpperCase(), style: PremiumUI.subtitle.copyWith(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}
