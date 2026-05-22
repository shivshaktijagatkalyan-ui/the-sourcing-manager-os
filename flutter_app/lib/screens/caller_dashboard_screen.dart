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
    if (!AppConfig.isSupabaseConfigured || AppConfig.isTrainingMode) {
      _trainingRuntime.addListener(_handleTrainingUpdate);
    }
    _fetchStats();
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
      _fetchStats();
    }
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser!.id;
        final today = DateTime.now();
        final startOfDay =
            DateTime(today.year, today.month, today.day).toIso8601String();

        final pending = await client
            .from('leads_public')
            .select('id')
            .eq('assigned_caller_id', userId)
            .eq('lead_status', 'new');
        final completedToday = await client
            .from('call_attempts')
            .select('id')
            .eq('caller_id', userId)
            .gte('created_at', startOfDay);
        final interested = await client
            .from('leads_public')
            .select('id')
            .eq('assigned_caller_id', userId)
            .eq('last_call_outcome', 'interested');
        final callLater = await client
            .from('leads_public')
            .select('id')
            .eq('assigned_caller_id', userId)
            .eq('last_call_outcome', 'call_later');
        final visitScheduled = await client
            .from('leads_public')
            .select('id')
            .eq('assigned_caller_id', userId)
            .eq('lead_status', 'visit_scheduled');

        final leads = await client
            .from('leads_public')
            .select(
                'id, alias, area, city, property_name, lead_status, last_call_outcome, budget_min, budget_max, brokers_public(broker_alias, company_name)')
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: PremiumUI.danger));
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
          ? const Center(child: CircularProgressIndicator(color: PremiumUI.primary))
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),
                    _buildPerformancePulse(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('TODAY\'S KPI'),
                    const SizedBox(height: 12),
                    _buildKPIGrid(),
                    const SizedBox(height: 32),
                    _buildMainActionButton(),
                    const SizedBox(height: 32),
                    PremiumUI.sectionShell(
                      title: 'Secure Call Queue',
                      subtitle: 'Numbers are encrypted. Click SECURE CALL to start.',
                      accentColor: PremiumUI.accent,
                      child: _buildQueueSummary(),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle('LATEST ASSIGNMENTS'),
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
        Text('Ready for today\'s secure calling session.', style: PremiumUI.subtitle),
      ],
    );
  }

  Widget _buildPerformancePulse() {
    final callsDone = _stats['completed_today'] ?? 0;
    final total = _stats['assigned_today'] ?? 10;
    final progress = total > 0 ? (callsDone / total).clamp(0.0, 1.0) : 0.0;

    return PremiumUI.glassCard(
      color: PremiumUI.secondary,
      opacity: 0.08,
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress.toDouble(),
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  color: PremiumUI.secondary,
                ),
              ),
              const Icon(Icons.flash_on, color: PremiumUI.secondary, size: 24),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DAILY SPEED', style: TextStyle(color: PremiumUI.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('$callsDone / $total Calls Done', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(progress > 0.8 ? 'Excellent speed!' : 'Keep pushing to reach target.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
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
        _miniKPI('Interested', _stats['interested_leads'].toString(), PremiumUI.hot),
        _miniKPI('Visit Done', '${_stats['visit_scheduled'] ?? 0}', PremiumUI.secondary),
      ],
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
          Text(label.toUpperCase(), style: PremiumUI.subtitle.copyWith(fontSize: 9, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildQueueSummary() {
    return Column(
      children: [
        _summaryRow('Pending Calls', '${_stats['pending_calls'] ?? 0}', PremiumUI.warning),
        _summaryRow('Interested Leads', '${_stats['interested_leads'] ?? 0}', PremiumUI.hot),
        _summaryRow('Follow-ups', '${_stats['call_later'] ?? 0}', PremiumUI.accent),
      ],
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))),
          PremiumUI.statusBadge(value, color),
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
        height: 64,
        decoration: BoxDecoration(
          color: PremiumUI.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: PremiumUI.accent.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_in_talk, color: Colors.black, size: 28),
              const SizedBox(width: 16),
              Text('ENTER SECURE QUEUE', style: PremiumUI.h1.copyWith(fontSize: 16, color: Colors.black, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> l) {
    final status = l['status'] ?? l['lead_status'] ?? 'new';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: PremiumUI.glassCard(
        opacity: 0.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l['alias'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                PremiumUI.statusBadge(status.toString(), PremiumUI.statusColor(status.toString())),
              ],
            ),
            const SizedBox(height: 12),
            Text('Project: ${l['project'] ?? l['property_name'] ?? 'Wadhwa Wise City'}', style: const TextStyle(color: PremiumUI.muted, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (c) => const CallerLeadQueueScreen()));
                    await _fetchStats();
                  },
                  icon: const Icon(Icons.call, size: 18, color: PremiumUI.secondary),
                  label: const Text('SECURE CALL', style: TextStyle(color: PremiumUI.secondary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
