import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';

class DeveloperRoiDashboard extends StatefulWidget {
  const DeveloperRoiDashboard({super.key});

  @override
  State<DeveloperRoiDashboard> createState() => _DeveloperRoiDashboardState();
}

class _DeveloperRoiDashboardState extends State<DeveloperRoiDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _riskAlerts = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        await _fetchLiveStats();
      } else {
        await _fetchDemoStats();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLiveStats() async {
    try {
      final client = Supabase.instance.client;

      // Total Brokers
      final totalBrokersResponse = await client
          .from('brokers_public')
          .select('id');
      
      // Active Brokers
      final activeBrokersResponse = await client
          .from('brokers_public')
          .select('id')
          .eq('category', 'active');

      // Sourcing Managers
      final sourcingResponse = await client.from('role_assignments')
          .select('id')
          .eq('role', 'sourcing_manager');

      // Callers
      final callersResponse = await client.from('role_assignments')
          .select('id')
          .eq('role', 'caller');

      // Leads Received
      final leadsResponse = await client.from('leads_public')
          .select('id');

      // Calls Done
      final callsResponse = await client.from('call_attempts')
          .select('id')
          .eq('call_status', 'completed');

      // Site Visits Scheduled
      final scheduledVisitsResponse = await client.from('site_visits')
          .select('id')
          .eq('status', 'scheduled');

      // Verified Visits
      final verifiedVisitsResponse = await client.from('site_visits')
          .select('id')
          .eq('status', 'completed');

      // Projects
      final projects = await client.from('projects')
          .select('id, project_name, area, city, status, rera_verified')
          .order('created_at', ascending: false)
          .limit(10);

      // Risk Alerts
      final riskAlerts = await client.from('abuse_events')
          .select('id, event_type, severity, status')
          .order('created_at', ascending: false)
          .limit(5);

      if (!mounted) return;
      setState(() {
        _stats = {
          'total_brokers': (totalBrokersResponse as List).length,
          'active_brokers': (activeBrokersResponse as List).length,
          'sourcing_managers': (sourcingResponse as List).length,
          'callers': (callersResponse as List).length,
          'leads_received': (leadsResponse as List).length,
          'calls_done': (callsResponse as List).length,
          'site_visits_scheduled': (scheduledVisitsResponse as List).length,
          'verified_visits': (verifiedVisitsResponse as List).length,
        };
        _projects = List<Map<String, dynamic>>.from(projects);
        _riskAlerts = List<Map<String, dynamic>>.from(riskAlerts);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDemoStats() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _stats = {
        'total_brokers': 28,
        'active_brokers': 16,
        'sourcing_managers': 4,
        'callers': 8,
        'leads_received': 156,
        'calls_done': 102,
        'site_visits_scheduled': 24,
        'verified_visits': 18,
      };
      _projects = [
        {
          'id': '1',
          'project_name': 'The Wadhwa Wise City',
          'area': 'Panvel',
          'city': 'Mumbai',
          'status': 'Active',
          'rera_verified': true,
        },
        {
          'id': '2',
          'project_name': 'Prestige Estates',
          'area': 'Whitefield',
          'city': 'Bangalore',
          'status': 'Active',
          'rera_verified': true,
        },
      ];
      _riskAlerts = [
        {
          'id': '1',
          'event_type': 'Duplicate Lead',
          'severity': 'medium',
          'status': 'open',
        },
        {
          'id': '2',
          'event_type': 'Contact Exposure',
          'severity': 'high',
          'status': 'investigating',
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: Text('ADMIN ERP & ANALYTICS', style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: PremiumUI.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: PremiumUI.danger.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text('ADMIN_SECURE', style: PremiumUI.subtitle.copyWith(color: PremiumUI.danger, fontSize: 8)),
              ),
            ),
          ),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildKPIRow1(),
                      const SizedBox(height: 16),
                      _buildKPIRow2(),
                      const SizedBox(height: 16),
                      _buildKPIRow3(),
                      const SizedBox(height: 24),
                      _buildKPIRow4(),
                      const SizedBox(height: 24),
                      _buildSection('Active Projects', _buildProjectsTable()),
                      const SizedBox(height: 24),
                      _buildSection('Risk Alerts', _buildRiskAlertsTable()),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildKPIRow1() {
    return Row(
      children: [
        Expanded(child: PremiumUI.kpiCard('Total Brokers', _stats['total_brokers'].toString(), Icons.people, PremiumUI.primary)),
        const SizedBox(width: 12),
        Expanded(child: PremiumUI.kpiCard('Active Brokers', _stats['active_brokers'].toString(), Icons.verified_user, PremiumUI.secondary)),
      ],
    );
  }

  Widget _buildKPIRow2() {
    return Row(
      children: [
        Expanded(child: PremiumUI.kpiCard('Sourcing Mgr', _stats['sourcing_managers'].toString(), Icons.person_outline, const Color(0xFF8B5CF6))),
        const SizedBox(width: 12),
        Expanded(child: PremiumUI.kpiCard('Callers', _stats['callers'].toString(), Icons.call_outlined, PremiumUI.accent)),
      ],
    );
  }

  Widget _buildKPIRow3() {
    return Row(
      children: [
        Expanded(child: PremiumUI.kpiCard('Leads Received', _stats['leads_received'].toString(), Icons.trending_up, PremiumUI.warning)),
        const SizedBox(width: 12),
        Expanded(child: PremiumUI.kpiCard('Calls Done', _stats['calls_done'].toString(), Icons.check_circle, PremiumUI.secondary)),
      ],
    );
  }

  Widget _buildKPIRow4() {
    return Row(
      children: [
        Expanded(child: PremiumUI.kpiCard('Visits Scheduled', _stats['site_visits_scheduled'].toString(), Icons.calendar_today, const Color(0xFFEC4899))),
        const SizedBox(width: 12),
        Expanded(child: PremiumUI.kpiCard('Project ROI', '12.4x', Icons.insights, PremiumUI.warning)),
      ],
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: PremiumUI.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), style: PremiumUI.subtitle.copyWith(color: Colors.white, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildProjectsTable() {
    if (_projects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: PremiumUI.glassBox(),
        child: const Center(child: Text('No projects found', style: TextStyle(color: Colors.white54))),
      );
    }
    return Column(
      children: List.generate(_projects.length, (index) {
        final project = _projects[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: PremiumUI.cyberPanel(color: PremiumUI.primary),
          child: ListTile(
            title: Text(project['project_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${project['area'] ?? ''}, ${project['city'] ?? ''}', style: PremiumUI.subtitle.copyWith(fontSize: 10)),
            trailing: Wrap(
              spacing: 8,
              children: [
                if (project['rera_verified'] ?? false)
                  const Icon(Icons.verified, size: 16, color: PremiumUI.secondary),
                const Icon(Icons.chevron_right, size: 16, color: Colors.white24),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRiskAlertsTable() {
    if (_riskAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Text('No risk alerts', style: TextStyle(color: Colors.white54))),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: List.generate(_riskAlerts.length, (index) {
          final alert = _riskAlerts[index];
          final severity = alert['severity'] ?? 'medium';
          final severityColor = severity == 'high'
              ? const Color(0xFFEF4444)
              : severity == 'medium'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF3B82F6);
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert['event_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${alert['status'] ?? ''}'.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 10, color: severityColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
