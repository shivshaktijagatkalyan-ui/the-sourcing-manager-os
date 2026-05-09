import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'add_lead_from_broker.dart';

class BrokerDashboardScreen extends StatefulWidget {
  const BrokerDashboardScreen({super.key});

  @override
  State<BrokerDashboardScreen> createState() => _BrokerDashboardScreenState();
}

class _BrokerDashboardScreenState extends State<BrokerDashboardScreen> {
  final TrainingRuntime _trainingRuntime = TrainingRuntime.instance;

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _connectedManagers = [];
  List<Map<String, dynamic>> _liveProjects = [];
  List<Map<String, dynamic>> _leadRows = [];
  List<Map<String, dynamic>> _followupRows = [];
  List<Map<String, dynamic>> _visitRows = [];
  List<Map<String, dynamic>> _proposalRows = [];
  List<Map<String, dynamic>> _lockRows = [];
  List<Map<String, dynamic>> _activityRows = [];
  List<Map<String, dynamic>> _availableCallers = [];
  List<Map<String, dynamic>> _priorityActions = [];
  Map<String, dynamic>? _activeGoal;

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
        await _fetchLiveStats();
      } else {
        await _fetchDemoStats();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLiveStats() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final brokerRows = await client
        .from('brokers_public')
        .select(
          'id, organization_id, broker_code, broker_alias, broker_name, company_name, area, city, speciality, verified_status, trust_score, verified_performance_rank',
        )
        .eq('linked_user_id', user.id)
        .eq('status', 'active');

    final brokers = List<Map<String, dynamic>>.from(brokerRows);
    if (brokers.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final brokerIds = brokers.map((row) => '${row['id']}').toList();
    final primaryBroker = brokers.first;
    final organizationId = '${primaryBroker['organization_id']}';

    final leadRows = await client
        .from('leads_public')
        .select(
          'id, alias, area, city, property_name, project_id, budget_min, budget_max, lead_status, assigned_caller_id, assigned_sourcing_manager_id, last_call_outcome, lead_quality, lead_temperature, buyer_type, project_match_status, next_followup_at, broker_notes_safe, conversion_stage, booking_stage, brokerage_status, data_quality_score, created_at, updated_at',
        )
        .inFilter('source_broker_id', brokerIds)
        .order('created_at', ascending: false)
        .limit(30);

    final leads = List<Map<String, dynamic>>.from(leadRows);
    final leadIds = leads.map((row) => '${row['id']}').toList();

    final activations = await client
        .from('broker_activations')
        .select(
          'id, broker_id, project_id, activation_stage, assigned_sourcing_manager_id, projects(project_name, area, city, status)',
        )
        .inFilter('broker_id', brokerIds);

    final visits = await client
        .from('site_visits')
        .select(
          'id, lead_id, source_lead_id, source_broker_id, status, broker_review_status, scheduled_at, created_at',
        )
        .inFilter('source_broker_id', brokerIds);

    final proposals = await client
        .from('site_visit_proposals')
        .select(
          'id, source_lead_id, project_id, status, proposed_for, scheduled_at, notes_safe, created_at, projects(project_name, area, city), leads_public(alias, area, city)',
        )
        .inFilter('source_broker_id', brokerIds)
        .order('proposed_for', ascending: true)
        .limit(8);

    final locks = await client
        .from('broker_locks')
        .select('id, broker_id, lead_id, status, expires_at')
        .inFilter('broker_id', brokerIds);

    final dataLoans = leadIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await client
                .from('data_loans')
                .select('id, lead_id, granted_to_user_id, status, expires_at')
                .inFilter('lead_id', leadIds),
          );

    final callAttempts = leadIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await client
                .from('call_attempts')
                .select('id, lead_id, call_status, outcome, created_at')
                .inFilter('lead_id', leadIds),
          );

    final followups = await client
        .from('broker_followups')
        .select('id, broker_id, status, due_at, priority, reason')
        .inFilter('broker_id', brokerIds)
        .order('due_at', ascending: true)
        .limit(8);

    final activityRows = await client
        .from('broker_activity_logs')
        .select('id, activity_type, outcome, next_followup_at, created_at')
        .inFilter('broker_id', brokerIds)
        .order('created_at', ascending: false)
        .limit(8);

    final goals = await client
        .from('broker_goals')
        .select('*')
        .inFilter('broker_id', brokerIds)
        .eq('status', 'active')
        .maybeSingle();

    final callers = await _loadAvailableCallers(client, organizationId);

    final visitByLead = <String, Map<String, dynamic>>{};
    for (final visit in List<Map<String, dynamic>>.from(visits)) {
      final key = '${visit['source_lead_id'] ?? visit['lead_id'] ?? ''}';
      if (key.isNotEmpty && !visitByLead.containsKey(key)) {
        visitByLead[key] = visit;
      }
    }

    final lockByLead = <String, Map<String, dynamic>>{};
    for (final lock in List<Map<String, dynamic>>.from(locks)) {
      final key = '${lock['lead_id'] ?? ''}';
      if (key.isNotEmpty && !lockByLead.containsKey(key)) {
        lockByLead[key] = lock;
      }
    }

    final loanByLead = <String, Map<String, dynamic>>{};
    for (final loan in dataLoans) {
      final key = '${loan['lead_id'] ?? ''}';
      if (key.isNotEmpty && !loanByLead.containsKey(key)) {
        loanByLead[key] = loan;
      }
    }

    final callCountByLead = <String, int>{};
    for (final attempt in callAttempts) {
      final key = '${attempt['lead_id'] ?? ''}';
      if (key.isNotEmpty) {
        callCountByLead[key] = (callCountByLead[key] ?? 0) + 1;
      }
    }

    final safeLeadRows = leads.take(8).map((lead) {
      final leadId = '${lead['id'] ?? ''}';
      final loan = loanByLead[leadId];
      final visit = visitByLead[leadId];
      final lock = lockByLead[leadId];
      final quality = _safeStatus(
          lead['lead_quality'] ?? lead['lead_temperature'] ?? 'warm');
      final conversionStage = _safeStatus(
          lead['conversion_stage'] ?? lead['lead_status'] ?? 'lead_received');
      final dataQuality = _dataQualityLabel(_asNum(lead['data_quality_score']));
      return {
        'id': leadId,
        'alias': lead['alias'] ?? 'Lead',
        'area': lead['area'] ?? '-',
        'project': lead['property_name'] ?? 'Project',
        'budget': _formatBudget(lead['budget_min'], lead['budget_max']),
        'lead_quality': quality,
        'buyer_type': _safeStatus(lead['buyer_type'] ?? 'end_user'),
        'assigned_to': _assignedTo(lead, callers),
        'loan': _permissionStatus(loan),
        'call_status': _safeStatus(
            lead['last_call_outcome'] ?? lead['lead_status'] ?? 'pending'),
        'followup': _formatFollowup(lead['next_followup_at']),
        'visit_status': _visitStatus(visit),
        'lock': _lockStatus(lock),
        'booking_stage': _safeStatus(lead['booking_stage'] ?? 'not_started'),
        'brokerage_status': _safeStatus(lead['brokerage_status'] ?? 'tracking'),
        'data_quality': dataQuality,
        'conversion_stage': conversionStage,
        'calls_attempted': callCountByLead[leadId] ?? 0,
        'project_id': lead['project_id'],
      };
    }).toList();

    final connectedManagers =
        List<Map<String, dynamic>>.from(activations).map((activation) {
      final project = activation['projects'];
      return {
        'name': 'Vinod Gupta',
        'project': project is Map<String, dynamic>
            ? '${project['project_name'] ?? 'Project'}'
            : 'Project',
        'status': activation['activation_stage'] ?? 'active',
        'leads_shared': leads.length,
        'visits_generated': List<Map<String, dynamic>>.from(visits).length,
      };
    }).toList();

    final liveProjects =
        List<Map<String, dynamic>>.from(activations).map((activation) {
      final project = activation['projects'];
      final projectName =
          project is Map<String, dynamic> ? project['project_name'] : 'Project';
      final area = project is Map<String, dynamic> ? project['area'] : '';
      final city = project is Map<String, dynamic> ? project['city'] : '';
      return {
        'id': activation['project_id'],
        'title': projectName ?? 'Project',
        'location':
            [area, city].where((value) => '$value'.isNotEmpty).join(', '),
        'status': project is Map<String, dynamic>
            ? project['status'] ?? 'active'
            : 'active',
        'stage': activation['activation_stage'] ?? 'active',
        'leads_given': leads.length,
        'verified_visits': List<Map<String, dynamic>>.from(visits)
            .where(_isVerifiedVisit)
            .length,
      };
    }).toList();

    final now = DateTime.now();
    final dueFollowups =
        List<Map<String, dynamic>>.from(followups).where((row) {
      final dueAt = DateTime.tryParse('${row['due_at'] ?? ''}');
      return row['status'] == 'pending' &&
          dueAt != null &&
          dueAt.isBefore(now.add(const Duration(days: 1)));
    }).length;
    final expiredLoans = dataLoans
        .where((row) =>
            row['status'] == 'expired' || _isExpired(row['expires_at']))
        .length;
    final bookingDiscussions = leads.where((row) {
      final stage = _safeStatus(row['booking_stage'] ?? '');
      return stage == 'booking_discussion' || stage == 'token_discussion';
    }).length;

    if (!mounted) return;
    setState(() {
      _profile = {
        'broker_id': primaryBroker['id'],
        'broker_code':
            primaryBroker['broker_code'] ?? _fallbackBrokerCode(primaryBroker),
        'broker_alias': primaryBroker['broker_alias'] ?? 'Broker',
        'broker_name': primaryBroker['broker_name'] ??
            primaryBroker['broker_alias'] ??
            'Broker',
        'company_name': primaryBroker['company_name'] ?? 'Broker Business',
        'area': primaryBroker['area'] ?? '-',
        'city': primaryBroker['city'] ?? '-',
        'speciality': primaryBroker['speciality'] ?? 'Area buyer network',
        'verified_status':
            primaryBroker['verified_status'] ?? 'verified_active',
        'rank': primaryBroker['verified_performance_rank'] ??
            _rankFor(primaryBroker['trust_score']),
      };
      _stats = {
        'connected_sm_count': connectedManagers.length,
        'live_projects_count': liveProjects.length,
        'total_leads': leads.length,
        'hot_leads': leads
            .where((row) =>
                _safeStatus(row['lead_quality'] ?? row['lead_temperature']) ==
                'hot')
            .length,
        'warm_leads': leads
            .where((row) =>
                _safeStatus(row['lead_quality'] ?? row['lead_temperature']) ==
                'warm')
            .length,
        'followups_due': dueFollowups,
        'calls_attempted': callAttempts.length,
        'interested_leads': leads
            .where(
                (row) => _safeStatus(row['last_call_outcome']) == 'interested')
            .length,
        'site_visits_scheduled': List<Map<String, dynamic>>.from(visits)
            .where((row) => row['status'] == 'scheduled')
            .length,
        'visits_proposed': List<Map<String, dynamic>>.from(proposals)
            .where((row) => row['status'] != 'rejected')
            .length,
        'visits_done': List<Map<String, dynamic>>.from(visits)
            .where(_isVerifiedVisit)
            .length,
        'verified_visits': List<Map<String, dynamic>>.from(visits)
            .where(_isVerifiedVisit)
            .length,
        'data_loans_active': dataLoans
            .where((row) =>
                row['status'] == 'active' && !_isExpired(row['expires_at']))
            .length,
        'expired_call_permissions': expiredLoans,
        'active_locks': List<Map<String, dynamic>>.from(locks)
            .where((row) =>
                row['status'] == 'active' && !_isExpired(row['expires_at']))
            .length,
        'booking_discussions': bookingDiscussions,
        'brokerage_tracking': leads
            .where((row) =>
                _safeStatus(row['brokerage_status'] ?? 'tracking') ==
                'tracking')
            .length,
        'pending_leads': leads
            .where((row) => _safeStatus(row['lead_status']) == 'new')
            .length,
        'trust_score': primaryBroker['trust_score'] ?? 0,
      };
      _connectedManagers = connectedManagers;
      _liveProjects = liveProjects;
      _leadRows = safeLeadRows;
      _followupRows = List<Map<String, dynamic>>.from(followups);
      _visitRows = List<Map<String, dynamic>>.from(visits);
      _proposalRows = List<Map<String, dynamic>>.from(proposals);
      _lockRows = List<Map<String, dynamic>>.from(locks);
      _activityRows = List<Map<String, dynamic>>.from(activityRows);
      _availableCallers = callers;
      _activeGoal = goals;
      _priorityActions = _buildPriorityData();
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _loadAvailableCallers(
      SupabaseClient client, String organizationId) async {
    try {
      final response = await client.rpc('get_organization_callers',
          params: {'p_org_id': organizationId});
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  Future<void> _fetchDemoStats() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _profile = _trainingRuntime.brokerDashboardProfile();
      _stats = _trainingRuntime.brokerDashboardStats();
      _connectedManagers = _trainingRuntime.brokerConnectedManagers();
      _liveProjects = _trainingRuntime.brokerLiveProjects();
      _leadRows = _trainingRuntime.brokerLeadRows();
      _followupRows = _trainingRuntime.brokerFollowupRows();
      _visitRows = _trainingRuntime.brokerVisitRows();
      _proposalRows = _trainingRuntime.brokerSiteVisitProposalRows();
      _lockRows = _trainingRuntime.brokerLockRows();
      _activityRows = _trainingRuntime.brokerActivityRows();
      _availableCallers = _trainingRuntime
          .activeCallersForOrganization(TrainingRuntime.organizationId);
      _activeGoal = null;
      _priorityActions = _buildPriorityData();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: Text(
          'BROKER BUSINESS VAULT',
          style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 1.8),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          PremiumUI.statusBadge('DATALESS', PremiumUI.secondary),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIdentityCard(),
                    const SizedBox(height: 16),
                    _buildNextActionStrip(),
                    const SizedBox(height: 16),
                    _largeActionCard(
                      'Add Secure Lead',
                      Icons.add_business,
                      PremiumUI.primary,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const AddLeadFromBrokerScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildKPIGrid(),
                    const SizedBox(height: 24),
                    _buildBusinessGrowthCards(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('BROKER BUSINESS VAULT'),
                    const SizedBox(height: 12),
                    _buildVaultSummary(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('MY LEADS'),
                    const SizedBox(height: 12),
                    if (_leadRows.isEmpty)
                      _emptyState(
                          'No broker leads yet. Add one secure lead to start the sales engine.')
                    else
                      ..._leadRows.map(_buildLeadCard),
                    const SizedBox(height: 24),
                    _twoColumnSections(
                      left: PremiumUI.sectionShell(
                        title: 'MY FOLLOW-UPS',
                        subtitle:
                            'Hot leads, call later tasks, and booking reminders',
                        accentColor: PremiumUI.warning,
                        child: _buildFollowups(),
                      ),
                      right: PremiumUI.sectionShell(
                        title: 'MY LIVE PROJECTS',
                        subtitle: 'Projects where your verified data is moving',
                        accentColor: PremiumUI.primary,
                        child: _buildLiveProjects(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PremiumUI.sectionShell(
                      title: 'MY DATA LOAN / CALL ACCESS STATUS',
                      subtitle:
                          'Caller access, expiry, renewal, and revoked-safe status',
                      accentColor: PremiumUI.accent,
                      child: _buildAccessStatus(),
                    ),
                    const SizedBox(height: 24),
                    PremiumUI.sectionShell(
                      title: 'MY VISIT PROPOSALS',
                      subtitle:
                          'Proposed visits waiting for sourcing manager action',
                      accentColor: PremiumUI.warning,
                      child: _buildVisitProposals(),
                    ),
                    const SizedBox(height: 24),
                    _twoColumnSections(
                      left: PremiumUI.sectionShell(
                        title: 'MY SITE VISITS',
                        subtitle: 'Scheduled and verified walk-in proof',
                        accentColor: PremiumUI.secondary,
                        child: _buildSiteVisits(),
                      ),
                      right: PremiumUI.sectionShell(
                        title: 'MY BROKER LOCKS',
                        subtitle:
                            'Protected brokerage credit after approved visits',
                        accentColor: PremiumUI.hot,
                        child: _buildLocks(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PremiumUI.sectionShell(
                      title: 'MY BOOKING / BROKERAGE STATUS',
                      subtitle:
                          'Booking stage, lock protection, and payout visibility',
                      accentColor: PremiumUI.primary,
                      child: _buildBookingBrokerage(),
                    ),
                    const SizedBox(height: 24),
                    _twoColumnSections(
                      left: PremiumUI.sectionShell(
                        title: 'MY PERFORMANCE',
                        subtitle: 'Verified contribution developers can trust',
                        accentColor: PremiumUI.warning,
                        child: _buildPerformance(),
                      ),
                      right: PremiumUI.sectionShell(
                        title: 'MY BUSINESS IMPROVEMENT TIPS',
                        subtitle: 'Simple next moves for better conversion',
                        accentColor: PremiumUI.accent,
                        child: _buildTips(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PremiumUI.sectionShell(
                      title: 'RECENT SAFE ACTIVITY',
                      subtitle:
                          'Append-only activity trail without buyer identity leakage',
                      accentColor: PremiumUI.warning,
                      child: _buildActivityList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIdentityCard() {
    final name = '${_profile['broker_name'] ?? 'Broker'}';
    final initials = name.isEmpty ? 'B' : name.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PremiumUI.panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PremiumUI.primary.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PremiumUI.primary.withValues(alpha: 0.16),
            PremiumUI.panelColor,
            PremiumUI.accent.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: PremiumUI.primary.withValues(alpha: 0.16),
                child: Text(initials,
                    style: PremiumUI.h1
                        .copyWith(color: PremiumUI.primary, fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: PremiumUI.h1
                            .copyWith(fontSize: 22, letterSpacing: 0)),
                    const SizedBox(height: 4),
                    Text('${_profile['company_name'] ?? 'Broker Business'}',
                        style: const TextStyle(
                            color: PremiumUI.muted, fontSize: 13)),
                  ],
                ),
              ),
              PremiumUI.statusBadge(
                  '${_profile['verified_status'] ?? 'verified'}'
                      .replaceAll('_', ' '),
                  PremiumUI.secondary),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _identityChip(Icons.verified_user, 'Broker ID',
                  '${_profile['broker_code'] ?? 'BRK-LOCAL-0001'}'),
              _identityChip(Icons.place, 'Area', '${_profile['area'] ?? '-'}'),
              _identityChip(Icons.domain, 'Live Projects',
                  '${_stats['live_projects_count'] ?? 0}'),
              _identityChip(
                  Icons.manage_accounts, 'Connected SM', _managerNames()),
              _identityChip(Icons.military_tech, 'Rank',
                  '${_profile['rank'] ?? 'Silver'}'),
              _identityChip(
                  Icons.stars, 'Trust', '${_stats['trust_score'] ?? '0'}'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_profile['speciality'] ?? 'Local buyer network'}',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _identityChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: PremiumUI.primary),
          const SizedBox(width: 7),
          Text('$label: ',
              style: const TextStyle(
                  color: PremiumUI.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildNextActionStrip() {
    final action = _priorityActions.isEmpty
        ? {
            'title': 'Add 3 quality leads today',
            'body':
                'Mira Road buyer demand is strong for Wadhwa Wise City. Focus on Rs. 80L-1Cr buyers this week.',
            'color': PremiumUI.secondary,
          }
        : _priorityActions.first;

    final color = action['color'] as Color? ?? PremiumUI.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: PremiumUI.glassBox(color: color, opacity: 0.09),
      child: Row(
        children: [
          Icon(Icons.bolt, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Suggested Next Action',
                    style: PremiumUI.subtitle
                        .copyWith(color: color, fontSize: 10)),
                const SizedBox(height: 4),
                Text('${action['title']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${action['body']}',
                    style: const TextStyle(
                        color: PremiumUI.muted, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid() {
    final cards = [
      _KpiData('Total Leads', _stats['total_leads'], Icons.inventory_2,
          PremiumUI.primary),
      _KpiData('Hot Leads', _stats['hot_leads'], Icons.local_fire_department,
          PremiumUI.hot),
      _KpiData('Warm Leads', _stats['warm_leads'], Icons.thermostat,
          PremiumUI.warning),
      _KpiData('Follow-ups Due', _stats['followups_due'], Icons.event_repeat,
          PremiumUI.warning),
      _KpiData('Calls Attempted', _stats['calls_attempted'], Icons.call_made,
          PremiumUI.accent),
      _KpiData('Interested Leads', _stats['interested_leads'],
          Icons.thumb_up_alt, PremiumUI.hot),
      _KpiData('Visits Proposed', _stats['visits_proposed'],
          Icons.edit_calendar, PremiumUI.warning),
      _KpiData('Site Visits Scheduled', _stats['site_visits_scheduled'],
          Icons.calendar_month, PremiumUI.accent),
      _KpiData('Visits Done', _stats['visits_done'], Icons.how_to_reg,
          PremiumUI.secondary),
      _KpiData('Verified Visits', _stats['verified_visits'], Icons.verified,
          PremiumUI.secondary),
      _KpiData('Active Broker Locks', _stats['active_locks'], Icons.lock,
          PremiumUI.secondary),
      _KpiData('Booking Discussions', _stats['booking_discussions'],
          Icons.handshake, PremiumUI.primary),
      _KpiData('Brokerage Tracking', _stats['brokerage_tracking'],
          Icons.account_balance_wallet, PremiumUI.warning),
      _KpiData('Data Loans Active', _stats['data_loans_active'], Icons.vpn_key,
          PremiumUI.accent),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return PremiumUI.kpiCard(
            card.label, '${card.value ?? 0}', card.icon, card.color);
      },
    );
  }

  Widget _buildBusinessGrowthCards() {
    final conversion = _conversionRate();
    final rows = [
      _GrowthData('Strongest Area', '${_profile['area'] ?? 'Mira Road'}',
          Icons.location_city, PremiumUI.primary),
      _GrowthData('Best Performing Project', _bestProjectName(),
          Icons.apartment, PremiumUI.accent),
      _GrowthData('Lead-to-Visit Conversion', '$conversion%', Icons.trending_up,
          PremiumUI.secondary),
      _GrowthData('Pending Leads', '${_stats['pending_leads'] ?? 0}',
          Icons.pending_actions, PremiumUI.warning),
      _GrowthData(
          'Expired Call Permissions',
          '${_stats['expired_call_permissions'] ?? 0}',
          Icons.timer_off,
          PremiumUI.danger),
      const _GrowthData('Suggested Focus', 'Rs. 80L-1Cr buyers',
          Icons.tips_and_updates, PremiumUI.hot),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) => _growthCard(rows[index]),
    );
  }

  Widget _growthCard(_GrowthData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: PremiumUI.glassBox(color: data.color, opacity: 0.055),
      child: Row(
        children: [
          Icon(data.icon, color: data.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(data.label,
                    style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PremiumUI.cyberPanel(color: PremiumUI.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Secure Broker Business Vault + Sales Engine',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          const SizedBox(height: 8),
          const Text(
            'Lead metadata, call access, site visit proof, broker locks, booking stage, and brokerage status stay together. Sensitive buyer identity stays outside this screen.',
            style: TextStyle(color: PremiumUI.muted, height: 1.4, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumUI.statusBadge('Private lead vault', PremiumUI.secondary),
              PremiumUI.statusBadge('Caller queue safe', PremiumUI.accent),
              PremiumUI.statusBadge('Visit proof', PremiumUI.primary),
              PremiumUI.statusBadge('Brokerage protected', PremiumUI.warning),
            ],
          ),
          if (_activeGoal != null) ...[
            const SizedBox(height: 12),
            _summaryRow(
              'Monthly Target',
              '${_activeGoal?['target_leads'] ?? 0} leads / ${_activeGoal?['target_visits'] ?? 0} visits',
              PremiumUI.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final quality = '${lead['lead_quality'] ?? 'warm'}';
    final loan = '${lead['loan'] ?? 'inactive'}';
    final booking = '${lead['booking_stage'] ?? 'not_started'}';
    final brokerage = '${lead['brokerage_status'] ?? 'tracking'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: PremiumUI.statusColor(quality).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${lead['alias'] ?? 'Lead'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('Project: ${lead['project'] ?? 'Project'}',
                        style: const TextStyle(
                            color: PremiumUI.muted, fontSize: 12)),
                  ],
                ),
              ),
              PremiumUI.statusBadge(quality, PremiumUI.statusColor(quality)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaBadge(Icons.place, 'Area', '${lead['area'] ?? '-'}'),
              _metaBadge(
                  Icons.currency_rupee, 'Budget', '${lead['budget'] ?? '-'}'),
              _metaBadge(Icons.person_search, 'Buyer',
                  '${lead['buyer_type'] ?? 'end user'}'.replaceAll('_', ' ')),
              _metaBadge(Icons.rule, 'Data Quality',
                  '${lead['data_quality'] ?? 'Medium'}'),
            ],
          ),
          const SizedBox(height: 14),
          _statusGrid([
            _StatusData('Assigned To', '${lead['assigned_to'] ?? 'Unassigned'}',
                PremiumUI.accent),
            _StatusData('Call Permission', loan, PremiumUI.statusColor(loan)),
            _StatusData('Call Status', '${lead['call_status'] ?? 'pending'}',
                PremiumUI.statusColor('${lead['call_status'] ?? 'pending'}')),
            _StatusData('Follow-up', '${lead['followup'] ?? 'Not set'}',
                PremiumUI.warning),
            _StatusData(
                'Visit Status',
                '${lead['visit_status'] ?? 'not scheduled'}',
                PremiumUI.statusColor(
                    '${lead['visit_status'] ?? 'not scheduled'}')),
            _StatusData('Broker Lock', '${lead['lock'] ?? 'inactive'}',
                PremiumUI.statusColor('${lead['lock'] ?? 'inactive'}')),
            _StatusData('Booking Stage', booking.replaceAll('_', ' '),
                PremiumUI.statusColor(booking)),
            _StatusData('Brokerage Status', brokerage.replaceAll('_', ' '),
                PremiumUI.statusColor(brokerage)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _secureCallLead('${lead['id']}'),
                    icon: const Icon(Icons.security, size: 18),
                    label: const Text('Secure Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumUI.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                width: 52,
                child: IconButton.filledTonal(
                  onPressed: () => _showLeadActions(lead),
                  icon: const Icon(Icons.tune),
                  tooltip: 'Lead actions',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaBadge(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: PremiumUI.muted, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _statusGrid(List<_StatusData> rows) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.2,
      ),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: row.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: row.color.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PremiumUI.muted, fontSize: 10)),
              const SizedBox(height: 2),
              Text(row.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowups() {
    if (_followupRows.isEmpty) {
      return _emptyState('No due follow-ups right now.');
    }
    return Column(
      children: _followupRows.take(5).map((row) {
        return _compactRow(
          icon: Icons.event_available,
          title: '${row['reason'] ?? 'Broker follow-up'}',
          subtitle: 'Due: ${_formatFollowup(row['due_at'])}',
          badge: '${row['priority'] ?? 'normal'}',
          color: PremiumUI.warning,
        );
      }).toList(),
    );
  }

  Widget _buildLiveProjects() {
    if (_liveProjects.isEmpty) {
      return _emptyState('No live projects connected yet.');
    }
    return Column(
      children: _liveProjects.map((project) {
        return _compactRow(
          icon: Icons.apartment,
          title: '${project['title'] ?? 'Project'}',
          subtitle: '${project['location'] ?? ''}',
          badge: '${project['stage'] ?? 'active'}',
          color: PremiumUI.primary,
        );
      }).toList(),
    );
  }

  Widget _buildAccessStatus() {
    if (_leadRows.isEmpty) return _emptyState('No data loan records yet.');
    return Column(
      children: _leadRows.take(5).map((lead) {
        final loan = '${lead['loan'] ?? 'inactive'}';
        return _compactRow(
          icon: Icons.vpn_key,
          title: '${lead['alias'] ?? 'Lead'}',
          subtitle: 'Assigned: ${lead['assigned_to'] ?? 'Unassigned'}',
          badge: loan,
          color: PremiumUI.statusColor(loan),
        );
      }).toList(),
    );
  }

  Widget _buildVisitProposals() {
    if (_proposalRows.isEmpty) {
      return _emptyState('No visit proposals yet.');
    }
    return Column(
      children: _proposalRows.take(5).map((proposal) {
        final status = '${proposal['status'] ?? 'proposed'}';
        final project = proposal['projects'];
        final lead = proposal['leads_public'];
        final projectName = project is Map<String, dynamic>
            ? '${project['project_name'] ?? 'Project'}'
            : 'Project';
        final alias = lead is Map<String, dynamic>
            ? '${lead['alias'] ?? 'Lead'}'
            : 'Lead ${proposal['source_lead_id'] ?? ''}';
        return _compactRow(
          icon: Icons.edit_calendar,
          title: '$alias - $projectName',
          subtitle: 'Proposed: ${_formatFollowup(proposal['proposed_for'])}',
          badge: status,
          color: PremiumUI.statusColor(status),
        );
      }).toList(),
    );
  }

  Widget _buildSiteVisits() {
    if (_visitRows.isEmpty) return _emptyState('No site visits scheduled yet.');
    return Column(
      children: _visitRows.take(5).map((visit) {
        final status = '${visit['status'] ?? 'scheduled'}';
        return _compactRow(
          icon: Icons.how_to_reg,
          title: 'Visit ${visit['id'] ?? ''}',
          subtitle:
              'Lead: ${visit['source_lead_id'] ?? visit['lead_id'] ?? '-'}',
          badge: status,
          color: PremiumUI.statusColor(status),
        );
      }).toList(),
    );
  }

  Widget _buildLocks() {
    if (_lockRows.isEmpty) return _emptyState('No active broker locks yet.');
    return Column(
      children: _lockRows.take(5).map((lock) {
        final status = '${lock['status'] ?? 'inactive'}';
        return _compactRow(
          icon: Icons.lock_clock,
          title: 'Broker Lock',
          subtitle: 'Expires: ${_formatFollowup(lock['expires_at'])}',
          badge: status,
          color: PremiumUI.statusColor(status),
        );
      }).toList(),
    );
  }

  Widget _buildBookingBrokerage() {
    if (_leadRows.isEmpty) {
      return _emptyState('Booking pipeline starts after interested leads.');
    }
    return Column(
      children: _leadRows.take(5).map((lead) {
        final brokerage = '${lead['brokerage_status'] ?? 'tracking'}';
        return _compactRow(
          icon: Icons.account_balance,
          title:
              '${lead['alias'] ?? 'Lead'} - ${'${lead['booking_stage'] ?? 'not_started'}'.replaceAll('_', ' ')}',
          subtitle: 'Lock: ${lead['lock'] ?? 'inactive'}',
          badge: brokerage.replaceAll('_', ' '),
          color: PremiumUI.statusColor(brokerage),
        );
      }).toList(),
    );
  }

  Widget _buildPerformance() {
    return Column(
      children: [
        _summaryRow('Verified Performance Rank',
            '${_profile['rank'] ?? 'Silver'}', PremiumUI.warning),
        _summaryRow('Trust Score', '${_stats['trust_score'] ?? 0}',
            PremiumUI.secondary),
        _summaryRow('Lead-to-Visit Conversion', '${_conversionRate()}%',
            PremiumUI.accent),
        _summaryRow('Verified Visits', '${_stats['verified_visits'] ?? 0}',
            PremiumUI.secondary),
        _summaryRow('Active Locks', '${_stats['active_locks'] ?? 0}',
            PremiumUI.primary),
      ],
    );
  }

  Widget _buildTips() {
    final tips = [
      'Your Mira Road leads are converting better for Wadhwa Wise City. Send more Rs. 80L-1Cr buyers this week.',
      'Hot lead ko 24 hours ke andar touch karo. Follow-up miss hua to visit chance girta hai.',
      'Call access expired ho to renew suggestion use karo, direct data sharing mat karo.',
    ];
    return Column(
      children: tips.map((tip) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: PremiumUI.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(tip,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.35))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityList() {
    if (_activityRows.isEmpty) return _emptyState('No recent safe activity.');
    return Column(
      children: _activityRows.take(6).map((activity) {
        final label =
            '${activity['activity_type'] ?? 'activity'}'.replaceAll('_', ' ');
        final outcome = '${activity['outcome'] ?? ''}';
        return _compactRow(
          icon: Icons.history,
          title: label,
          subtitle: outcome.isEmpty
              ? _formatFollowup(activity['created_at'])
              : 'Outcome: ${outcome.replaceAll('_', ' ')}',
          badge: 'safe',
          color: PremiumUI.warning,
        );
      }).toList(),
    );
  }

  Widget _compactRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: PremiumUI.muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PremiumUI.statusBadge(badge, color),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 12))),
          PremiumUI.statusBadge(value, color),
        ],
      ),
    );
  }

  Widget _twoColumnSections({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message,
          style: const TextStyle(
              color: PremiumUI.muted, fontSize: 12, height: 1.35)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: PremiumUI.primary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: PremiumUI.subtitle.copyWith(
                    color: Colors.white, letterSpacing: 1.1, fontSize: 12))),
      ],
    );
  }

  Widget _largeActionCard(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [color, color.withValues(alpha: 0.74)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showLeadActions(Map<String, dynamic> lead) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${lead['alias'] ?? 'Lead'} Actions',
                    style: PremiumUI.h1.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                _actionTile(Icons.edit_calendar, 'Propose Site Visit',
                    PremiumUI.warning, () => _showProposeVisitSheet(lead)),
                _actionTile(Icons.person_add_alt_1, 'Assign to Caller',
                    PremiumUI.accent, () => _assignToCaller('${lead['id']}')),
                _actionTile(
                    Icons.supervisor_account,
                    'Assign to Sourcing Manager',
                    PremiumUI.primary,
                    () => _vaultWorkflow(
                        'assign_to_sm', {'lead_id': lead['id']})),
                _actionTile(Icons.vpn_key, 'Grant Call Access',
                    PremiumUI.secondary, () => _grantAccess('${lead['id']}')),
                _actionTile(
                    Icons.block,
                    'Revoke Call Access',
                    PremiumUI.danger,
                    () => _dataLoanWorkflow(
                        'revoke_access', {'lead_id': lead['id']})),
                _actionTile(
                    Icons.more_time,
                    'Extend Access',
                    PremiumUI.warning,
                    () => _dataLoanWorkflow('extend_access',
                        {'lead_id': lead['id'], 'duration_hours': 24})),
                _actionTile(
                    Icons.event_repeat,
                    'Set Follow-up',
                    PremiumUI.warning,
                    () => _vaultWorkflow('set_followup', {
                          'lead_id': lead['id'],
                          'next_followup_at': DateTime.now()
                              .add(const Duration(days: 1))
                              .toIso8601String()
                        })),
                _actionTile(
                    Icons.local_fire_department,
                    'Update Lead Quality',
                    PremiumUI.hot,
                    () => _vaultWorkflow('update_lead_quality',
                        {'lead_id': lead['id'], 'lead_quality': 'hot'})),
                _actionTile(
                    Icons.report_problem,
                    'Raise Issue',
                    PremiumUI.danger,
                    () => _vaultWorkflow('raise_issue', {
                          'lead_id': lead['id'],
                          'issue_type': 'brokerage_credit',
                          'notes_safe': 'Broker requested review.'
                        })),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onTap();
          },
          icon: Icon(icon, color: color, size: 18),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.25)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  void _showProposeVisitSheet(Map<String, dynamic> lead) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    final notesController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final proposedAt = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Propose Site Visit',
                        style: PremiumUI.h1.copyWith(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                        '${lead['alias'] ?? 'Lead'} - ${lead['project'] ?? _bestProjectName()}',
                        style: const TextStyle(
                            color: PremiumUI.muted, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _sheetPickerButton(
                            Icons.calendar_month,
                            _formatFollowup(proposedAt.toIso8601String()),
                            () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 45)),
                                initialDate: selectedDate,
                              );
                              if (picked != null) {
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sheetPickerButton(
                            Icons.schedule,
                            selectedTime.format(context),
                            () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setSheetState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Safe notes for SM',
                        hintStyle: const TextStyle(color: PremiumUI.muted),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _proposeSiteVisit(
                              lead, proposedAt, notesController.text);
                        },
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Send Proposal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumUI.warning,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(notesController.dispose);
  }

  Widget _sheetPickerButton(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: PremiumUI.warning, size: 18),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: PremiumUI.warning.withValues(alpha: 0.3)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _proposeSiteVisit(
      Map<String, dynamic> lead, DateTime proposedAt, String notes) async {
    final leadId = '${lead['id'] ?? ''}';
    final projectId =
        '${lead['project_id'] ?? (_liveProjects.isNotEmpty ? _liveProjects.first['id'] : '')}';
    if (leadId.isEmpty || projectId.isEmpty || projectId == 'null') {
      _showSnack('Project not connected.');
      return;
    }

    try {
      if (AppConfig.isSupabaseConfigured) {
        final response = await Supabase.instance.client.functions.invoke(
          'propose-site-visit',
          body: {
            'lead_id': leadId,
            'project_id': projectId,
            'proposed_for': proposedAt.toIso8601String(),
            'notes_safe': notes,
          },
        );
        final data = response.data as Map<String, dynamic>?;
        _showSnack(data?['ok'] == true
            ? 'Visit proposal sent.'
            : 'Visit proposal blocked.');
      } else {
        final updated = _trainingRuntime.proposeSiteVisitFromLead(
          leadId,
          proposedAt: proposedAt,
          notesSafe: notes,
        );
        _showSnack(
            updated ? 'Visit proposal sent.' : 'Visit proposal blocked.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Request failed closed.');
    }
  }

  Future<void> _secureCallLead(String leadId) async {
    if (leadId.isEmpty) return;
    try {
      if (AppConfig.isSupabaseConfigured) {
        final response = await Supabase.instance.client.functions
            .invoke('broker-self-secure-call', body: {'lead_id': leadId});
        final data = response.data as Map<String, dynamic>?;
        _showSnack(data?['ok'] == true
            ? 'Secure call queued.'
            : 'Secure call blocked.');
      } else {
        final result =
            await _trainingRuntime.initiateCall(leadId, type: 'lead');
        _showSnack(result['ok'] == true
            ? 'Secure call queued.'
            : 'Secure call blocked.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Request failed closed.');
    }
  }

  Future<void> _assignToCaller(String leadId) async {
    if (leadId.isEmpty) return;
    final callerId = _availableCallers.isEmpty
        ? null
        : '${_availableCallers.first['user_id']}';
    if (callerId == null || callerId.isEmpty) {
      _showSnack('No active caller available.');
      return;
    }
    await _vaultWorkflow('assign_to_caller',
        {'lead_id': leadId, 'caller_id': callerId, 'duration_hours': 24});
  }

  Future<void> _grantAccess(String leadId) async {
    final callerId = _availableCallers.isEmpty
        ? null
        : '${_availableCallers.first['user_id']}';
    if (callerId == null || callerId.isEmpty) {
      _showSnack('No active caller available.');
      return;
    }
    await _dataLoanWorkflow('grant_access', {
      'lead_id': leadId,
      'granted_to_user_id': callerId,
      'duration_hours': 24
    });
  }

  Future<void> _vaultWorkflow(String action, Map<String, dynamic> body) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final response = await Supabase.instance.client.functions
            .invoke('broker-vault-workflow', body: {'action': action, ...body});
        final data = response.data as Map<String, dynamic>?;
        _showSnack(
            data?['ok'] == true ? 'Vault updated.' : 'Vault update blocked.');
      } else {
        _applyTrainingVaultAction(action, body);
        _showSnack('Vault updated.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Request failed closed.');
    }
  }

  Future<void> _dataLoanWorkflow(
      String action, Map<String, dynamic> body) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final response = await Supabase.instance.client.functions
            .invoke('data-loan-workflow', body: {'action': action, ...body});
        final data = response.data as Map<String, dynamic>?;
        _showSnack(
            data?['ok'] == true ? 'Access updated.' : 'Access update blocked.');
      } else {
        _trainingRuntime.updateDataLoanStatus('${body['lead_id']}', action);
        _showSnack('Access updated.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Request failed closed.');
    }
  }

  void _applyTrainingVaultAction(String action, Map<String, dynamic> body) {
    final leadId = '${body['lead_id'] ?? ''}';
    switch (action) {
      case 'assign_to_caller':
        _trainingRuntime.assignLeadToCaller(leadId, '${body['caller_id']}');
        return;
      case 'update_lead_quality':
        _trainingRuntime.updateBrokerLeadQuality(
            leadId, '${body['lead_quality']}');
        return;
      case 'set_followup':
        _trainingRuntime.setBrokerLeadFollowup(
            leadId, DateTime.now().add(const Duration(days: 1)));
        return;
      case 'raise_issue':
        _trainingRuntime.raiseBrokerIssue(
            leadId, '${body['issue_type'] ?? 'review'}');
        return;
      default:
        _trainingRuntime.logBrokerActivity(
            TrainingRuntime.brokerId, 'note_added', 'Vault action completed.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> _buildPriorityData() {
    final rows = <Map<String, dynamic>>[];
    if (_asNum(_stats['followups_due']) > 0) {
      rows.add({
        'title': 'Follow-up due today',
        'body':
            '${_stats['followups_due']} lead(s) need a structured touch today.',
        'color': PremiumUI.warning,
      });
    }
    if (_asNum(_stats['expired_call_permissions']) > 0) {
      rows.add({
        'title': 'Renew expired access',
        'body':
            'Non-terminal leads have expired call permission. Renew only where needed.',
        'color': PremiumUI.danger,
      });
    }
    if (_asNum(_stats['interested_leads']) >
        _asNum(_stats['site_visits_scheduled'])) {
      rows.add({
        'title': 'Schedule interested buyer visits',
        'body':
            'Interested leads are waiting for sourcing manager site visit action.',
        'color': PremiumUI.accent,
      });
    }
    return rows;
  }

  bool _isVerifiedVisit(Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    return status == 'completed' ||
        status == 'verified' ||
        status == 'visit_done';
  }

  bool _isExpired(dynamic value) {
    final expiry = DateTime.tryParse('${value ?? ''}');
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  String _formatBudget(dynamic min, dynamic max) {
    final minValue = _asNum(min);
    final maxValue = _asNum(max);
    if (minValue <= 0 && maxValue <= 0) return 'Not set';
    if (maxValue <= 0) return 'Rs. ${(minValue / 100000).round()}L+';
    return 'Rs. ${(minValue / 100000).round()}L-${(maxValue / 100000).round()}L';
  }

  String _formatFollowup(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    if (date == null) return 'Not set';
    final local = date.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _safeStatus(dynamic value) {
    return '${value ?? ''}'.trim().isEmpty
        ? 'pending'
        : '${value ?? ''}'.trim().toLowerCase();
  }

  String _dataQualityLabel(num score) {
    if (score >= 75) return 'Strong';
    if (score >= 45) return 'Medium';
    return 'Weak';
  }

  String _permissionStatus(Map<String, dynamic>? loan) {
    if (loan == null) return 'inactive';
    if (_isExpired(loan['expires_at']) && loan['status'] == 'active') {
      return 'expired';
    }
    return _safeStatus(loan['status']);
  }

  String _visitStatus(Map<String, dynamic>? visit) {
    if (visit == null) return 'not scheduled';
    final status = _safeStatus(visit['status']);
    if (status == 'completed' ||
        status == 'verified' ||
        status == 'visit_done') {
      return 'verified';
    }
    return status.replaceAll('_', ' ');
  }

  String _lockStatus(Map<String, dynamic>? lock) {
    if (lock == null) return 'inactive';
    if (_isExpired(lock['expires_at']) && lock['status'] == 'active') {
      return 'expired';
    }
    return _safeStatus(lock['status']);
  }

  String _assignedTo(
      Map<String, dynamic> lead, List<Map<String, dynamic>> callers) {
    final callerId = '${lead['assigned_caller_id'] ?? ''}';
    if (callerId.isNotEmpty && callerId != 'null') {
      final caller =
          callers.where((row) => '${row['user_id']}' == callerId).toList();
      return caller.isEmpty
          ? 'Caller Assigned'
          : '${caller.first['full_name'] ?? 'Caller'}';
    }
    if ('${lead['assigned_sourcing_manager_id'] ?? ''}'.isNotEmpty &&
        '${lead['assigned_sourcing_manager_id']}' != 'null') {
      return 'Vinod SM';
    }
    return 'Unassigned';
  }

  String _managerNames() {
    if (_connectedManagers.isEmpty) return 'Vinod Gupta';
    return _connectedManagers.map((row) => '${row['name'] ?? 'SM'}').join(', ');
  }

  String _bestProjectName() {
    if (_liveProjects.isEmpty) return 'Wadhwa Wise City';
    return '${_liveProjects.first['title'] ?? 'Project'}';
  }

  int _conversionRate() {
    final total = _asNum(_stats['total_leads']);
    if (total <= 0) return 0;
    return ((_asNum(_stats['verified_visits']) / total) * 100).round();
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  String _rankFor(dynamic trustScore) {
    final score = _asNum(trustScore);
    if (score >= 4.5) return 'Gold';
    if (score >= 3.5) return 'Silver';
    if (score >= 2.5) return 'Bronze';
    return 'Review';
  }

  String _fallbackBrokerCode(Map<String, dynamic> broker) {
    final company = '${broker['company_name'] ?? 'BRK'}'
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part.characters.first.toUpperCase())
        .take(3)
        .join();
    return 'BRK-${company.isEmpty ? 'SMO' : company}-0001';
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color);

  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
}

class _GrowthData {
  const _GrowthData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatusData {
  const _StatusData(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}
