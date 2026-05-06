import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'activation_pipeline_board.dart';
import 'broker_followup_queue.dart';
import 'add_broker_screen.dart';
import 'add_lead_from_broker.dart';
import 'site_visit_list.dart';
import 'broker_review_list.dart';


class SourcingManagerDashboard extends StatefulWidget {
  const SourcingManagerDashboard({super.key});

  @override
  State<SourcingManagerDashboard> createState() => _SourcingManagerDashboardState();
}

class _SourcingManagerDashboardState extends State<SourcingManagerDashboard> {
  final TrainingRuntime _trainingRuntime = TrainingRuntime.instance;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topBrokers = [];
  List<Map<String, dynamic>> _followups = [];
  List<Map<String, dynamic>> _interestedLeads = [];
  List<Map<String, dynamic>> _scheduledVisits = [];

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
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
        final startOfMonth = DateTime(today.year, today.month, 1).toIso8601String();
        final last7Days = today.subtract(const Duration(days: 7)).toIso8601String();

        final followups = await client.from('broker_followups').select('id').eq('assigned_to', userId).eq('status', 'pending').gte('due_at', startOfDay).lte('due_at', endOfDay);
        final followupRows = await client
            .from('broker_followups')
            .select('id, title, due_at, brokers_public(broker_alias, company_name)')
            .eq('assigned_to', userId)
            .eq('status', 'pending')
            .gte('due_at', startOfDay)
            .lte('due_at', endOfDay)
            .order('due_at')
            .limit(5);
        final activeBrokers = await client.from('brokers_public').select('id').eq('assigned_sourcing_manager_id', userId).eq('category', 'active');
        final hotBrokers = await client.from('brokers_public').select('id').eq('assigned_sourcing_manager_id', userId).eq('category', 'hot');
        final newBrokers = await client.from('brokers_public').select('id').eq('assigned_sourcing_manager_id', userId).gte('created_at', last7Days);
        final leads = await client.from('leads_public').select('id').eq('assigned_sourcing_manager_id', userId).gte('created_at', startOfMonth);
        final verifiedVisits = await client.from('site_visits').select('id').eq('sourcing_manager_id', userId).eq('status', 'completed').gte('created_at', startOfMonth);
        final leadsAssignedToCaller = await client.from('leads_public').select('id, alias, area, city, lead_status, assigned_caller_id').eq('assigned_sourcing_manager_id', userId).gte('created_at', startOfMonth).not('assigned_caller_id', 'is', null).limit(5);
        final interestedLeads = await client.from('leads_public').select('id, alias, area, city, lead_status').eq('assigned_sourcing_manager_id', userId).eq('last_call_outcome', 'interested').gte('created_at', startOfMonth).limit(5);
        final scheduledVisits = await client.from('site_visits').select('id, lead_id, property_name, area, city, visit_date, status').eq('sourcing_manager_id', userId).eq('status', 'scheduled').gte('created_at', startOfMonth).limit(5);
        final topBrokers = await client.from('brokers_public').select('id, broker_name, company_name, area, city').eq('assigned_sourcing_manager_id', userId).eq('category', 'active').order('created_at', ascending: false).limit(5);

