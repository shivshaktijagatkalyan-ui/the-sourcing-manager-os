import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'activation_pipeline_board.dart';
import 'project_inventory_erp.dart';
import 'add_broker_screen.dart';
import 'add_lead_from_broker.dart';
import 'broker_review_list.dart';
import 'site_visit_verify.dart';
import '../widgets/complete_profile_card.dart';
import 'profile_completion_screen.dart';
class SourcingManagerDashboard extends StatefulWidget {
  const SourcingManagerDashboard({super.key});

  @override
  State<SourcingManagerDashboard> createState() =>
      _SourcingManagerDashboardState();
}

class _SourcingManagerDashboardState extends State<SourcingManagerDashboard> {
  final TrainingRuntime _trainingRuntime = TrainingRuntime.instance;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topBrokers = [];
  List<Map<String, dynamic>> _followups = [];
  List<Map<String, dynamic>> _interestedLeads = [];
  List<Map<String, dynamic>> _scheduledVisits = [];
  List<Map<String, dynamic>> _visitProposals = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _lockRows = [];
  Map<String, dynamic>? _activeGoal;
  String? _orgId;

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
        final endOfDay =
            DateTime(today.year, today.month, today.day, 23, 59, 59)
                .toIso8601String();
        final startOfMonth =
            DateTime(today.year, today.month, 1).toIso8601String();
        final last7Days =
            today.subtract(const Duration(days: 7)).toIso8601String();

        final followups = await client
            .from('broker_followups')
            .select('id')
            .eq('assigned_to', userId)
            .eq('status', 'pending')
            .gte('due_at', startOfDay)
            .lte('due_at', endOfDay);
        final followupRows = await client
            .from('broker_followups')
            .select(
                'id, title, due_at, brokers_public(broker_alias, company_name)')
            .eq('assigned_to', userId)
            .eq('status', 'pending')
            .gte('due_at', startOfDay)
            .lte('due_at', endOfDay)
            .order('due_at')
            .limit(5);
        final activeBrokers = await client
            .from('brokers_public')
            .select('id')
            .eq('assigned_sourcing_manager_id', userId)
            .eq('category', 'active');
        final hotBrokers = await client
            .from('brokers_public')
            .select('id')
            .eq('assigned_sourcing_manager_id', userId)
            .eq('category', 'hot');
        final newBrokers = await client
            .from('brokers_public')
            .select('id')
            .eq('assigned_sourcing_manager_id', userId)
            .gte('created_at', last7Days);
        final pilotInfo = await client
            .from('pilot_users')
            .select('org_id')
            .eq('user_id', userId)
            .maybeSingle();
        final leads = await client
            .from('leads_public')
            .select('id')
            .eq('assigned_sourcing_manager_id', userId)
            .gte('created_at', startOfMonth);
        final verifiedVisits = await client
            .from('site_visits')
            .select('id')
            .eq('sourcing_manager_id', userId)
            .inFilter('status', ['completed', 'visit_done']).gte(
                'created_at', startOfMonth);
        final leadsAssignedToCaller = await client
            .from('leads_public')
            .select('id, alias, area, city, lead_status, assigned_caller_id')
            .eq('assigned_sourcing_manager_id', userId)
            .gte('created_at', startOfMonth)
            .not('assigned_caller_id', 'is', null)
            .limit(5);
        final interestedLeads = await client
            .from('leads_public')
            .select('id, alias, area, city, lead_status')
            .eq('assigned_sourcing_manager_id', userId)
            .eq('last_call_outcome', 'interested')
            .gte('created_at', startOfMonth)
            .limit(5);
        final scheduledVisits = await client
            .from('site_visits')
            .select(
                'id, lead_id, source_lead_id, property_name, area, city, visit_date, scheduled_at, status')
            .eq('sourcing_manager_id', userId)
            .inFilter('status', [
              'scheduled',
              'client_reached_site',
              'gps_verified',
              'qr_verified',
              'photo_uploaded',
              'broker_review_pending',
              'completed',
              'visit_done',
              'no_show'
            ])
            .gte('created_at', startOfMonth)
            .limit(8);
        final visitProposals = await client
            .from('site_visit_proposals')
            .select(
                'id, source_lead_id, source_broker_id, project_id, status, proposed_for, scheduled_at, notes_safe, projects(project_name, area, city), brokers_public(broker_name, company_name, area), leads_public(alias, area, city)')
            .eq('assigned_sourcing_manager_id', userId)
            .eq('organization_id', pilotInfo?['org_id'])
            .inFilter('status', ['proposed', 'accepted', 'scheduled'])
            .order('proposed_for')
            .limit(8);
        final topBrokers = await client
            .from('brokers_public')
            .select('id, broker_name, company_name, area, city')
            .eq('assigned_sourcing_manager_id', userId)
            .eq('category', 'active')
            .order('created_at', ascending: false)
            .limit(5);
        final goals = await client
            .from('sourcing_goals')
            .select('*')
            .eq('user_id', userId)
            .eq('status', 'active')
            .maybeSingle();
        // sourcing_tasks may not exist in all remote environments — degrade gracefully
        List<dynamic> tasks = [];
        try {
          tasks = await client
              .from('sourcing_tasks')
              .select('*')
              .eq('user_id', userId)
              .order('created_at', ascending: false);
        } catch (_) {
          // Table not yet deployed to this Supabase instance — skip silently
        }

