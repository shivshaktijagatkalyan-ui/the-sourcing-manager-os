import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';
import 'broker_upload.dart';
import '../widgets/complete_profile_card.dart';
import 'profile_completion_screen.dart';

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
  List<Map<String, dynamic>> _liveProjects = [];
  List<Map<String, dynamic>> _connectedManagers = [];
  List<Map<String, dynamic>> _leadRows = [];
  List<Map<String, dynamic>> _followupRows = [];
  List<Map<String, dynamic>> _visitRows = [];
  List<Map<String, dynamic>> _proposalRows = [];
  List<Map<String, dynamic>> _lockRows = [];
  List<Map<String, dynamic>> _activityRows = [];
  List<Map<String, dynamic>> _availableCallers = [];
  List<Map<String, dynamic>> _priorityActions = [];
  Map<String, dynamic>? _activeGoal;

  // UI state — filter + collapsible lead cards
  String _activeFilter = 'all';
  String _leadSearchQuery = '';
  final TextEditingController _leadSearchController = TextEditingController();
  final Set<String> _expandedLeads = {};

  List<Map<String, dynamic>> get _filteredLeads {
    Iterable<Map<String, dynamic>> rows = _leadRows;
    switch (_activeFilter) {
      case 'hot':
        rows = rows.where((l) => _safeStatus(l['lead_quality']) == 'hot');
        break;
      case 'warm':
        rows = rows.where((l) => _safeStatus(l['lead_quality']) == 'warm');
        break;
      case 'followup':
        rows = rows.where(_isLeadFollowupDue);
        break;
      case 'visit_pending':
        rows = rows.where((l) =>
            _safeStatus(l['call_status']) == 'interested' &&
            _safeStatus(l['visit_status']) == 'not scheduled');
        break;
      default:
        break;
    }
    final query = _leadSearchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      rows = rows.where((lead) {
        final haystack = [
          lead['alias'],
          lead['area'],
          lead['project'],
          lead['lead_quality'],
          lead['buyer_type'],
          lead['assigned_to'],
          lead['call_status'],
          lead['visit_status'],
          lead['booking_stage'],
          lead['brokerage_status'],
        ].map((value) => '${value ?? ''}'.toLowerCase()).join(' ');
        return haystack.contains(query);
      });
    }
    return rows.toList();
  }

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
    _leadSearchController.dispose();
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
        await _fetchLiveStats();
      } else {
        await _fetchDemoStats();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Dashboard refresh failed. Please try again.');
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
          'id, organization_id, broker_code, broker_alias, broker_name, company_name, area, city, speciality, verified_status, trust_score, verified_performance_rank, rera_number',
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
        .limit(200);

    final leads = List<Map<String, dynamic>>.from(leadRows);
    final leadIds = leads.map((row) => '${row['id']}').toList();

    // BUG-C5 FIX: each table is isolated — a single failing query never crashes the whole dashboard.

    List<Map<String, dynamic>> activations = [];
    try {
      activations = List<Map<String, dynamic>>.from(
        await client
            .from('broker_activations')
            .select(
              'id, broker_id, project_id, activation_stage, assigned_sourcing_manager_id, projects(project_name, area, city, status)',
            )
            .inFilter('broker_id', brokerIds),
      );
    } catch (_) {}

    List<Map<String, dynamic>> visits = [];
    try {
      visits = List<Map<String, dynamic>>.from(
        await client
            .from('site_visits')
            .select(
              'id, lead_id, source_lead_id, source_broker_id, status, broker_review_status, scheduled_at, created_at, leads_public(alias)',
            )
            .inFilter('source_broker_id', brokerIds),
      );
    } catch (_) {}

    // CON-4 FIX: explicit FK hint `leads_public!source_lead_id` so PostgREST resolves
    // the join via source_lead_id and not the default implicit FK.
    List<Map<String, dynamic>> proposals = [];
    try {
      proposals = List<Map<String, dynamic>>.from(
        await client
            .from('site_visit_proposals')
            .select(
              'id, source_lead_id, project_id, status, proposed_for, scheduled_at, notes_safe, created_at, projects(project_name, area, city), leads_public!source_lead_id(alias, area, city)',
            )
            .inFilter('source_broker_id', brokerIds)
            .order('proposed_for', ascending: true)
            .limit(8),
      );
    } catch (_) {}

    List<Map<String, dynamic>> locks = [];
    try {
      locks = List<Map<String, dynamic>>.from(
        await client
            .from('broker_locks')
            .select(
              'id, broker_id, lead_id, status, expires_at, brokerage_status, metadata, leads_public(alias, project_id)',
            )
            .inFilter('broker_id', brokerIds),
      );
    } catch (_) {}

    List<Map<String, dynamic>> dataLoans = [];
    if (leadIds.isNotEmpty) {
      try {
        dataLoans = List<Map<String, dynamic>>.from(
          await client
              .from('data_loans')
              .select(
                'id, lead_id, granted_to_user_id, purpose, status, expires_at, created_at',
              )
              .inFilter('lead_id', leadIds)
              .order('created_at', ascending: false),
        );
      } catch (_) {}
    }

    List<Map<String, dynamic>> callAttempts = [];
    if (leadIds.isNotEmpty) {
      try {
        callAttempts = List<Map<String, dynamic>>.from(
          await client
              .from('call_attempts')
              .select('id, lead_id, call_status, outcome, created_at')
              .inFilter('lead_id', leadIds),
        );
      } catch (_) {}
    }

    // GAP-4 FIX: include lead_id + leads_public(alias) so followup cards show
    // which lead the follow-up is about instead of just a reason string.
    List<Map<String, dynamic>> followups = [];
    try {
      followups = List<Map<String, dynamic>>.from(
        await client
            .from('broker_followups')
            .select(
                'id, broker_id, lead_id, status, due_at, priority, reason, leads_public(alias)')
            .inFilter('broker_id', brokerIds)
            .order('due_at', ascending: true)
            .limit(8),
      );
    } catch (_) {}

    List<Map<String, dynamic>> activityRows = [];
    try {
      activityRows = List<Map<String, dynamic>>.from(
        await client
            .from('broker_activity_logs')
            .select('id, activity_type, outcome, next_followup_at, created_at')
            .inFilter('broker_id', brokerIds)
            .order('created_at', ascending: false)
            .limit(8),
      );
    } catch (_) {}

    // BUG-C2 FIX: added .order + .limit(1) to prevent PostgrestException when
    // a broker has more than one active goal (maybeSingle fails on multiple rows).
    Map<String, dynamic>? goals;
    try {
      goals = await client
          .from('broker_goals')
          .select('*')
          .inFilter('broker_id', brokerIds)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {}

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
      final existing = loanByLead[key];
      final isActiveCall =
          loan['purpose'] == 'call' && loan['status'] == 'active';
      if (key.isNotEmpty &&
          (existing == null ||
              (existing['status'] != 'active' && isActiveCall))) {
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

    final safeLeadRows = leads.map((lead) {
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
        'next_followup_at': lead['next_followup_at'],
        'visit_status': _visitStatus(visit),
        'lock': _lockStatus(lock),
        'booking_stage': _safeStatus(lead['booking_stage'] ?? 'not_started'),
        'brokerage_status': _safeStatus(lead['brokerage_status'] ?? 'tracking'),
        'data_quality': dataQuality,
        'conversion_stage': conversionStage,
        'calls_attempted': callCountByLead[leadId] ?? 0,
        'project_id': lead['project_id'],
        'assigned_sourcing_manager_id': lead['assigned_sourcing_manager_id'],
        'assigned_caller_id': lead['assigned_caller_id'],
        'loan_id': loan?['id'],
        'updated_at': lead['updated_at'],
      };
    }).toList();

    final connectedManagers =
        List<Map<String, dynamic>>.from(activations).map((activation) {
      final project = activation['projects'];
      final smId = activation['assigned_sourcing_manager_id'];
      return {
        'id': smId ?? '',
        'project': project is Map<String, dynamic>
            ? '${project['project_name'] ?? 'Project'}'
            : 'Project',
        'status': activation['activation_stage'] ?? 'active',
        'leads_shared': leads.length,
        'visits_generated': List<Map<String, dynamic>>.from(visits).length,
      };
    }).toList();

    final smIds = connectedManagers
        .map((m) => '${m['id']}')
        .where((id) => id.isNotEmpty)
        .toList();
    Map<String, String> smNames = {};
    if (smIds.isNotEmpty) {
      try {
        final profileRows = await client
            .from('user_profiles')
            .select('user_id, full_name')
            .inFilter('user_id', smIds);
        for (final row in List<Map<String, dynamic>>.from(profileRows)) {
          smNames['${row['user_id']}'] =
              '${row['full_name'] ?? 'Sourcing Manager'}';
        }
      } catch (_) {}
    }

    final connectedManagersWithNames = connectedManagers.map((m) {
      final id = m['id'];
      final name = smNames[id] ?? 'Sourcing Manager';
      return {
        ...m,
        'name': name,
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
        'manager_id': activation['assigned_sourcing_manager_id'] ?? '',
        'manager_name':
            smNames['${activation['assigned_sourcing_manager_id'] ?? ''}'] ??
                'Sourcing Manager',
        'manager_status': activation['activation_stage'] ?? 'active',
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
        'rera_number': primaryBroker['rera_number'] ?? '',
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
      _liveProjects = liveProjects;
      _connectedManagers = connectedManagersWithNames;
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

  // GAP-5 FIX: surface caller-load failure so broker knows why picker is empty
  Future<List<Map<String, dynamic>>> _loadAvailableCallers(
      SupabaseClient client, String organizationId) async {
    final safeOrganizationId = organizationId.trim();
    if (safeOrganizationId.isEmpty ||
        safeOrganizationId.toLowerCase() == 'null') {
      return [];
    }
    try {
      final response = await client.rpc('get_organization_callers',
          params: {'p_org_id': safeOrganizationId});
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      if (mounted) _showSnack('Caller list unavailable. Contact your admin.');
      return [];
    }
  }

  Future<void> _fetchDemoStats() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _profile = _trainingRuntime.brokerDashboardProfile();
      _stats = _trainingRuntime.brokerDashboardStats();
      _liveProjects = _trainingRuntime.brokerLiveProjects();
      _connectedManagers = _trainingRuntime.brokerConnectedManagers();
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
          PremiumUI.statusBadge(
            AppConfig.isTrainingMode ? 'TRAINING' : 'LIVE',
            AppConfig.isTrainingMode ? PremiumUI.warning : PremiumUI.secondary,
          ),
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
                    if (_brokerProfileMissingFields().isNotEmpty) ...[
                      CompleteProfileCard(
                        role: 'broker',
                        missingFields: _brokerProfileMissingFields(),
                        onCompleteTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfileCompletionScreen(
                                      role: 'broker')));
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Issue 8 FIX: primary CTA before action strip
                    _largeActionCard(
                      'Add Secure Lead',
                      Icons.add_business,
                      PremiumUI.primary,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const BrokerUploadScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildNextActionStrip(),
                    const SizedBox(height: 20),
                    _buildKPIRibbon(),
                    const SizedBox(height: 24),
                    _buildBusinessGrowthCards(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('BROKER BUSINESS VAULT'),
                    const SizedBox(height: 12),
                    _buildVaultSummary(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('MY LEADS'),
                    const SizedBox(height: 10),
                    _buildLeadFilterBar(),
                    const SizedBox(height: 12),
                    if (_leadRows.isEmpty)
                      _emptyState(
                          'No broker leads yet. Add one secure lead to start the sales engine.')
                    else if (_filteredLeads.isEmpty)
                      _emptyState('No leads match this filter.')
                    else
                      ..._filteredLeads.map(_buildLeadCard),
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
                        subtitle:
                            'Each live project with its connected sourcing manager',
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
                      title: 'MY VISIT / LOCK PIPELINE',
                      subtitle:
                          'Lead, project, visit proposal, site visit, and broker lock in one flow',
                      accentColor: PremiumUI.warning,
                      child: _buildVisitLockPipeline(),
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
    final missingFields = _brokerProfileMissingFields();
    final profileComplete = missingFields.isEmpty;
    final badgeLabel =
        profileComplete ? 'Verified Broker Badge' : 'Profile Review Pending';
    final badgeColor = profileComplete ? PremiumUI.accent : PremiumUI.warning;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumUI.panelColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PremiumUI.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: PremiumUI.primary.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTrustScoreGauge(_asNum(_stats['trust_score'])),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: PremiumUI.h1
                            .copyWith(fontSize: 24, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('${_profile['company_name'] ?? 'Broker Business'}',
                        style: const TextStyle(
                            color: PremiumUI.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PremiumUI.statusBadge(badgeLabel, badgeColor),
                        PremiumUI.statusBadge(
                          profileComplete
                              ? '${_profile['verified_status'] ?? 'review'}'
                                  .replaceAll('_', ' ')
                              : 'data incomplete',
                          profileComplete
                              ? PremiumUI.secondary
                              : PremiumUI.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildVaultIdentityGrid(),
        ],
      ),
    );
  }

  Widget _buildTrustScoreGauge(num score) {
    final double percent = _trustScorePercent(score);
    final scoreLabel = _trustScoreLabel(score);
    final color = percent > 0.8
        ? PremiumUI.secondary
        : percent > 0.5
            ? PremiumUI.primary
            : PremiumUI.danger;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: percent,
            strokeWidth: 10,
            backgroundColor: Colors.white10,
            color: color,
          ),
        ),
        Column(
          children: [
            Text(scoreLabel,
                style: PremiumUI.h1.copyWith(fontSize: 20, color: color)),
            Text('TRUST',
                style: PremiumUI.subtitle.copyWith(fontSize: 8, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildVaultIdentityGrid() {
    final hasRera = _profile['rera_number'] != null &&
        _profile['rera_number'].toString().trim().isNotEmpty;
    final profileComplete = _brokerProfileMissingFields().isEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _identityChip(Icons.verified_user, 'ID',
            '${_profile['broker_code'] ?? 'BRK-001'}'),
        _identityChip(
            Icons.military_tech, 'RANK', '${_profile['rank'] ?? 'Silver'}'),
        _identityChip(Icons.place, 'FOCUS', '${_profile['area'] ?? '-'}'),
        if (hasRera)
          _identityChip(
              Icons.assignment_turned_in, 'RERA', '${_profile['rera_number']}',
              iconColor: PremiumUI.secondary),
        _identityChip(
          Icons.verified,
          'BADGE',
          profileComplete ? 'BLUE TICK READY' : 'DATA REVIEW PENDING',
          iconColor: profileComplete ? PremiumUI.accent : PremiumUI.warning,
        ),
        _identityChip(
          Icons.security,
          'VAULT',
          hasRera ? 'SECURED & UNLOCKED' : 'LOCKED (READ-ONLY)',
          iconColor: hasRera ? PremiumUI.secondary : PremiumUI.warning,
        ),
      ],
    );
  }

  Widget _identityChip(IconData icon, String label, String value,
      {Color iconColor = PremiumUI.primary}) {
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
          Icon(icon, size: 15, color: iconColor),
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
                'Focus on your strongest active project and add qualified buyers to the protected broker vault.',
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

  Widget _buildKPIRibbon() {
    final cards = [
      _KpiData('TOTAL LEADS', _stats['total_leads'], Icons.inventory_2_outlined,
          PremiumUI.primary),
      _KpiData('HOT LEADS', _stats['hot_leads'],
          Icons.local_fire_department_outlined, PremiumUI.hot),
      _KpiData('45-DAY LOCKS', _stats['active_locks'],
          Icons.lock_clock_outlined, PremiumUI.secondary),
      _KpiData('VERIFIED VISITS', _stats['verified_visits'],
          Icons.verified_user_outlined, PremiumUI.secondary),
      _KpiData('Visits Proposed', _stats['visits_proposed'],
          Icons.edit_calendar_outlined, PremiumUI.warning),
      _KpiData('Visits Done', _stats['visits_done'], Icons.how_to_reg_outlined,
          PremiumUI.secondary),
      _KpiData('FOLLOW-UPS', _stats['followups_due'],
          Icons.event_repeat_outlined, PremiumUI.warning),
      _KpiData('CALLS DONE', _stats['calls_attempted'],
          Icons.call_made_outlined, PremiumUI.accent),
      _KpiData('DATA LOANS', _stats['data_loans_active'],
          Icons.vpn_key_outlined, PremiumUI.accent),
      _KpiData('WARM LEADS', _stats['warm_leads'], Icons.thermostat_outlined,
          PremiumUI.warning),
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final card = cards[index];
          return GestureDetector(
            onTap: () => _handleKpiTap(card),
            child: _kpiRibbonCard(card, tappable: true),
          );
        },
      ),
    );
  }

  void _handleKpiTap(_KpiData card) {
    switch (card.label) {
      case 'HOT LEADS':
        setState(() => _activeFilter = 'hot');
        _showSnack('Filtered to hot leads.');
        return;
      case 'FOLLOW-UPS':
        setState(() => _activeFilter = 'followup');
        _showSnack('Filtered to follow-up due leads.');
        return;
      case 'VERIFIED VISITS':
        _showVerifiedVisitsSheet();
        return;
      default:
        _showSnack('${card.label}: ${card.value ?? 0}');
    }
  }

  void _showVerifiedVisitsSheet() {
    final verified = _visitRows.where(_isVerifiedVisit).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verified Visits',
                  style: PremiumUI.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                '${verified.length} verified visit(s) are currently counted for this broker.',
                style: const TextStyle(color: PremiumUI.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              if (verified.isEmpty)
                _emptyState('No verified visits yet.')
              else
                ...verified.take(5).map((visit) {
                  final leadData = visit['leads_public'];
                  final alias = leadData is Map<String, dynamic>
                      ? '${leadData['alias'] ?? 'Lead'}'
                      : 'Lead';
                  return _compactRow(
                    icon: Icons.verified_user_outlined,
                    title: alias,
                    subtitle:
                        'Visit: ${_formatFollowup(visit['scheduled_at'] ?? visit['created_at'])}',
                    badge: '${visit['status'] ?? 'verified'}',
                    color: PremiumUI.secondary,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // Issue 2 + 4 FIX: searchable lead workbench and filter chips
  Widget _buildLeadFilterBar() {
    final filters = [
      ('all', 'All', null),
      ('hot', 'Hot', PremiumUI.hot),
      ('warm', 'Warm', PremiumUI.warning),
      ('followup', 'Follow-up Due', PremiumUI.accent),
      ('visit_pending', 'Visit Pending', PremiumUI.secondary),
    ];
    final filteredCount = _filteredLeads.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _leadSearchController,
          onChanged: (value) => setState(() => _leadSearchQuery = value),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by alias, area, project, stage, or assignment',
            hintStyle: const TextStyle(color: PremiumUI.muted, fontSize: 12),
            prefixIcon:
                const Icon(Icons.search, color: PremiumUI.muted, size: 18),
            suffixIcon: _leadSearchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close,
                        color: PremiumUI.muted, size: 18),
                    onPressed: () {
                      _leadSearchController.clear();
                      setState(() => _leadSearchQuery = '');
                    },
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: PremiumUI.primary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final isActive = _activeFilter == f.$1;
              final color = f.$3 ?? PremiumUI.primary;
              return GestureDetector(
                onTap: () => setState(() => _activeFilter = f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? color
                          : Colors.white.withValues(alpha: 0.1),
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    f.$2,
                    style: TextStyle(
                      color: isActive ? color : PremiumUI.muted,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Showing $filteredCount of ${_leadRows.length} loaded lead(s).',
          style: const TextStyle(color: PremiumUI.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _kpiRibbonCard(_KpiData card, {bool tappable = false}) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tappable
              ? card.color.withValues(alpha: 0.4)
              : card.color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
              color: card.color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  card.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: PremiumUI.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              Icon(card.icon,
                  color: card.color.withValues(alpha: tappable ? 0.9 : 0.5),
                  size: 14),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${card.value ?? 0}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron'),
              ),
              if (tappable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.filter_list, size: 10, color: PremiumUI.muted),
              ],
            ],
          ),
        ],
      ),
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
        childAspectRatio: 2.05,
      ),
      itemBuilder: (context, index) => _growthCard(rows[index]),
    );
  }

  Widget _growthCard(_GrowthData data) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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
    final visitStatus = '${lead['visit_status'] ?? 'not scheduled'}';
    final callStatus = '${lead['call_status'] ?? 'pending'}';
    final lockStatus = '${lead['lock'] ?? 'inactive'}';
    final leadId = '${lead['id'] ?? ''}';
    final isExpanded = _expandedLeads.contains(leadId);

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
          // Header row
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
                    const SizedBox(height: 4),
                    Text('${lead['project'] ?? 'Project'}  •  ${lead['area'] ?? '-'}',
                        style: const TextStyle(
                            color: PremiumUI.muted, fontSize: 12)),
                  ],
                ),
              ),
              PremiumUI.statusBadge(quality, PremiumUI.statusColor(quality)),
            ],
          ),
          const SizedBox(height: 10),
          // Compact 3-badge strip — always visible (Issue 1 FIX)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metaBadge(Icons.currency_rupee, 'Budget', '${lead['budget'] ?? '-'}'),
              _statusStripBadge(Icons.call, callStatus),
              _statusStripBadge(Icons.event_available, visitStatus),
              _statusStripBadge(Icons.lock_clock, lockStatus),
            ],
          ),
          // Expandable detail grid (Issue 1 FIX)
          if (isExpanded) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaBadge(Icons.person_search, 'Buyer',
                    '${lead['buyer_type'] ?? 'end user'}'.replaceAll('_', ' ')),
                _metaBadge(Icons.rule, 'Data Quality',
                    '${lead['data_quality'] ?? 'Medium'}'),
              ],
            ),
            const SizedBox(height: 10),
            _statusGrid([
              _StatusData('Assigned To', '${lead['assigned_to'] ?? 'Unassigned'}',
                  PremiumUI.accent),
              _StatusData('Call Permission', loan, PremiumUI.statusColor(loan)),
              _StatusData('Follow-up', '${lead['followup'] ?? 'Not set'}',
                  PremiumUI.warning),
              _StatusData('Booking Stage', booking.replaceAll('_', ' '),
                  PremiumUI.statusColor(booking)),
              _StatusData('Brokerage Status', brokerage.replaceAll('_', ' '),
                  PremiumUI.statusColor(brokerage)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _secureCallLead('${lead['id']}'),
                    icon: const Icon(Icons.security, size: 16),
                    label: const Text('Secure Call',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumUI.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                width: 44,
                child: IconButton.filledTonal(
                  onPressed: () => _showLeadActions(lead),
                  icon: const Icon(Icons.tune, size: 18),
                  tooltip: 'Lead actions',
                ),
              ),
              const SizedBox(width: 8),
              // Expand/collapse toggle
              SizedBox(
                height: 44,
                width: 44,
                child: IconButton(
                  onPressed: () => setState(() {
                    if (isExpanded) {
                      _expandedLeads.remove(leadId);
                    } else {
                      _expandedLeads.add(leadId);
                    }
                  }),
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: PremiumUI.muted,
                    size: 20,
                  ),
                  tooltip: isExpanded ? 'Collapse' : 'View details',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusStripBadge(IconData icon, String status) {
    final color = PremiumUI.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            status.replaceAll('_', ' '),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800),
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
        mainAxisExtent: 64,
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
    // Issue 5 FIX: sort by due_at, triage overdue / today / upcoming
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sorted = [..._followupRows]
      ..sort((a, b) {
        final da = DateTime.tryParse('${a['due_at'] ?? ''}') ?? DateTime(2099);
        final db = DateTime.tryParse('${b['due_at'] ?? ''}') ?? DateTime(2099);
        return da.compareTo(db);
      });
    return Column(
      children: sorted.take(5).map((row) {
        final dueAt = DateTime.tryParse('${row['due_at'] ?? ''}');
        final dueDay = dueAt != null
            ? DateTime(dueAt.year, dueAt.month, dueAt.day)
            : null;
        final isOverdue = dueDay != null && dueDay.isBefore(today);
        final isToday = dueDay != null && dueDay.isAtSameMomentAs(today);
        final borderColor = isOverdue
            ? PremiumUI.danger
            : isToday
                ? PremiumUI.warning
                : PremiumUI.muted.withValues(alpha: 0.3);
        final leadData = row['leads_public'];
        final leadAlias = leadData is Map<String, dynamic>
            ? ' — ${leadData['alias'] ?? ''}'
            : '';
        final urgencyLabel = isOverdue
            ? 'OVERDUE'
            : isToday
                ? 'TODAY'
                : '${row['priority'] ?? 'normal'}';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: borderColor, width: 3),
            ),
          ),
          child: _compactRow(
            icon: Icons.event_available,
            title: '${row['reason'] ?? 'Broker follow-up'}$leadAlias',
            subtitle: 'Due: ${_formatFollowup(row['due_at'])}',
            badge: urgencyLabel,
            color: isOverdue
                ? PremiumUI.danger
                : isToday
                    ? PremiumUI.warning
                    : PremiumUI.muted,
            noBg: true,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveProjects() {
    if (_liveProjects.isEmpty) {
      return _emptyState('No live projects connected yet.');
    }
    return Column(
      children: _liveProjects.map(_buildLiveProjectManagerCard).toList(),
    );
  }

  Widget _buildLiveProjectManagerCard(Map<String, dynamic> project) {
    final manager = _connectedManagerForProject(project);
    final managerName =
        '${project['manager_name'] ?? manager?['name'] ?? 'Sourcing Manager'}';
    final managerStatus =
        '${project['manager_status'] ?? manager?['status'] ?? 'active'}';
    final leadsShared = project['leads_given'] ?? manager?['leads_shared'] ?? 0;
    final visitsGenerated =
        project['verified_visits'] ?? manager?['visits_generated'] ?? 0;
    final stage = '${project['stage'] ?? 'active'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.apartment, color: PremiumUI.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${project['title'] ?? 'Project'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${project['location'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PremiumUI.statusBadge(stage, PremiumUI.primary),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _inlineInfoChip(
                  Icons.person_pin, 'SM: $managerName', PremiumUI.secondary),
              _inlineInfoChip(Icons.verified_user,
                  managerStatus.replaceAll('_', ' '), PremiumUI.secondary),
              _inlineInfoChip(
                  Icons.group, '$leadsShared leads', PremiumUI.accent),
              _inlineInfoChip(Icons.how_to_reg, '$visitsGenerated visits',
                  PremiumUI.warning),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _connectedManagerForProject(
      Map<String, dynamic> project) {
    final projectTitle = '${project['title'] ?? ''}'.toLowerCase();
    final managerId = '${project['manager_id'] ?? ''}';
    for (final manager in _connectedManagers) {
      final candidateProject = '${manager['project'] ?? ''}'.toLowerCase();
      final candidateId = '${manager['id'] ?? ''}';
      if (managerId.isNotEmpty && managerId == candidateId) return manager;
      if (projectTitle.isNotEmpty && candidateProject.contains(projectTitle)) {
        return manager;
      }
    }
    return null;
  }

  Widget _inlineInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessStatus() {
    if (_leadRows.isEmpty) return _emptyState('No data loan records yet.');
    // Issue 6 FIX: expired loans always shown first with a banner
    final expired = _leadRows.where((l) => l['loan'] == 'expired').toList();
    final active = _leadRows.where((l) => l['loan'] != 'expired').toList();
    final ordered = [...expired, ...active].take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expired.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: PremiumUI.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PremiumUI.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: PremiumUI.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${expired.length} expired call permission(s). Renew access to re-enable caller.',
                    style: const TextStyle(
                        color: PremiumUI.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ...ordered.map((lead) {
          final loan = '${lead['loan'] ?? 'inactive'}';
          final isExpired = loan == 'expired';
          return _compactRow(
            icon: Icons.vpn_key,
            title: '${lead['alias'] ?? 'Lead'}',
            subtitle: 'Assigned: ${lead['assigned_to'] ?? 'Unassigned'}',
            badge: isExpired ? 'EXPIRED' : loan,
            color: PremiumUI.statusColor(loan),
            trailing:
                isExpired ? _renewAccessChip(() => _renewCallAccess(lead)) : null,
          );
        }),
      ],
    );
  }

  Widget _renewAccessChip(VoidCallback onPressed) {
    return ActionChip(
      avatar: const Icon(Icons.warning_amber_rounded,
          color: Colors.white, size: 14),
      label: const Text('EXPIRED - RENEW'),
      onPressed: onPressed,
      backgroundColor: PremiumUI.danger,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  void _renewCallAccess(Map<String, dynamic> lead) {
    final leadId = '${lead['id'] ?? ''}';
    if (leadId.isEmpty) return;
    final loanId = '${lead['loan_id'] ?? ''}';
    if (loanId.isEmpty || loanId == 'null') {
      _grantAccess(leadId);
      return;
    }
    _dataLoanWorkflow('extend_access', {
      'lead_id': leadId,
      'duration_hours': 24,
      'loan_id': loanId,
      'purpose': 'call',
    });
  }

  Widget _buildVisitLockPipeline() {
    final rows = _visitLockPipelineRows();
    if (rows.isEmpty) {
      return _emptyState('No visit or broker lock movement yet.');
    }
    return Column(
      children: rows.take(8).map(_buildVisitLockPipelineCard).toList(),
    );
  }

  List<Map<String, dynamic>> _visitLockPipelineRows() {
    final rows = <String, Map<String, dynamic>>{};

    Map<String, dynamic> ensureRow(String key) {
      return rows.putIfAbsent(
        key,
        () => {
          'lead_id': key,
          'safe_alias': 'Lead',
          'project_name': 'Project',
          'proposal_status': 'pending',
          'proposal_time': 'Not proposed',
          'visit_status': 'not scheduled',
          'visit_time': 'Date pending',
          'lock_status': 'inactive',
          'lock_expiry': 'No lock',
          'booking_stage': 'not started',
          'brokerage_status': 'tracking',
          'has_pipeline_activity': false,
        },
      );
    }

    for (final lead in _leadRows) {
      final key = _pipelineKey(lead, const ['id', 'alias']);
      if (key.isEmpty) continue;
      ensureRow(key).addAll({
        'safe_alias': '${lead['alias'] ?? 'Lead'}',
        'project_name': '${lead['project'] ?? 'Project'}',
        'visit_status': '${lead['visit_status'] ?? 'not scheduled'}',
        'lock_status': '${lead['lock'] ?? 'inactive'}',
        'booking_stage':
            '${lead['booking_stage'] ?? 'not_started'}'.replaceAll('_', ' '),
        'brokerage_status':
            '${lead['brokerage_status'] ?? 'tracking'}'.replaceAll('_', ' '),
      });
    }

    for (final proposal in _proposalRows) {
      final key =
          _pipelineKey(proposal, const ['source_lead_id', 'lead_id', 'id']);
      if (key.isEmpty) continue;
      final projectName = _projectNameFromRelation(
        proposal['projects'],
        '${proposal['project_name'] ?? 'Project'}',
      );
      final leadAlias = _leadAliasFromRelation(
        proposal['leads_public'] ?? proposal['leads_public!source_lead_id'],
        rows[key]?['safe_alias'] ?? 'Lead ${proposal['source_lead_id'] ?? ''}',
      );
      ensureRow(key).addAll({
        'safe_alias': leadAlias,
        'project_name': projectName,
        'proposal_status': '${proposal['status'] ?? 'proposed'}',
        'proposal_time': _formatFollowup(
          proposal['scheduled_at'] ?? proposal['proposed_for'],
        ),
        'has_pipeline_activity': true,
      });
    }

    for (final visit in _visitRows) {
      final key =
          _pipelineKey(visit, const ['source_lead_id', 'lead_id', 'id']);
      if (key.isEmpty) continue;
      final leadAlias = _leadAliasFromRelation(
        visit['leads_public'],
        rows[key]?['safe_alias'] ?? 'Lead ${visit['lead_id'] ?? ''}',
      );
      ensureRow(key).addAll({
        'safe_alias': leadAlias,
        'visit_status': '${visit['status'] ?? 'scheduled'}',
        'visit_time': _formatFollowup(
          visit['scheduled_at'] ?? visit['created_at'],
        ),
        'visit_review': '${visit['broker_review_status'] ?? ''}',
        'has_pipeline_activity': true,
      });
    }

    for (final lock in _lockRows) {
      final key = _pipelineKey(lock, const ['lead_id', 'source_lead_id', 'id']);
      if (key.isEmpty) continue;
      final leadAlias = _leadAliasFromRelation(
        lock['leads_public'],
        rows[key]?['safe_alias'] ?? 'Lead ${lock['lead_id'] ?? ''}',
      );
      ensureRow(key).addAll({
        'safe_alias': leadAlias,
        'lock_status': '${lock['status'] ?? 'active'}',
        'lock_expiry': _lockExpiryLabel(lock['expires_at']),
        'brokerage_status':
            '${lock['brokerage_status'] ?? 'tracking'}'.replaceAll('_', ' '),
        'has_pipeline_activity': true,
      });
    }

    return rows.values
        .where((row) => row['has_pipeline_activity'] == true)
        .toList();
  }

  Widget _buildVisitLockPipelineCard(Map<String, dynamic> row) {
    final proposal = '${row['proposal_status'] ?? 'pending'}';
    final visit = '${row['visit_status'] ?? 'not scheduled'}';
    final lock = '${row['lock_status'] ?? 'inactive'}';
    final brokerage = '${row['brokerage_status'] ?? 'tracking'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.route, color: PremiumUI.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['safe_alias'] ?? 'Lead'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Project: ${row['project_name'] ?? 'Project'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PremiumUI.statusBadge(visit, PremiumUI.statusColor(visit)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _inlineInfoChip(
                Icons.edit_calendar,
                'Proposal: ${proposal.replaceAll('_', ' ')}',
                PremiumUI.warning,
              ),
              _inlineInfoChip(
                Icons.event_available,
                '${row['proposal_time'] ?? 'Date pending'}',
                PremiumUI.warning,
              ),
              _inlineInfoChip(
                Icons.how_to_reg,
                'Visit: ${visit.replaceAll('_', ' ')}',
                PremiumUI.secondary,
              ),
              _inlineInfoChip(
                Icons.lock_clock,
                'Lock: ${lock.replaceAll('_', ' ')}',
                PremiumUI.hot,
              ),
              _inlineInfoChip(
                Icons.account_balance,
                'Brokerage: ${brokerage.replaceAll('_', ' ')}',
                PremiumUI.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pipelineKey(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  String _projectNameFromRelation(dynamic relation, String fallback) {
    if (relation is Map) {
      final name = '${relation['project_name'] ?? relation['name'] ?? ''}';
      if (name.trim().isNotEmpty) return name;
    }
    return fallback.trim().isEmpty ? 'Project' : fallback;
  }

  String _leadAliasFromRelation(dynamic relation, Object? fallback) {
    if (relation is Map) {
      final alias = '${relation['alias'] ?? ''}';
      if (alias.trim().isNotEmpty) return alias;
    }
    final fallbackText = '${fallback ?? ''}'.trim();
    return fallbackText.isEmpty ? 'Lead' : fallbackText;
  }

  String _lockExpiryLabel(dynamic value) {
    final expiry = DateTime.tryParse('${value ?? ''}');
    if (expiry == null) return 'No expiry';
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return 'Expired';
    if (daysLeft == 0) return 'Expires today';
    return '$daysLeft days left';
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
    final missingFields = _brokerProfileMissingFields();
    return Column(
      children: [
        _buildPerformanceGoalCard(missingFields),
        const SizedBox(height: 12),
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

  Widget _buildPerformanceGoalCard(List<String> missingFields) {
    final profileAction = missingFields.isEmpty
        ? 'Profile data complete. Keep trust score high for badge review.'
        : 'Complete ${missingFields.first} to start broker badge review.';
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.all(12),
      decoration: PremiumUI.glassBox(color: PremiumUI.accent, opacity: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Goal Path',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _inlineInfoChip(
                Icons.verified,
                missingFields.isEmpty
                    ? 'Badge: review ready'
                    : 'Badge: data pending',
                missingFields.isEmpty ? PremiumUI.accent : PremiumUI.warning,
              ),
              _inlineInfoChip(
                Icons.flag,
                _goalGapLabel(),
                PremiumUI.primary,
              ),
              _inlineInfoChip(
                Icons.trending_up,
                'Trust: ${_stats['trust_score'] ?? 0}',
                PremiumUI.secondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profileAction,
            style: const TextStyle(
              color: PremiumUI.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    // Issue 9 FIX: all tips in consistent English
    final tips = [
      'Contact hot leads within 24 hours. A missed follow-up reduces the chance of converting to a site visit.',
      'If a lead is interested but has no visit scheduled, assign to your Sourcing Manager immediately.',
      'When call access expires, use the Extend Access action — never share buyer details directly.',
      'After a verified site visit, check your Broker Lock status. Your payout protection depends on it.',
      'If a booking discussion has been silent for 48 hours, ask your SM to push the caller to start token discussion.',
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
    bool noBg = false,
    Widget? trailing,
  }) {
    return Container(
      margin: noBg ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: noBg
          ? null
          : BoxDecoration(
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
          trailing ?? PremiumUI.statusBadge(badge, color),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${lead['alias'] ?? 'Lead'} Actions',
                    style: PremiumUI.h1.copyWith(fontSize: 18)),
                const SizedBox(height: 16),
                // Issue 3 FIX: 3 grouped sections
                _actionGroupHeader('📞  Call & Access'),
                _actionTile(Icons.security, 'Secure Call',
                    PremiumUI.secondary, () => _secureCallLead('${lead['id']}')),
                _actionTile(Icons.person_add_alt_1, 'Assign to Caller',
                    PremiumUI.accent, () => _assignToCaller('${lead['id']}')),
                _actionTile(Icons.vpn_key, 'Grant Call Access',
                    PremiumUI.secondary, () => _grantAccess('${lead['id']}')),
                _actionTile(
                    Icons.more_time, 'Extend Access', PremiumUI.warning,
                    () => _dataLoanWorkflow('extend_access', {
                          'lead_id': lead['id'],
                          'duration_hours': 24,
                          'loan_id': lead['loan_id'],
                          'purpose': 'call',
                        })),
                _actionTile(
                    Icons.block, 'Revoke Call Access', PremiumUI.danger,
                    () => _dataLoanWorkflow('revoke_access', {
                          'lead_id': lead['id'],
                          'loan_id': lead['loan_id'],
                          'purpose': 'call',
                        })),
                const SizedBox(height: 12),
                _actionGroupHeader('📅  Visit & Follow-up'),
                _actionTile(Icons.edit_calendar, 'Propose Site Visit',
                    PremiumUI.warning, () => _showProposeVisitSheet(lead)),
                _actionTile(Icons.event_repeat, 'Set Follow-up',
                    PremiumUI.warning, () => _showFollowupDatePicker(lead)),
                _actionTile(Icons.rate_review, 'Review Site Visit',
                    PremiumUI.secondary, () => _showReviewVisitSheet(lead)),
                const SizedBox(height: 12),
                _actionGroupHeader('📈  Pipeline & Status'),
                _actionTile(Icons.supervisor_account,
                    'Assign to Sourcing Manager', PremiumUI.primary,
                    () => _showSmPicker('${lead['id']}')),
                _actionTile(Icons.local_fire_department, 'Update Lead Quality',
                    PremiumUI.hot, () => _showQualityPicker(lead)),
                _actionTile(Icons.book_online, 'Update Booking Stage',
                    PremiumUI.primary, () => _showBookingStageSheet(lead)),
                _actionTile(Icons.account_balance_wallet,
                    'Update Brokerage Status', PremiumUI.accent,
                    () => _showBrokerageStatusSheet(lead)),
                _actionTile(Icons.report_problem, 'Raise Issue',
                    PremiumUI.danger,
                    () => _vaultWorkflow('raise_issue', {
                          'lead_id': lead['id'],
                          'issue_type': 'brokerage_credit',
                          'notes_safe': 'Broker requested review.',
                        })),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionGroupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: PremiumUI.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
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

  // GAP-1 FIX: quality picker so broker can set any valid quality, not just 'hot'
  void _showQualityPicker(Map<String, dynamic> lead) {
    const qualities = [
      'hot',
      'warm',
      'cold',
      'investor',
      'end_user',
      'site_visit_ready',
      'loan_required',
      'family_decision_pending',
      'budget_matched',
      'location_matched',
      'low_quality',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Lead Quality',
                  style: PremiumUI.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: qualities.map((q) {
                  final color = PremiumUI.statusColor(q);
                  return ActionChip(
                    label: Text(q.replaceAll('_', ' '),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    backgroundColor: color.withValues(alpha: 0.2),
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _vaultWorkflow('update_lead_quality',
                          {'lead_id': lead['id'], 'lead_quality': q});
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // GAP-2 FIX: date picker for set_followup instead of hardcoded +1 day
  void _showFollowupDatePicker(Map<String, dynamic> lead) {
    showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: DateTime.now().add(const Duration(days: 1)),
    ).then((picked) {
      if (picked == null || !mounted) return;
      _vaultWorkflow('set_followup', {
        'lead_id': lead['id'],
        'next_followup_at':
            picked.copyWith(hour: 10, minute: 0).toIso8601String(),
      });
    });
  }

  // GAP-3 FIX: booking stage picker
  void _showBookingStageSheet(Map<String, dynamic> lead) {
    const stages = [
      'not_started',
      'booking_discussion',
      'token_discussion',
      'token_paid',
      'booking_confirmed',
      'loan_legal_started',
      'agreement_pending',
      'payment_pending',
      'closed',
      'lost',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Booking Stage',
                  style: PremiumUI.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stages.map((s) {
                  final color = PremiumUI.statusColor(s);
                  return ActionChip(
                    label: Text(s.replaceAll('_', ' '),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    backgroundColor: color.withValues(alpha: 0.15),
                    side: BorderSide(color: color.withValues(alpha: 0.35)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _vaultWorkflow('update_booking_stage',
                          {'lead_id': lead['id'], 'booking_stage': s});
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // GAP-3 FIX: brokerage status picker
  void _showBrokerageStatusSheet(Map<String, dynamic> lead) {
    const statuses = [
      'tracking',
      'pending_visit',
      'locked',
      'eligible',
      'paid',
      'disputed',
      'blocked',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Brokerage Status',
                  style: PremiumUI.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: statuses.map((s) {
                  final color = PremiumUI.statusColor(s);
                  return ActionChip(
                    label: Text(s.replaceAll('_', ' '),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    backgroundColor: color.withValues(alpha: 0.15),
                    side: BorderSide(color: color.withValues(alpha: 0.35)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _vaultWorkflow('update_brokerage_status',
                          {'lead_id': lead['id'], 'brokerage_status': s});
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
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
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
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
      _showSnack('Action failed. Please try again.');
    }
  }

  Future<void> _secureCallLead(String leadId) async {
    if (leadId.isEmpty) return;
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
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
      _showSnack('Action failed. Please try again.');
    }
  }

  Future<void> _assignToCaller(String leadId) async {
    if (leadId.isEmpty) return;
    // Issue 7 FIX: always open the sheet — show a descriptive empty state inside
    _showCallerPicker(leadId);
  }

  void _showCallerPicker(String leadId) {
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
                Text('Assign Caller',
                    style: PremiumUI.h1.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                if (_availableCallers.isEmpty)
                  // Issue 7 FIX: descriptive guidance instead of a blank sheet
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PremiumUI.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PremiumUI.accent.withValues(alpha: 0.18)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: PremiumUI.accent, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No callers are assigned to your organization yet. Contact your Sourcing Manager to activate callers.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._availableCallers.map((caller) {
                    // RPC may return user_id or id — try both keys
                    final callerId =
                        '${caller['user_id'] ?? caller['id'] ?? ''}';
                    final callerName =
                        '${caller['full_name'] ?? caller['name'] ?? 'Caller'}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.support_agent,
                          color: PremiumUI.accent),
                      title: Text(callerName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      subtitle: const Text('Grant 24h secure call access',
                          style: TextStyle(color: PremiumUI.muted)),
                      onTap: callerId.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _assignLeadToCaller(leadId, callerId);
                            },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _assignLeadToCaller(String leadId, String callerId) async {
    await _vaultWorkflow('assign_to_caller',
        {'lead_id': leadId, 'caller_id': callerId, 'duration_hours': 24});
  }

  // FIX: SM picker — shows connected managers, never silently passes null
  void _showSmPicker(String leadId) {
    final managers = _connectedManagers
        .where((m) => '${m['id'] ?? ''}'.isNotEmpty && m['id'] != 'null')
        .toList();
    if (managers.isEmpty) {
      _showSnack('No sourcing managers connected. Contact your admin.');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign to Sourcing Manager',
                  style: PremiumUI.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              ...managers.map((m) {
                final smId = '${m['id']}';
                final smName = '${m['name'] ?? 'Sourcing Manager'}';
                final project = '${m['project'] ?? 'Project'}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.person_pin, color: PremiumUI.primary),
                  title: Text(smName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text('Project: $project',
                      style: const TextStyle(color: PremiumUI.muted)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _vaultWorkflow('assign_to_sm', {
                      'lead_id': leadId,
                      'sourcing_manager_id': smId,
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // FIX: Route grant-access through caller picker — caller_id must go to vault assign_to_caller
  Future<void> _grantAccess(String leadId) async {
    if (_availableCallers.isEmpty) {
      _showSnack('No active caller available.');
      return;
    }
    _showCallerPicker(leadId);
  }

  // FIX: Review site visit — show approve/reject sheet for pending-review visits of this lead
  void _showReviewVisitSheet(Map<String, dynamic> lead) {
    final leadId = '${lead['id'] ?? ''}';
    final pendingVisits = _visitRows
        .where((v) =>
            ('${v['source_lead_id'] ?? v['lead_id'] ?? ''}' == leadId ||
                leadId.isEmpty) &&
            _safeStatus(v['broker_review_status']) == 'pending' &&
            (v['status'] == 'broker_review_pending' ||
                v['status'] == 'photo_verified' ||
                v['status'] == 'visit_done'))
        .toList();

    if (pendingVisits.isEmpty) {
      _showSnack('No verified visit pending your review for this lead.');
      return;
    }

    final visit = pendingVisits.first;
    final visitId = '${visit['id'] ?? ''}';
    final notesController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PremiumUI.panelColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review Site Visit',
                  style: PremiumUI.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                '${lead['alias'] ?? 'Lead'} — visit on ${_formatFollowup(visit['scheduled_at'] ?? visit['created_at'])}',
                style:
                    const TextStyle(color: PremiumUI.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Optional notes (no buyer identity)',
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
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _reviewSiteVisit(
                              visitId, 'approve', notesController.text);
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve'),
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
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _reviewSiteVisit(
                              visitId, 'reject', notesController.text);
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Dispute'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumUI.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(notesController.dispose);
  }

  Future<void> _reviewSiteVisit(
      String visitId, String action, String reason) async {
    if (visitId.isEmpty) return;
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final response =
            await Supabase.instance.client.functions.invoke(
          'broker-review-site-visit',
          body: {
            'site_visit_id': visitId,
            'action': action,
            'reason': reason.isEmpty ? null : reason,
          },
        );
        final data = response.data as Map<String, dynamic>?;
        _showSnack(data?['ok'] == true
            ? 'Visit ${action == 'approve' ? 'approved' : 'disputed'}.'
            : 'Review blocked: ${data?['reason'] ?? 'failed'}');
      } else {
        // Training mode: flip broker_review_status locally
        _trainingRuntime.reviewSiteVisit(visitId, action);
        _showSnack(
            'Visit ${action == 'approve' ? 'approved' : 'disputed'} (training).');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Review action failed. Please try again.');
    }
  }

  Future<void> _vaultWorkflow(String action, Map<String, dynamic> body) async {
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final response = await Supabase.instance.client.functions
            .invoke('broker-vault-workflow', body: {'action': action, ...body});
        final data = response.data as Map<String, dynamic>?;
        // BUG-C3 FIX: surface the reason code so broker knows why action failed
        _showSnack(data?['ok'] == true
            ? 'Vault updated.'
            : 'Blocked: ${data?['reason'] ?? 'action failed'}');
      } else {
        _applyTrainingVaultAction(action, body);
        _showSnack('Vault updated.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Action failed. Please try again.');
    }
  }

  Future<void> _dataLoanWorkflow(
      String action, Map<String, dynamic> body) async {
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final response = await Supabase.instance.client.functions
            .invoke('data-loan-workflow', body: {'action': action, ...body});
        final data = response.data as Map<String, dynamic>?;
        _showSnack(data?['ok'] == true
            ? 'Access updated.'
            : 'Blocked: ${data?['reason'] ?? 'action failed'}');
      } else {
        _trainingRuntime.updateDataLoanStatus(
          '${body['lead_id']}',
          action,
          grantedToUserId: '${body['granted_to_user_id'] ?? ''}',
          durationHours: _asNum(body['duration_hours']).toInt(),
        );
        _showSnack('Access updated.');
      }
      await _fetchStats();
    } catch (_) {
      _showSnack('Action failed. Please try again.');
    }
  }

  void _applyTrainingVaultAction(String action, Map<String, dynamic> body) {
    final leadId = '${body['lead_id'] ?? ''}';
    switch (action) {
      case 'assign_to_sm':
        _trainingRuntime.assignLeadToSourcingManager(
          leadId,
          managerId: '${body['sourcing_manager_id'] ?? ''}',
        );
        return;
      case 'assign_to_caller':
        _trainingRuntime.assignLeadToCaller(leadId, '${body['caller_id']}');
        return;
      case 'update_lead_quality':
        _trainingRuntime.updateBrokerLeadQuality(
            leadId, '${body['lead_quality']}');
        return;
      case 'set_followup':
        _trainingRuntime.setBrokerLeadFollowup(
          leadId,
          DateTime.tryParse('${body['next_followup_at'] ?? ''}') ??
              DateTime.now().add(const Duration(days: 1)),
        );
        return;
      case 'raise_issue':
        _trainingRuntime.raiseBrokerIssue(
            leadId, '${body['issue_type'] ?? 'review'}');
        return;
      // GAP-8 FIX: training mode coverage for new booking/brokerage actions
      case 'update_booking_stage':
        _trainingRuntime.updateBrokerLeadBookingStage(
            leadId, '${body['booking_stage'] ?? 'not_started'}');
        return;
      case 'update_brokerage_status':
        _trainingRuntime.updateBrokerLeadBrokerageStatus(
            leadId, '${body['brokerage_status'] ?? 'tracking'}');
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
    final now = DateTime.now();

    // 1. Hot lead untouched 24h -> reminder
    final hotUntouched = _leadRows.where((lead) {
      final quality = _safeStatus(lead['lead_quality']);
      final updated = DateTime.tryParse('${lead['updated_at'] ?? ''}');
      return quality == 'hot' &&
          updated != null &&
          now.difference(updated).inHours >= 24;
    }).length;
    if (hotUntouched > 0) {
      rows.add({
        'title': 'Hot Lead Alert',
        'body':
            '$hotUntouched hot lead(s) have had no movement for 24 hours. Trigger a call or follow-up now.',
        'color': PremiumUI.hot,
      });
    }

    // 2. Call_later -> caller follow-up
    final callLater = _leadRows.where((lead) {
      return _safeStatus(lead['call_status']) == 'call_later';
    }).length;
    if (callLater > 0) {
      rows.add({
        'title': 'Call Later Queue',
        'body':
            '$callLater lead(s) marked "Call Later". Send to caller for follow-up.',
        'color': PremiumUI.accent,
      });
    }

    // 3. Interested without visit 24h -> SM reminder
    final interestedNoVisit = _leadRows.where((lead) {
      final status = _safeStatus(lead['call_status']);
      final visit = _safeStatus(lead['visit_status']);
      final updated = DateTime.tryParse('${lead['updated_at'] ?? ''}');
      return status == 'interested' &&
          visit == 'not scheduled' &&
          updated != null &&
          now.difference(updated).inHours >= 24;
    }).length;
    if (interestedNoVisit > 0) {
      rows.add({
        'title': 'Visit Pending',
        'body':
            '$interestedNoVisit interested lead(s) still need a site visit. Assign a sourcing manager immediately.',
        'color': PremiumUI.warning,
      });
    }

    // 4. Expired data loan -> renew suggestion
    if (_asNum(_stats['expired_call_permissions']) > 0) {
      rows.add({
        'title': 'Renew Access',
        'body':
            '${_stats['expired_call_permissions']} lead(s) have expired access. Renew call permission now.',
        'color': PremiumUI.danger,
      });
    }

    // 5. Verified visit pending review -> broker reminder
    final pendingReviewVisits = _visitRows.where((visit) {
      final status = _safeStatus(visit['status']);
      return (status == 'broker_review_pending' ||
              status == 'photo_verified' ||
              status == 'visit_done') &&
          _safeStatus(visit['broker_review_status']) == 'pending';
    }).length;
    if (pendingReviewVisits > 0) {
      rows.add({
        'title': 'Visit Review Needed',
        'body':
            '$pendingReviewVisits verified visit(s) pending your review. Payout trigger depends on this!',
        'color': PremiumUI.secondary,
      });
    }

    // 6. Booking discussion stale -> follow-up
    final staleBooking = _leadRows.where((lead) {
      final stage = _safeStatus(lead['booking_stage']);
      final updated = DateTime.tryParse('${lead['updated_at'] ?? ''}');
      return (stage == 'booking_discussion' || stage == 'token_discussion') &&
          updated != null &&
          now.difference(updated).inHours >= 48;
    }).length;
    if (staleBooking > 0) {
      rows.add({
        'title': 'Booking Stale',
        'body':
            '$staleBooking booking discussion(s) silent for 48h. Check with SM/Client.',
        'color': PremiumUI.warning,
      });
    }

    if (rows.isEmpty && _asNum(_stats['followups_due']) > 0) {
      rows.add({
        'title': 'Follow-up due today',
        'body':
            '${_stats['followups_due']} lead(s) need a structured touch today.',
        'color': PremiumUI.warning,
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

  bool _isLeadFollowupDue(Map<String, dynamic> lead) {
    final callStatus = _safeStatus(lead['call_status']);
    if (callStatus == 'call_later') return true;
    final dueAt = DateTime.tryParse('${lead['next_followup_at'] ?? ''}');
    if (dueAt == null) return false;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return !dueAt.toLocal().isAfter(endOfToday);
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
    // BUG-H1 FIX: never hardcode a person's name — show generic label
    if ('${lead['assigned_sourcing_manager_id'] ?? ''}'.isNotEmpty &&
        '${lead['assigned_sourcing_manager_id']}' != 'null') {
      return 'SM Assigned';
    }
    return 'Unassigned';
  }

  String _bestProjectName() {
    if (_liveProjects.isEmpty) return 'Wadhwa Wise City';
    return '${_liveProjects.first['title'] ?? 'Project'}';
  }

  List<String> _brokerProfileMissingFields() {
    final requiredFields = <String, dynamic>{
      'full name': _profile['broker_name'],
      'company name': _profile['company_name'],
      'RERA number': _profile['rera_number'],
      'working area': _profile['area'],
      'city': _profile['city'],
      'speciality': _profile['speciality'],
    };
    return requiredFields.entries
        .where((entry) => _isBlankProfileValue(entry.value))
        .map((entry) => entry.key)
        .toList();
  }

  bool _isBlankProfileValue(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == '-' || text.toLowerCase() == 'null';
  }

  String _goalGapLabel() {
    final targetLeads = _asNum(_activeGoal?['target_leads']);
    final targetVisits = _asNum(_activeGoal?['target_visits']);
    final currentLeads = _asNum(_stats['total_leads']);
    final currentVisits = _asNum(_stats['verified_visits']);
    if (targetLeads <= 0 && targetVisits <= 0) {
      return 'Goal: add leads + visits';
    }
    final leadGap = (targetLeads - currentLeads).clamp(0, targetLeads);
    final visitGap = (targetVisits - currentVisits).clamp(0, targetVisits);
    return 'Need ${leadGap.round()} leads / ${visitGap.round()} visits';
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

  double _trustScorePercent(num score) {
    if (score <= 5) return (score / 5).toDouble().clamp(0.0, 1.0);
    return (score / 100).toDouble().clamp(0.0, 1.0);
  }

  String _trustScoreLabel(num score) {
    if (score <= 5 && score.toDouble() != score.toDouble().roundToDouble()) {
      return score.toStringAsFixed(1);
    }
    return '${score.round()}';
  }

  String _rankFor(dynamic trustScore) {
    final score = _asNum(trustScore);
    if (score >= 80) return 'Gold';
    if (score >= 60) return 'Silver';
    if (score >= 40) return 'Bronze';
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