        setState(() {
          _stats = {
            'followups_today': followups.length,
            'hot_brokers': hotBrokers.length,
            'active_brokers': activeBrokers.length,
            'new_brokers': newBrokers.length,
            'leads_this_month': leads.length,
            'leads_assigned_to_caller': leadsAssignedToCaller.length,
            'interested_leads': interestedLeads.length,
            'site_visits_scheduled': scheduledVisits.length,
            'verified_visits_this_month': verifiedVisits.length,
            'monthly_performance': '94%',
            'top_broker': topBrokers.isNotEmpty ? (topBrokers.first['broker_name'] ?? topBrokers.first['company_name'] ?? 'Not available') : 'Not available',
          };
          _topBrokers = List<Map<String, dynamic>>.from(topBrokers);
          _followups = List<Map<String, dynamic>>.from(followupRows);
          _interestedLeads = List<Map<String, dynamic>>.from(interestedLeads);
          _scheduledVisits = List<Map<String, dynamic>>.from(scheduledVisits);
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _stats = _trainingRuntime.sourcingManagerStats();
          _topBrokers = _trainingRuntime.topBrokersForManager(TrainingRuntime.sourcingManagerId);
          _followups = _trainingRuntime.followupsForManager(TrainingRuntime.sourcingManagerId);
          _interestedLeads = _trainingRuntime.interestedLeadsForManager(TrainingRuntime.sourcingManagerId);
          _scheduledVisits = _trainingRuntime.siteVisitsForManager(TrainingRuntime.sourcingManagerId);
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
        title: Text('SOURCING MANAGER HUB', style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _buildStatusBadge('SECURE_SESSION', PremiumUI.secondary),
          IconButton(onPressed: _fetchStats, icon: const Icon(Icons.refresh, size: 20)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeHeader(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('TODAY\'S PRIORITIES'),
                      const SizedBox(height: 12),
                      _buildHinglishHelp('Aaj follow-up due hai. Broker ko secure call karein. Number screen par kabhi nahi dikhega.'),
                      const SizedBox(height: 16),
                      _buildKPIGrid(),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'Today\'s Follow-up Queue',
                        subtitle: 'Aaj ka pending broker work',
                        accentColor: PremiumUI.warning,
                        child: _buildFollowupQueue(),
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('ACTIVATION PIPELINE'),
                      const SizedBox(height: 12),
                      _buildPipelineSummary(),
                      const SizedBox(height: 32),
                      _buildSectionTitle('LEAD PERFORMANCE'),
                      const SizedBox(height: 12),
                      _buildLeadPerformanceGrid(),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'Interested Leads Needing Action',
                        subtitle: 'Call outcome se site visit tak ka next step',
                        accentColor: PremiumUI.hot,
                        child: _buildInterestedLeadList(),
                      ),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'Site Visit Tracker',
                        subtitle: 'Scheduled and field-ready visits',
                        accentColor: PremiumUI.accent,
                        child: _buildSiteVisitList(),
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('TOP PERFORMING BROKERS'),
                      const SizedBox(height: 12),
                      _buildTopBrokersTable(),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'My Monthly Performance',
                        subtitle: 'What is pending, blocked, and verified this month',
                        accentColor: PremiumUI.primary,
                        child: _buildMonthlyPerformance(),
                      ),
                      const SizedBox(height: 32),
                      _buildQuickActionGrid(),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Good Morning, Vinod', style: PremiumUI.h1),
        const SizedBox(height: 4),
        Text('Project: The Wadhwa Wise City, Panvel', style: PremiumUI.subtitle.copyWith(color: PremiumUI.primary)),
      ],
    );
  }

