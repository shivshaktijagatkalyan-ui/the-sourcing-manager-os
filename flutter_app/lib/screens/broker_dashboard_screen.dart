import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';

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
  List<Map<String, dynamic>> _activityRows = [];

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
    setState(() {
      _isLoading = true;
    });

    try {
      if (AppConfig.isSupabaseConfigured) {
        await _fetchLiveStats();
      } else {
        await _fetchDemoStats();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLiveStats() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() { _isLoading = false; });
      return;
    }

    final brokerRows = await client.from('brokers_public').select('id, organization_id, broker_alias, broker_name, company_name, area, city, category, trust_score').eq('linked_user_id', user.id).eq('status', 'active');
    final brokers = List<Map<String, dynamic>>.from(brokerRows);
    if (brokers.isEmpty) {
      setState(() { _isLoading = false; });
      return;
    }

    final brokerIds = brokers.map((row) => row['id'] as String).toList();
    final primaryBroker = brokers.first;
    final leadRows = await client
        .from('leads_public')
        .select('id, alias, area, city, property_name, budget_min, budget_max, lead_status, assigned_caller_id, last_call_outcome, created_at')
        .inFilter('source_broker_id', brokerIds)
        .order('created_at', ascending: false)
        .limit(20);
    final leadIds = List<Map<String, dynamic>>.from(leadRows)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();

    final activations = await client.from('broker_activations').select('id, broker_id, activation_stage, assigned_sourcing_manager_id, projects(project_name, area, city, status)').inFilter('broker_id', brokerIds);
    final visits = await client.from('site_visits').select('id, lead_id, source_lead_id, source_broker_id, status, broker_review_status, created_at').inFilter('source_broker_id', brokerIds);
    final locks = await client.from('broker_locks').select('id, broker_id, lead_id, status, expires_at').inFilter('broker_id', brokerIds);
    final dataLoans = leadIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(await client.from('data_loans').select('id, lead_id, status, expires_at').inFilter('lead_id', leadIds));
    final activityRows = await client
        .from('broker_activity_logs')
        .select('id, activity_type, created_at')
        .inFilter('broker_id', brokerIds)
        .order('created_at', ascending: false)
        .limit(6);

    final visitByLead = <String, Map<String, dynamic>>{};
    for (final visit in List<Map<String, dynamic>>.from(visits)) {
      final key = (visit['source_lead_id'] ?? visit['lead_id'])?.toString();
      if (key != null && !visitByLead.containsKey(key)) {
        visitByLead[key] = visit;
      }
    }

    final lockByLead = <String, Map<String, dynamic>>{};
    for (final lock in List<Map<String, dynamic>>.from(locks)) {
      final key = lock['lead_id']?.toString();
      if (key != null && !lockByLead.containsKey(key)) {
        lockByLead[key] = lock;
      }
    }

    final loanByLead = <String, Map<String, dynamic>>{};
    for (final loan in dataLoans) {
      final key = loan['lead_id']?.toString();
      if (key != null && !loanByLead.containsKey(key)) {
        loanByLead[key] = loan;
      }
    }

    final connectedManagers = List<Map<String, dynamic>>.from(activations).map((activation) {
      final project = activation['projects'];
      return {
        'name': 'Assigned sourcing manager',
        'project': project is Map<String, dynamic>
            ? '${project['project_name'] ?? 'Project'}'
            : 'Project',
        'status': activation['activation_stage'] ?? 'active',
        'leads_shared': List<Map<String, dynamic>>.from(leadRows).where((lead) => lead['id'] != null).length,
        'visits_generated': List<Map<String, dynamic>>.from(visits).length,
      };
    }).toList();

    final liveProjects = List<Map<String, dynamic>>.from(activations).map((activation) {
      final project = activation['projects'];
      final projectName = project is Map<String, dynamic> ? project['project_name'] : 'Project';
      final area = project is Map<String, dynamic> ? project['area'] : '';
      final city = project is Map<String, dynamic> ? project['city'] : '';
      return {
        'title': projectName ?? 'Project',
        'location': [area, city].where((e) => '$e'.isNotEmpty).join(', '),
        'status': project is Map<String, dynamic> ? (project['status'] ?? 'active') : 'active',
        'stage': activation['activation_stage'] ?? 'active',
        'leads_given': List<Map<String, dynamic>>.from(leadRows).length,
        'verified_visits': List<Map<String, dynamic>>.from(visits).where((visit) => visit['status'] == 'completed').length,
      };
    }).toList();

    final safeLeadRows = List<Map<String, dynamic>>.from(leadRows).take(6).map((lead) {
      final leadId = lead['id']?.toString() ?? '';
      final loan = loanByLead[leadId];
      final visit = visitByLead[leadId];
      final lock = lockByLead[leadId];
      final budgetMin = (lead['budget_min'] is num) ? lead['budget_min'] as num : num.tryParse('${lead['budget_min'] ?? ''}') ?? 0;
      final budgetMax = (lead['budget_max'] is num) ? lead['budget_max'] as num : num.tryParse('${lead['budget_max'] ?? ''}') ?? 0;
      return {
        'alias': lead['alias'] ?? 'Lead',
        'area': lead['area'] ?? '-',
        'project': lead['property_name'] ?? 'Project',
        'budget': '₹${(budgetMin / 100000).toStringAsFixed(0)}L–₹${(budgetMax / 100000).toStringAsFixed(0)}L',
        'caller': lead['assigned_caller_id'] == null ? 'Unassigned' : 'Assigned',
        'loan': (loan?['status'] ?? 'inactive').toString(),
        'call_status': (lead['last_call_outcome'] ?? lead['lead_status'] ?? 'pending').toString(),
        'visit_status': (visit?['status'] ?? 'not_scheduled').toString(),
        'lock': (lock?['status'] ?? 'inactive').toString(),
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      _profile = {
        'broker_name': primaryBroker['broker_name'] ?? primaryBroker['broker_alias'] ?? 'Broker',
        'org_name': primaryBroker['company_name'] ?? 'Broker organization',
        'rank': _rankFor(primaryBroker['trust_score']),
      };
      _stats = {
        'connected_sm_count': connectedManagers.length,
        'live_projects_count': liveProjects.length,
        'total_leads': List<Map<String, dynamic>>.from(leadRows).length,
        'interested_leads': List<Map<String, dynamic>>.from(leadRows).where((l) => l['last_call_outcome'] == 'interested').length,
        'calls_attempted': List<Map<String, dynamic>>.from(leadRows).where((l) => l['last_call_outcome'] != null).length,
        'site_visits_scheduled': visits.where((v) => v['status'] == 'scheduled').length,
        'verified_visits': visits.where((v) => v['status'] == 'completed').length,
        'data_loans_active': dataLoans.where((loan) => loan['status'] == 'active').length,
        'active_locks': locks.where((lock) => lock['status'] == 'active').length,
        'trust_score': primaryBroker['trust_score'] ?? 0,
      };
      _connectedManagers = connectedManagers;
      _liveProjects = liveProjects;
      _leadRows = safeLeadRows;
      _activityRows = List<Map<String, dynamic>>.from(activityRows);
      _isLoading = false;
    });
  }

  Future<void> _fetchDemoStats() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _profile = _trainingRuntime.brokerDashboardProfile();
      _stats = _trainingRuntime.brokerDashboardStats();
      _connectedManagers = _trainingRuntime.brokerConnectedManagers();
      _liveProjects = _trainingRuntime.brokerLiveProjects();
      _leadRows = _trainingRuntime.brokerLeadRows();
      _activityRows = _trainingRuntime.brokerActivityRows();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: Text('BROKER PARTNER ERP', style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _buildStatusBadge('PARTNER_SECURE', PremiumUI.secondary),
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
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildKPIGrid(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('CONNECTED SOURCING MANAGERS'),
                    const SizedBox(height: 12),
                    ..._connectedManagers.map((m) => _buildManagerCard(m)),
                    const SizedBox(height: 32),
                    _buildSectionTitle('LIVE PROJECTS'),
                    const SizedBox(height: 12),
                    ..._liveProjects.map((p) => _buildProjectCard(p)),
                    const SizedBox(height: 32),
                    _buildSectionTitle('MY LEAD STATUS'),
                    const SizedBox(height: 12),
                    ..._leadRows.map((l) => _buildLeadCard(l)),
                    const SizedBox(height: 32),
                    PremiumUI.sectionShell(
                      title: 'Recent Activity',
                      subtitle: 'Safe performance and lock trail',
                      accentColor: PremiumUI.warning,
                      child: _buildActivityList(),
                    ),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: PremiumUI.primary.withValues(alpha: 0.1),
          child: Text(_profile['broker_name'][0], style: const TextStyle(color: PremiumUI.primary, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_profile['broker_name'], style: PremiumUI.h1.copyWith(fontSize: 20)),
              Text(_profile['org_name'], style: PremiumUI.subtitle),
            ],
          ),
        ),
        _buildStatusBadge(_profile['rank'], PremiumUI.warning),
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
        _miniKPI('SMs', _stats['connected_sm_count'].toString(), PremiumUI.primary),
        _miniKPI('Projects', _stats['live_projects_count'].toString(), PremiumUI.secondary),
        _miniKPI('Leads', _stats['total_leads'].toString(), PremiumUI.accent),
        _miniKPI('Calls', '${_stats['calls_attempted'] ?? 0}', PremiumUI.warning),
        _miniKPI('Interested', _stats['interested_leads'].toString(), PremiumUI.hot),
        _miniKPI('Visits', _stats['verified_visits'].toString(), PremiumUI.secondary),
        _miniKPI('Loans', '${_stats['data_loans_active'] ?? 0}', PremiumUI.accent),
        _miniKPI('Locks', '${_stats['active_locks'] ?? 0}', PremiumUI.primary),
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
          Text(label.toUpperCase(), style: PremiumUI.subtitle.copyWith(fontSize: 9, color: Colors.white70, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildManagerCard(Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: PremiumUI.cyberPanel(color: PremiumUI.primary),
      child: ListTile(
        title: Text(m['name'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(m['project'], style: PremiumUI.subtitle.copyWith(fontSize: 10)),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PremiumUI.statusBadge('${m['status'] ?? 'active'}', PremiumUI.statusColor('${m['status'] ?? 'active'}')),
            const SizedBox(height: 4),
            Text('${m['visits_generated']}V / ${m['leads_shared']}L', style: const TextStyle(color: PremiumUI.primary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: PremiumUI.cyberPanel(color: PremiumUI.secondary),
      child: ListTile(
        title: Text(p['title'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(p['location'], style: PremiumUI.subtitle.copyWith(fontSize: 10)),
        trailing: _buildStatusBadge('${p['stage']}', PremiumUI.statusColor('${p['stage']}')),
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> l) {
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
              _buildStatusBadge(l['loan'], PremiumUI.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _leadMeta(Icons.location_on, l['area']),
              const SizedBox(width: 16),
              _leadMeta(Icons.payments, l['budget']),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l['project'] ?? 'Project', style: PremiumUI.subtitle.copyWith(fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('Call: ${l['call_status']}', style: PremiumUI.subtitle.copyWith(fontSize: 10)),
                  Text('Visit: ${l['visit_status']}', style: PremiumUI.subtitle.copyWith(fontSize: 10)),
                ],
              ),
              _buildStatusBadge(
                l['lock'] == 'active' ? 'LOCKED' : 'NO LOCK',
                l['lock'] == 'active' ? PremiumUI.secondary : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    if (_activityRows.isEmpty) {
      return const Text('No recent safe activity.', style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _activityRows.map((activity) {
        final timestamp = DateTime.tryParse('${activity['created_at'] ?? ''}');
        final label = '${activity['activity_type'] ?? 'activity'}'.replaceAll('_', ' ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 10, color: PremiumUI.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white)),
              ),
              Text(
                timestamp == null
                    ? '-'
                    : '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: PremiumUI.muted, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
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

  String _rankFor(dynamic trustScore) {
    final score = trustScore is num ? trustScore : num.tryParse('$trustScore');
    if (score == null) return 'Unranked';
    if (score >= 4.5) return 'Gold';
    if (score >= 3.5) return 'Silver';
    if (score >= 2.5) return 'Bronze';
    return 'Review';
  }
}