        // broker_locks requires a valid org_id; skip if pilot row is missing
        final orgId = pilotInfo?['org_id'] as String?;
        List<dynamic> locks = [];
        if (orgId != null) {
          locks = await client
              .from('broker_locks')
              .select(
                  'id, broker_id, lead_id, status, expires_at, brokerage_status, brokers_public(broker_name, company_name), leads_public(alias)')
              .eq('organization_id', orgId)
              .order('expires_at')
              .limit(10);
        }

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
            'visit_proposals': visitProposals.length,
            'scheduled_visits': scheduledVisits
                .where((row) => row['status'] == 'scheduled')
                .length,
            'client_reached': scheduledVisits
                .where((row) => row['status'] == 'client_reached_site')
                .length,
            'no_shows': scheduledVisits
                .where((row) => row['status'] == 'no_show')
                .length,
            'verified_visits_this_month': verifiedVisits.length,
            'monthly_performance': '94%',
            'top_broker': topBrokers.isNotEmpty
                ? (topBrokers.first['broker_name'] ??
                    topBrokers.first['company_name'] ??
                    'Not available')
                : 'Not available',
          };
          _topBrokers = List<Map<String, dynamic>>.from(topBrokers);
          _followups = List<Map<String, dynamic>>.from(followupRows);
          _interestedLeads = List<Map<String, dynamic>>.from(interestedLeads);
          _scheduledVisits = List<Map<String, dynamic>>.from(scheduledVisits);
          _visitProposals = List<Map<String, dynamic>>.from(visitProposals);
          _activeGoal = goals;
          _tasks = List<Map<String, dynamic>>.from(tasks);
          _lockRows = List<Map<String, dynamic>>.from(locks);
          _orgId = orgId;
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _stats = _trainingRuntime.sourcingManagerStats();
          _topBrokers = _trainingRuntime
              .topBrokersForManager(TrainingRuntime.sourcingManagerId);
          _followups = _trainingRuntime
              .followupsForManager(TrainingRuntime.sourcingManagerId);
          _interestedLeads = _trainingRuntime
              .interestedLeadsForManager(TrainingRuntime.sourcingManagerId);
          _scheduledVisits = _trainingRuntime
              .siteVisitsForManager(TrainingRuntime.sourcingManagerId);
          _visitProposals = _trainingRuntime
              .siteVisitProposalsForManager(TrainingRuntime.sourcingManagerId);
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
        title: Text('SOURCING MANAGER HUB',
            style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _buildStatusBadge('SECURE_SESSION', PremiumUI.secondary),
          IconButton(
              onPressed: _fetchStats,
              icon: const Icon(Icons.refresh, size: 20)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeHeader(),
                          const SizedBox(height: 24),
                          CompleteProfileCard(
                            role: 'sourcing_manager',
                            onCompleteTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileCompletionScreen(role: 'sourcing_manager')));
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildDailyGoalProgress(),
                          const SizedBox(height: 32),
                          _buildSectionTitle('TODAY\'S PRIORITIES'),
                          const SizedBox(height: 12),
                          _buildHinglishHelp(
                              'Aaj ke follow-ups line mein hain. Broker ko "Secure Call" karein, number kabhi leak nahi hoga.'),
                          const SizedBox(height: 16),
                          _buildPremiumActionHub(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('SALES INTELLIGENCE (GOALS)'),
                          const SizedBox(height: 12),
                          _buildGoalTracking(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('DAILY TASKS'),
                          const SizedBox(height: 12),
                          _buildTaskManagement(),
                          const SizedBox(height: 24),
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
                        title: 'Visit Proposals',
                        subtitle:
                            'Broker proposals waiting for acceptance or reschedule',
                        accentColor: PremiumUI.warning,
                        child: _buildVisitProposalList(),
                      ),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'Site Visit Tracker',
                        subtitle: 'Scheduled and field-ready visits',
                        accentColor: PremiumUI.accent,
                        child: _buildSiteVisitList(),
                      ),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'Broker Credit Locks',
                        subtitle: 'Commission protection and status',
                        accentColor: PremiumUI.secondary,
                        child: _buildBrokerLocks(),
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('TOP PERFORMING BROKERS'),
                      const SizedBox(height: 12),
                      _buildTopBrokersTable(),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'Broker-wise Visit Performance',
                        subtitle: 'Verified walk-in performance by broker',
                        accentColor: PremiumUI.secondary,
                        child: _buildBrokerVisitPerformance(),
                      ),
                      const SizedBox(height: 32),
                      PremiumUI.sectionShell(
                        title: 'My Monthly Performance',
                        subtitle:
                            'What is pending, blocked, and verified this month',
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
        Text('Project: The Wadhwa Wise City, Panvel',
            style: PremiumUI.subtitle.copyWith(color: PremiumUI.primary)),
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
          Expanded(
              child: Text(text,
                  style: PremiumUI.subtitle
                      .copyWith(color: Colors.white70, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildDailyGoalProgress() {
    // Mock progress for now, would be tied to _activeGoal
    const double progress = 0.65; // 65%
    return PremiumUI.glassCard(
      color: PremiumUI.primary,
      opacity: 0.08,
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  color: PremiumUI.primary,
                ),
              ),
              Text('${(progress * 100).toInt()}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DAILY PERFORMANCE TARGET',
                    style: TextStyle(
                        color: PremiumUI.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                const Text('12 / 20 Actions Completed',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Good pace! 8 more to reach your daily bonus.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActionHub() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _hubAction(
          'Add Broker',
          Icons.person_add_outlined,
          PremiumUI.primary,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (c) => const AddBrokerScreen())),
        ),
        _hubAction(
          'Add Lead',
          Icons.post_add_outlined,
          PremiumUI.secondary,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (c) => const AddLeadFromBrokerScreen())),
        ),
        _hubAction(
          'View Board',
          Icons.view_kanban_outlined,
          PremiumUI.accent,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (c) => const ActivationPipelineBoard())),
        ),
        _hubAction(
          'Review Work',
          Icons.fact_check_outlined,
          PremiumUI.hot,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (c) => const BrokerReviewListScreen())),
        ),
        _hubAction(
          'Inventory ERP',
          Icons.apartment_outlined,
          PremiumUI.secondary,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (c) => const ProjectInventoryERPScreen(
                      projectId: 'project_wadhwa_wise_city'))),
        ),
      ],
    );
  }

  Widget _hubAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
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
        _miniKPI('Follow-ups', _stats['followups_today'].toString(),
            PremiumUI.warning),
        _miniKPI(
            'Hot Brokers', _stats['hot_brokers'].toString(), PremiumUI.hot),
        _miniKPI(
            'Active', _stats['active_brokers'].toString(), PremiumUI.primary),
        _miniKPI('Visit Proposals', _stats['visit_proposals'].toString(),
            PremiumUI.warning),
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
        _miniKPI('Leads (M)', _stats['leads_this_month'].toString(),
            PremiumUI.primary),
        _miniKPI('Caller Asgn', _stats['leads_assigned_to_caller'].toString(),
            PremiumUI.accent),
        _miniKPI(
            'Interested', _stats['interested_leads'].toString(), PremiumUI.hot),
        _miniKPI('Scheduled Visits', _stats['scheduled_visits'].toString(),
            PremiumUI.accent),
        _miniKPI('Client Reached', _stats['client_reached'].toString(),
            PremiumUI.secondary),
        _miniKPI('No Shows', _stats['no_shows'].toString(), PremiumUI.danger),
        _miniKPI('Verified Visits',
            _stats['verified_visits_this_month'].toString(), PremiumUI.accent),
      ],
    );
  }

  Widget _buildFollowupQueue() {
    if (_followups.isEmpty) {
      return const Text('No follow-ups due right now.',
          style: TextStyle(color: PremiumUI.muted));
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
              const Icon(Icons.call_outlined,
                  color: PremiumUI.warning, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      followup['title']?.toString() ?? 'Broker follow-up',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      brokerLabel.toString(),
                      style:
                          const TextStyle(color: PremiumUI.muted, fontSize: 12),
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
      return const Text('No interested leads are waiting for action.',
          style: TextStyle(color: PremiumUI.muted));
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
                    Text(lead['alias']?.toString() ?? 'Lead',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${lead['area'] ?? '-'}, ${lead['city'] ?? '-'}',
                        style: const TextStyle(
                            color: PremiumUI.muted, fontSize: 12)),
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

  Widget _buildVisitProposalList() {
    if (_visitProposals.isEmpty) {
      return const Text('No visit proposals waiting right now.',
          style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _visitProposals.map((proposal) {
        final project = proposal['projects'];
        final lead = proposal['leads_public'];
        final broker = proposal['brokers_public'];
        final projectName = project is Map<String, dynamic>
            ? project['project_name']?.toString() ?? 'Project'
            : 'Project';
        final leadAlias = lead is Map<String, dynamic>
            ? lead['alias']?.toString() ?? 'Lead'
            : 'Lead';
        final brokerName = broker is Map<String, dynamic>
            ? (broker['company_name'] ?? broker['broker_name'] ?? 'Broker')
                .toString()
            : 'Broker';
        final proposedAt =
            DateTime.tryParse('${proposal['proposed_for'] ?? ''}');
        final when = proposedAt == null
            ? 'Slot pending'
            : '${proposedAt.day}/${proposedAt.month} ${proposedAt.hour.toString().padLeft(2, '0')}:${proposedAt.minute.toString().padLeft(2, '0')}';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PremiumUI.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PremiumUI.warning.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$leadAlias - $projectName',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('$brokerName - Proposed $when',
                            style: const TextStyle(
                                color: PremiumUI.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  PremiumUI.statusBadge(
                      '${proposal['status'] ?? 'proposed'}', PremiumUI.warning),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _smallActionButton(
                      'Accept',
                      PremiumUI.secondary,
                      () => _reviewVisitProposal(proposal, 'accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallActionButton(
                      'Reschedule',
                      PremiumUI.accent,
                      () => _reviewVisitProposal(proposal, 'reschedule'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallActionButton(
                      'Reject',
                      PremiumUI.danger,
                      () => _reviewVisitProposal(proposal, 'reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSiteVisitList() {
    if (_scheduledVisits.isEmpty) {
      return const Text('No site visits scheduled yet.',
          style: TextStyle(color: PremiumUI.muted));
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            visit['property_name']?.toString() ??
                                'Scheduled visit',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            '${visit['area'] ?? '-'}, ${visit['city'] ?? '-'} - $when',
                            style: const TextStyle(
                                color: PremiumUI.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  PremiumUI.statusBadge(
                      '${visit['status'] ?? 'scheduled'}',
                      PremiumUI.statusColor(
                          '${visit['status'] ?? 'scheduled'}')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _smallActionButton(
                      'Client Reached',
                      PremiumUI.accent,
                      () => _confirmVisitArrival(visit),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallActionButton(
                      'Verify Proof',
                      PremiumUI.secondary,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SiteVisitVerifyScreen(
                            visitId: '${visit['id'] ?? ''}',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallActionButton(
                      'No Show',
                      PremiumUI.danger,
                      () => _verifyVisitProof(visit, 'no_show'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBrokerLocks() {
    if (_lockRows.isEmpty) {
      return const Text('No active broker locks monitored.',
          style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _lockRows.map((lock) {
        final broker = lock['brokers_public'];
        final lead = lock['leads_public'];
        final brokerName = broker is Map ? (broker['company_name'] ?? broker['broker_name'] ?? 'Broker') : 'Broker';
        final leadAlias = lead is Map ? (lead['alias'] ?? 'Lead') : 'Lead';
        final status = '${lock['status'] ?? 'inactive'}';
        final brokerage = '${lock['brokerage_status'] ?? 'tracking'}';

        final expiry = DateTime.tryParse('${lock['expires_at'] ?? ''}');
        final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : 0;
        final countdown = daysLeft > 0 ? '$daysLeft days left' : 'Expired';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PremiumUI.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PremiumUI.secondary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_clock, color: PremiumUI.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$leadAlias - $countdown',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('$brokerName | ${brokerage.replaceAll('_', ' ').toUpperCase()}',
                        style: const TextStyle(
                            color: PremiumUI.muted, fontSize: 11)),
                  ],
                ),
              ),
              PremiumUI.statusBadge(status, daysLeft < 7 ? PremiumUI.hot : PremiumUI.secondary),
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
          Text(label.toUpperCase(),
              style: PremiumUI.subtitle.copyWith(
                  fontSize: 9, color: Colors.white70, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _smallActionButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineSummary() {
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (c) => const ActivationPipelineBoard())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration:
            PremiumUI.glassBox(color: PremiumUI.secondary, opacity: 0.05),
        child: Row(
          children: [
            const Icon(Icons.view_kanban, color: PremiumUI.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activation Kanban',
                      style: PremiumUI.subtitle.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Manage broker onboarding stages',
                      style: PremiumUI.subtitle.copyWith(fontSize: 10)),
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
      children: _topBrokers
          .map((b) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: PremiumUI.cyberPanel(color: PremiumUI.primary),
                child: ListTile(
                  title: Text(b['broker_name'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(b['company_name'] ?? '',
                      style: PremiumUI.subtitle.copyWith(fontSize: 10)),
                  trailing: const Icon(Icons.star,
                      color: PremiumUI.warning, size: 16),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildBrokerVisitPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _performanceRow(
          'JSN Enterprise',
          '${_stats['verified_visits_this_month'] ?? 0} verified / ${_stats['scheduled_visits'] ?? 0} scheduled',
          PremiumUI.secondary,
        ),
        _performanceRow(
          'Visit Proposals',
          '${_stats['visit_proposals'] ?? 0}',
          PremiumUI.warning,
        ),
        _performanceRow(
          'No Shows',
          '${_stats['no_shows'] ?? 0}',
          PremiumUI.danger,
        ),
      ],
    );
  }

  Widget _buildMonthlyPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _performanceRow(
            'Top Performing Broker',
            _stats['top_broker']?.toString() ?? 'Not available',
            PremiumUI.primary),
        _performanceRow('Leads Assigned to Caller',
            '${_stats['leads_assigned_to_caller'] ?? 0}', PremiumUI.accent),
        _performanceRow('Interested Leads',
            '${_stats['interested_leads'] ?? 0}', PremiumUI.hot),
        _performanceRow(
            'Verified Visits',
            '${_stats['verified_visits_this_month'] ?? 0}',
            PremiumUI.secondary),
        _performanceRow(
            'My Monthly Performance',
            _stats['monthly_performance']?.toString() ?? '0%',
            PremiumUI.warning),
      ],
    );
  }

  Widget _performanceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white))),
          PremiumUI.statusBadge(value, color),
        ],
      ),
    );
  }

  Widget _buildGoalTracking() {
    if (_activeGoal == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: PremiumUI.glassBox(color: PremiumUI.primary, opacity: 0.1),
        child: const Text(
            'No active goals for this month. Focus on daily tasks.',
            style: TextStyle(color: PremiumUI.muted)),
      );
    }

    final targetLeads = (_activeGoal!['target_leads'] as num?) ?? 0;
    final targetVisits = (_activeGoal!['target_visits'] as num?) ?? 0;
    final currentLeads = (_stats['leads_this_month'] as num?) ?? 0;
    final currentVisits = (_stats['verified_visits_this_month'] as num?) ?? 0;

    return Column(
      children: [
        _buildGoalProgress(
            'Monthly Leads Goal', currentLeads, targetLeads, PremiumUI.primary),
        const SizedBox(height: 12),
        _buildGoalProgress(
            'Site Visits Goal', currentVisits, targetVisits, PremiumUI.accent),
      ],
    );
  }

  Widget _buildGoalProgress(
      String label, num current, num target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text('$current / $target',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.toDouble(),
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskManagement() {
    final pendingTasks = _tasks.where((t) => t['status'] == 'pending').toList();
    final completedTasks =
        _tasks.where((t) => t['status'] == 'completed').toList();

    return Column(
      children: [
        Row(
          children: [
            _taskStatCard('Daily', pendingTasks.length, PremiumUI.warning),
            const SizedBox(width: 12),
            _taskStatCard(
                'Achieved', completedTasks.length, PremiumUI.secondary),
            const SizedBox(width: 12),
            _taskStatCard(
                'Incomplete',
                _tasks.where((t) => t['status'] == 'cancelled').length,
                PremiumUI.muted),
          ],
        ),
        const SizedBox(height: 16),
        if (pendingTasks.isEmpty)
          const Text('Sab tasks poore hain! Shabaash.',
              style: TextStyle(color: PremiumUI.muted, fontSize: 12))
        else
          ...pendingTasks.map((task) => _buildTaskItem(task)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showAddTaskDialog,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('CREATE NEW TASK'),
          style: ElevatedButton.styleFrom(
            backgroundColor: PremiumUI.primary.withValues(alpha: 0.1),
            foregroundColor: PremiumUI.primary,
            side: const BorderSide(color: PremiumUI.primary),
            minimumSize: const Size(double.infinity, 40),
          ),
        ),
      ],
    );
  }

  Widget _taskStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PremiumUI.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(count.toString(),
                style: PremiumUI.h1.copyWith(fontSize: 18, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task['status'] == 'completed',
            onChanged: (val) => _toggleTaskStatus(task['id'], val ?? false),
            activeColor: PremiumUI.secondary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task['title'] ?? 'Task',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                if (task['description'] != null)
                  Text(task['description'],
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          _priorityBadge(task['priority']),
        ],
      ),
    );
  }

  Widget _priorityBadge(String? priority) {
    Color color = PremiumUI.muted;
    if (priority == 'high') color = PremiumUI.hot;
    if (priority == 'medium') color = PremiumUI.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(priority?.toUpperCase() ?? 'MED',
          style: TextStyle(
              color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _reviewVisitProposal(
      Map<String, dynamic> proposal, String action) async {
    final proposalId = '${proposal['id'] ?? ''}';
    if (proposalId.isEmpty) return;
    final proposedFor =
        DateTime.tryParse('${proposal['proposed_for'] ?? ''}') ??
            DateTime.now().add(const Duration(days: 1));

    try {
      if (AppConfig.isSupabaseConfigured) {
        final response = await Supabase.instance.client.functions.invoke(
          'review-site-visit-proposal',
          body: {
            'proposal_id': proposalId,
            'action': action,
            'scheduled_at': proposedFor.toIso8601String(),
            'notes_safe': 'Reviewed by sourcing manager.',
          },
        );
        final data = response.data as Map<String, dynamic>?;
        _showSnack(data?['ok'] == true
            ? 'Visit proposal updated.'
            : 'Visit proposal blocked.');
      } else {
        final updated = _trainingRuntime.reviewSiteVisitProposal(
          proposalId,
          action,
          scheduledAt: proposedFor,
        );
        _showSnack(
            updated ? 'Visit proposal updated.' : 'Visit proposal blocked.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Request failed closed.');
    }
  }

  Future<void> _confirmVisitArrival(Map<String, dynamic> visit) async {
    final visitId = '${visit['id'] ?? ''}';
    if (visitId.isEmpty) return;

    try {
      if (AppConfig.isSupabaseConfigured) {
        final response = await Supabase.instance.client.functions.invoke(
          'confirm-site-visit-arrival',
          body: {'site_visit_id': visitId},
        );
        final data = response.data as Map<String, dynamic>?;
        _showSnack(data?['ok'] == true
            ? 'Client Reached updated.'
            : 'Arrival update blocked.');
      } else {
        final updated = _trainingRuntime.confirmSiteVisitArrival(visitId);
        _showSnack(
            updated ? 'Client Reached updated.' : 'Arrival update blocked.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Request failed closed.');
    }
  }

  Future<void> _verifyVisitProof(
      Map<String, dynamic> visit, String proofType) async {
    final visitId = '${visit['id'] ?? ''}';
    if (visitId.isEmpty) return;

    try {
      if (AppConfig.isSupabaseConfigured) {
        final response = await Supabase.instance.client.functions.invoke(
          'verify-site-visit-proof',
          body: {'site_visit_id': visitId, 'proof_type': proofType},
        );
        final data = response.data as Map<String, dynamic>?;
        _showSnack(data?['ok'] == true
            ? 'Visit proof updated.'
            : 'Visit proof blocked.');
      } else {
        final updated =
            _trainingRuntime.verifySiteVisitProof(visitId, proofType);
        _showSnack(updated ? 'Visit proof updated.' : 'Visit proof blocked.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Request failed closed.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleTaskStatus(String taskId, bool completed) async {
    if (!AppConfig.isSupabaseConfigured) return;
    try {
      await Supabase.instance.client.from('sourcing_tasks').update(
          {'status': completed ? 'completed' : 'pending'}).eq('id', taskId);
      _fetchStats();
    } catch (e) {
      // ignore
    }
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumUI.background,
        title:
            Text('CREATE NEW TASK', style: PremiumUI.h1.copyWith(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: priority,
              dropdownColor: PremiumUI.cardColor,
              decoration: const InputDecoration(
                  labelText: 'Priority',
                  labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
              items: ['low', 'medium', 'high']
                  .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                  .toList(),
              onChanged: (val) => priority = val ?? 'medium',
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || _orgId == null) return;
              final client = Supabase.instance.client;
              await client.from('sourcing_tasks').insert({
                'user_id': client.auth.currentUser!.id,
                'org_id': _orgId,
                'title': titleController.text,
                'description': descController.text,
                'priority': priority,
                'status': 'pending',
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              _fetchStats();
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid() => const SizedBox.shrink();

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: PremiumUI.primary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title,
            style: PremiumUI.subtitle.copyWith(
                color: Colors.white, letterSpacing: 1.5, fontSize: 11)),
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
        child: Text(text,
            style: PremiumUI.subtitle.copyWith(color: color, fontSize: 8)),
      ),
    );
  }
}