  Widget _buildHinglishHelp(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumUI.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PremiumUI.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: PremiumUI.primary, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: PremiumUI.subtitle.copyWith(color: Colors.white70, fontSize: 11))),
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
        _miniKPI('Follow-ups', _stats['followups_today'].toString(), PremiumUI.warning),
        _miniKPI('Hot Brokers', _stats['hot_brokers'].toString(), PremiumUI.hot),
        _miniKPI('Active', _stats['active_brokers'].toString(), PremiumUI.primary),
        _miniKPI('New (7d)', _stats['new_brokers'].toString(), PremiumUI.secondary),
      ],
    );
  }

  Widget _buildLeadPerformanceGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _miniKPI('Leads (M)', _stats['leads_this_month'].toString(), PremiumUI.primary),
        _miniKPI('Caller Asgn', _stats['leads_assigned_to_caller'].toString(), PremiumUI.accent),
        _miniKPI('Interested', _stats['interested_leads'].toString(), PremiumUI.hot),
        _miniKPI('Verified Visits', _stats['verified_visits_this_month'].toString(), PremiumUI.accent),
      ],
    );
  }

  Widget _buildFollowupQueue() {
    if (_followups.isEmpty) {
      return const Text('No follow-ups due right now.', style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _followups.map((followup) {
        final broker = followup['brokers_public'];
        final brokerLabel = broker is Map<String, dynamic>
            ? (broker['broker_alias'] ?? broker['company_name'] ?? 'Broker')
            : 'Broker';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PremiumUI.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.call_outlined, color: PremiumUI.warning, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      followup['title']?.toString() ?? 'Broker follow-up',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      brokerLabel.toString(),
                      style: const TextStyle(color: PremiumUI.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PremiumUI.statusBadge('Due', PremiumUI.warning),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInterestedLeadList() {
    if (_interestedLeads.isEmpty) {
      return const Text('No interested leads are waiting for action.', style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _interestedLeads.map((lead) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PremiumUI.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead['alias']?.toString() ?? 'Lead', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${lead['area'] ?? '-'}, ${lead['city'] ?? '-'}', style: const TextStyle(color: PremiumUI.muted, fontSize: 12)),
                  ],
                ),
              ),
              PremiumUI.statusBadge('Interested', PremiumUI.hot),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSiteVisitList() {
    if (_scheduledVisits.isEmpty) {
      return const Text('No site visits scheduled yet.', style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _scheduledVisits.map((visit) {
        final visitDate = DateTime.tryParse('${visit['visit_date'] ?? ''}');
        final when = visitDate == null
            ? 'Date pending'
            : '${visitDate.day}/${visitDate.month} ${visitDate.hour.toString().padLeft(2, '0')}:${visitDate.minute.toString().padLeft(2, '0')}';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PremiumUI.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit['property_name']?.toString() ?? 'Scheduled visit', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${visit['area'] ?? '-'}, ${visit['city'] ?? '-'} • $when', style: const TextStyle(color: PremiumUI.muted, fontSize: 12)),
                  ],
                ),
              ),
              PremiumUI.statusBadge('Scheduled', PremiumUI.accent),
            ],
          ),
        );
      }).toList(),
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

  Widget _buildPipelineSummary() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ActivationPipelineBoard())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: PremiumUI.glassBox(color: PremiumUI.secondary, opacity: 0.05),
        child: Row(
          children: [
            const Icon(Icons.view_kanban, color: PremiumUI.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activation Kanban', style: PremiumUI.subtitle.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Manage broker onboarding stages', style: PremiumUI.subtitle.copyWith(fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBrokersTable() {
    return Column(
      children: _topBrokers.map((b) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: PremiumUI.cyberPanel(color: PremiumUI.primary),
        child: ListTile(
          title: Text(b['broker_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text(b['company_name'] ?? '', style: PremiumUI.subtitle.copyWith(fontSize: 10)),
          trailing: const Icon(Icons.star, color: PremiumUI.warning, size: 16),
        ),
      )).toList(),
    );
  }

  Widget _buildMonthlyPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _performanceRow('Top Performing Broker', _stats['top_broker']?.toString() ?? 'Not available', PremiumUI.primary),
        _performanceRow('Leads Assigned to Caller', '${_stats['leads_assigned_to_caller'] ?? 0}', PremiumUI.accent),
        _performanceRow('Interested Leads', '${_stats['interested_leads'] ?? 0}', PremiumUI.hot),
        _performanceRow('Verified Visits', '${_stats['verified_visits_this_month'] ?? 0}', PremiumUI.secondary),
        _performanceRow('My Monthly Performance', _stats['monthly_performance']?.toString() ?? '0%', PremiumUI.warning),
      ],
    );
  }

  Widget _performanceRow(String label, String value, Color color) {
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

  Widget _buildQuickActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 3,
      children: [
        _actionBtn('Add Broker', Icons.person_add, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddBrokerScreen()))),
        _actionBtn('Add Lead', Icons.post_add, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddLeadFromBrokerScreen()))),
        _actionBtn('Follow-ups', Icons.call, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BrokerFollowupQueueScreen()))),
        _actionBtn('Site Visits', Icons.location_on, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SiteVisitListScreen()))),
        _actionBtn('Review Queue', Icons.fact_check, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BrokerReviewListScreen()))),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: PremiumUI.primary, size: 16),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: PremiumUI.subtitle.copyWith(color: color, fontSize: 8)),
      ),
    );
  }
}
