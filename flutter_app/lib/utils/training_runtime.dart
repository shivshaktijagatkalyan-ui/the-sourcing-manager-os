import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'training_storage.dart';

class TrainingRuntime extends ChangeNotifier {
  static const String _storageKey = 'sm_os_training_runtime_v1';

  TrainingRuntime._() {
    _seed();
    _restoreFromStorage();
  }

  static final TrainingRuntime instance = TrainingRuntime._();

  static const String organizationId = 'org_demo_1';
  static const String projectId = 'project_wadhwa_wise_city';
  static const String sourcingManagerId = 'user_vinod';
  static const String brokerUserId = 'user_jitu';
  static const String callerRahulId = 'user_rahul';
  static const String brokerId = 'jitu_1';

  late Map<String, dynamic> _project;
  late Map<String, dynamic> _broker;
  late Map<String, dynamic> _activation;
  late List<Map<String, dynamic>> _followups;
  late List<Map<String, dynamic>> _leads;
  late List<Map<String, dynamic>> _callers;
  late List<Map<String, dynamic>> _dataLoans;
  late List<Map<String, dynamic>> _callAttempts;
  late List<Map<String, dynamic>> _brokerActivityLogs;
  late List<Map<String, dynamic>> _siteVisits;
  late List<Map<String, dynamic>> _auditEvents;
  late List<Map<String, dynamic>> _brokerLocks;

  void _seed() {
    final now = DateTime.now();
    _project = {
      'id': projectId,
      'project_name': 'The Wadhwa Wise City',
      'area': 'Panvel',
      'city': 'Mumbai',
      'status': 'active',
    };

    _broker = {
      'id': brokerId,
      'organization_id': organizationId,
      'linked_user_id': brokerUserId,
      'assigned_sourcing_manager_id': sourcingManagerId,
      'broker_alias': 'Jitu Gupta',
      'broker_name': 'Jitu Gupta',
      'company_name': 'JSN Enterprise',
      'area': 'Mira Road',
      'city': 'Mumbai',
      'category': 'hot',
      'status': 'active',
      'trust_score': 4.2,
    };

    _activation = {
      'id': 'activation_jitu_wadhwa',
      'organization_id': organizationId,
      'broker_id': brokerId,
      'project_id': projectId,
      'assigned_sourcing_manager_id': sourcingManagerId,
      'activation_stage': 'active_broker',
      'last_touch_at': now.subtract(const Duration(hours: 4)).toIso8601String(),
    };

    _callers = [
      {
        'user_id': callerRahulId,
        'organization_id': organizationId,
        'full_name': 'Rahul',
        'role_id': 'caller',
        'status': 'active',
        'can_call_leads': true,
      },
    ];

    _followups = [
      {
        'id': 'followup_1',
        'organization_id': organizationId,
        'broker_id': brokerId,
        'assigned_to': sourcingManagerId,
        'status': 'pending',
        'title': 'Broker activation follow-up',
        'due_at': now.add(const Duration(hours: 2)).toIso8601String(),
        'brokers_public': {
          'broker_alias': 'Jitu Gupta',
          'company_name': 'JSN Enterprise',
        },
      },
    ];

    _leads = [
      {
        'id': 'lead_998',
        'organization_id': organizationId,
        'source_broker_id': brokerId,
        'broker_id': brokerUserId,
        'assigned_sourcing_manager_id': sourcingManagerId,
        'assigned_manager_id': sourcingManagerId,
        'assigned_caller_id': null,
        'project_id': projectId,
        'property_name': 'The Wadhwa Wise City',
        'alias': 'L-998',
        'lead_alias': 'L-998',
        'area': 'Kharghar',
        'city': 'Mumbai',
        'budget_min': 6500000,
        'budget_max': 8500000,
        'lead_status': 'new',
        'last_call_outcome': null,
        'created_at': now.subtract(const Duration(hours: 5)).toIso8601String(),
        'updated_at': now.subtract(const Duration(hours: 5)).toIso8601String(),
      },
      {
        'id': 'lead_1042',
        'organization_id': organizationId,
        'source_broker_id': brokerId,
        'broker_id': brokerUserId,
        'assigned_sourcing_manager_id': sourcingManagerId,
        'assigned_manager_id': sourcingManagerId,
        'assigned_caller_id': callerRahulId,
        'project_id': projectId,
        'property_name': 'The Wadhwa Wise City',
        'alias': 'L-1042',
        'lead_alias': 'L-1042',
        'area': 'Mira Road',
        'city': 'Mumbai',
        'budget_min': 8000000,
        'budget_max': 10000000,
        'lead_status': 'new',
        'last_call_outcome': null,
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'updated_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];

    _dataLoans = [
      {
        'id': 'loan_1042',
        'lead_id': 'lead_1042',
        'broker_id': brokerUserId,
        'granted_to_user_id': callerRahulId,
        'purpose': 'call',
        'status': 'active',
        'starts_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'expires_at': now.add(const Duration(hours: 23)).toIso8601String(),
      },
    ];

    _callAttempts = [];
    _siteVisits = [];
    _auditEvents = [
      {
        'id': 'audit_seed',
        'actor_id': sourcingManagerId,
        'lead_id': 'lead_1042',
        'event_type': 'lead_received_from_broker',
        'event_context': {'broker_id': brokerId, 'source': 'external_broker'},
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
    _brokerActivityLogs = [
      {
        'id': 'bal_seed',
        'organization_id': organizationId,
        'broker_id': brokerId,
        'project_id': projectId,
        'actor_id': sourcingManagerId,
        'activity_type': 'lead_received',
        'notes_safe': 'Broker-sourced lead received securely.',
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
    _brokerLocks = [];
  }

  // --- HARDWARE FLOW MOCKS ---

  Future<Map<String, dynamic>> initiateCall(String targetId, {String type = 'lead'}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (type == 'lead') {
      final lead = _leadById(targetId);
      if (lead == null) return {'ok': false, 'reason': 'lead_not_found'};
      
      // Check for active loan if it's a caller
      final loan = _loanForLead(targetId);
      if (loan == null && lead['assigned_caller_id'] != null) {
        return {'ok': false, 'status': 'loan_expired', 'reason': 'no_active_loan'};
      }
    } else {
      // Broker call
      if (targetId != brokerId) return {'ok': false, 'reason': 'broker_not_found'};
    }

    _auditEvents.add({
      'id': 'audit_call_${DateTime.now().microsecondsSinceEpoch}',
      'actor_id': sourcingManagerId,
      'lead_id': type == 'lead' ? targetId : null,
      'event_type': 'secure_call_initiated',
      'event_context': {'provider': 'exotel', 'mode': 'pstn_bridge', 'target_type': type},
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return {'ok': true, 'status': 'queued'};
  }

  Future<bool> startSiteVisit(String visitId) async {
    final visit = _siteVisitById(visitId);
    if (visit == null) return false;
    visit['status'] = 'started';
    visit['updated_at'] = DateTime.now().toIso8601String();
    notifyListeners();
    return true;
  }

  Future<bool> verifySiteGps(String visitId, double lat, double lng) async {
    final visit = _siteVisitById(visitId);
    if (visit == null) return false;
    
    
    // Simulating geofence check (Wadhwa Wise City is approx 18.98, 73.11)
    const projectLat = 18.9894;
    const projectLng = 73.1175;
    
    // Simple Euclidean distance for mock (not real Haversine but fine for smoke test)
    final dist = ((lat - projectLat).abs() + (lng - projectLng).abs()) * 111000;
    
    if (dist < 500) { // 500m geofence
      visit['gps_status'] = 'verified';
      visit['status'] = 'gps_verified';
      visit['distance_from_project_meters'] = dist;
    } else {
      visit['gps_status'] = 'rejected';
      visit['status'] = 'gps_rejected';
      visit['distance_from_project_meters'] = dist;
      return false;
    }
    
    visit['updated_at'] = DateTime.now().toIso8601String();
    
    _auditEvents.add({
      'id': 'audit_gps_${DateTime.now().microsecondsSinceEpoch}',
      'lead_id': visit['source_lead_id'],
      'event_type': 'site_gps_verified',
      'event_context': {'lat': lat, 'lng': lng, 'distance': 42.5},
      'created_at': DateTime.now().toIso8601String(),
    });
    
    notifyListeners();
    return true;
  }

  Future<bool> uploadSitePhoto(String visitId) async {
    final visit = _siteVisitById(visitId);
    if (visit == null) return false;
    
    const hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    visit['photo_sha256'] = hash;
    visit['photo_storage_path'] = 'site-visits/$visitId/$hash.jpg';
    visit['status'] = 'broker_review_pending';
    visit['updated_at'] = DateTime.now().toIso8601String();
    
    _auditEvents.add({
      'id': 'audit_photo_${DateTime.now().microsecondsSinceEpoch}',
      'lead_id': visit['source_lead_id'],
      'event_type': 'site_photo_uploaded',
      'event_context': {'hash': 'e3b0...'},
      'created_at': DateTime.now().toIso8601String(),
    });
    
    notifyListeners();
    return true;
  }

  Future<bool> brokerReviewSiteVisit(String visitId, String action) async {
    final visit = _siteVisitById(visitId);
    if (visit == null) return false;
    
    if (action == 'approve') {
      visit['status'] = 'completed';
      visit['broker_lock_status'] = 'active';
      
      final expiresAt = DateTime.now().add(const Duration(days: 45));
      visit['lock_expires_at'] = expiresAt.toIso8601String();
      
      _brokerLocks.add({
        'id': 'lock_${DateTime.now().microsecondsSinceEpoch}',
        'lead_id': visit['source_lead_id'],
        'broker_id': visit['source_broker_id'],
        'source_site_visit_id': visitId,
        'starts_at': DateTime.now().toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'status': 'active',
      });
      
      _auditEvents.add({
        'id': 'audit_lock_${DateTime.now().microsecondsSinceEpoch}',
        'lead_id': visit['source_lead_id'],
        'event_type': 'broker_lock_activated',
        'event_context': {'duration_days': 45},
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      visit['status'] = 'rejected';
    }
    
    visit['updated_at'] = DateTime.now().toIso8601String();
    notifyListeners();
    return true;
  }

  Map<String, dynamic>? _siteVisitById(String id) {
    try {
      return _siteVisits.firstWhere((v) => v['id'] == id);
    } catch (_) {
      return null;
    }
  }

  void _restoreFromStorage() {
    final raw = readTrainingStorage(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _project = Map<String, dynamic>.from(data['project'] as Map);
      _broker = Map<String, dynamic>.from(data['broker'] as Map);
      _activation = Map<String, dynamic>.from(data['activation'] as Map);
      _followups = (data['followups'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _leads = (data['leads'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _callers = (data['callers'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _dataLoans = (data['data_loans'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _callAttempts = (data['call_attempts'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _brokerActivityLogs = (data['broker_activity_logs'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _siteVisits = (data['site_visits'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _auditEvents = (data['audit_events'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      notifyListeners();
    } catch (_) {
      // Ignore invalid local training cache and keep seeded data.
    }
  }

  void _persist() {
    final payload = {
      'project': _project,
      'broker': _broker,
      'activation': _activation,
      'followups': _followups,
      'leads': _leads,
      'callers': _callers,
      'data_loans': _dataLoans,
      'call_attempts': _callAttempts,
      'broker_activity_logs': _brokerActivityLogs,
      'site_visits': _siteVisits,
      'audit_events': _auditEvents,
    };
    writeTrainingStorage(_storageKey, jsonEncode(payload));
  }

  Map<String, dynamic> brokerById(String brokerId) => Map<String, dynamic>.from(_broker);

  Map<String, dynamic> activationByBrokerId(String brokerId) => Map<String, dynamic>.from(_activation);

  List<Map<String, dynamic>> activityLogsForBroker(String brokerId) {
    final rows = _brokerActivityLogs.where((row) => row['broker_id'] == brokerId).toList()
      ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  List<Map<String, dynamic>> recentLeadsForBroker(String brokerId) {
    final rows = _leads.where((row) => row['source_broker_id'] == brokerId).toList()
      ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  int leadCountForBroker(String brokerId) =>
      _leads.where((row) => row['source_broker_id'] == brokerId).length;

  int visitCountForBroker(String brokerId) =>
      _siteVisits.where((row) => row['source_broker_id'] == brokerId).length;

  List<Map<String, dynamic>> activeCallersForOrganization(String organizationId) {
    return _callers
        .where((row) =>
            row['organization_id'] == organizationId &&
            row['status'] == 'active' &&
            row['role_id'] == 'caller' &&
            row['can_call_leads'] == true)
        .map((row) => {
              'user_id': row['user_id'],
              'full_name': row['full_name'],
            })
        .toList();
  }

  List<Map<String, dynamic>> callerAssignedLeads(String callerId) {
    return _leads
        .where((row) => row['assigned_caller_id'] == callerId)
        .map((row) => {
              ...Map<String, dynamic>.from(row),
              'brokers_public': {
                'broker_alias': _broker['broker_alias'],
                'company_name': _broker['company_name'],
              },
            })
        .toList()
      ..sort((a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'));
  }

  List<Map<String, dynamic>> siteVisitsForManager(String managerId) {
    final visits = _siteVisits
        .where((row) => row['assigned_sourcing_manager_id'] == managerId || row['sourcing_manager_id'] == managerId)
        .map((row) => {
              ...Map<String, dynamic>.from(row),
              'projects': {
                'project_name': _project['project_name'],
                'area': _project['area'],
                'city': _project['city'],
              },
              'leads_public': {
                'alias': _leadById('${row['source_lead_id'] ?? row['lead_id']}')?['alias'] ?? 'Lead',
              },
            })
        .toList()
      ..sort((a, b) => '${a['scheduled_at']}'.compareTo('${b['scheduled_at']}'));
    return visits;
  }

  Map<String, dynamic> sourcingManagerStats() {
    final managerLeads = _leads.where((row) => row['assigned_sourcing_manager_id'] == sourcingManagerId).toList();
    final interestedLeads = managerLeads.where((row) => row['last_call_outcome'] == 'interested').length;
    final assignedLeads = managerLeads.where((row) => row['assigned_caller_id'] != null).length;
    final visits = _siteVisits.where((row) => row['assigned_sourcing_manager_id'] == sourcingManagerId).toList();
    final verifiedVisits = visits.where((row) => row['status'] == 'completed').length;

    return {
      'followups_today': _followups.where((row) => row['status'] == 'pending').length,
      'hot_brokers': 1,
      'active_brokers': 1,
      'new_brokers': 0,
      'leads_this_month': managerLeads.length,
      'leads_assigned_to_caller': assignedLeads,
      'interested_leads': interestedLeads,
      'site_visits_scheduled': visits.where((row) => row['status'] == 'scheduled').length,
      'verified_visits_this_month': verifiedVisits,
      'monthly_performance': '94%',
      'top_broker': _broker['company_name'],
    };
  }

  List<Map<String, dynamic>> interestedLeadsForManager(String managerId) {
    return _leads
        .where((row) =>
            row['assigned_sourcing_manager_id'] == managerId &&
            row['last_call_outcome'] == 'interested')
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<Map<String, dynamic>> followupsForManager(String managerId) {
    return _followups
        .where((row) => row['assigned_to'] == managerId)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<Map<String, dynamic>> topBrokersForManager(String managerId) {
    return [
      {
        'id': _broker['id'],
        'broker_name': _broker['broker_name'],
        'company_name': _broker['company_name'],
        'area': _broker['area'],
        'city': _broker['city'],
      }
    ];
  }

  Map<String, dynamic> brokerDashboardProfile() {
    return {
      'broker_name': _broker['broker_name'],
      'org_name': _broker['company_name'],
      'rank': _rankFor(_broker['trust_score']),
    };
  }

  Map<String, dynamic> brokerDashboardStats() {
    final brokerLeads = _leads.where((row) => row['source_broker_id'] == brokerId).toList();
    final brokerVisits = _siteVisits.where((row) => row['source_broker_id'] == brokerId).toList();
    return {
      'connected_sm_count': 1,
      'live_projects_count': 1,
      'total_leads': brokerLeads.length,
      'interested_leads': brokerLeads.where((row) => row['last_call_outcome'] == 'interested').length,
      'calls_attempted': _callAttempts.where((row) => _leadById('${row['lead_id']}')?['source_broker_id'] == brokerId).length,
      'site_visits_scheduled': brokerVisits.where((row) => row['status'] == 'scheduled').length,
      'verified_visits': brokerVisits.where((row) => row['status'] == 'completed').length,
      'data_loans_active': _dataLoans.where((row) => row['status'] == 'active').length,
      'active_locks': brokerVisits.where((row) => row['broker_lock_status'] == 'active').length,
      'trust_score': _broker['trust_score'],
    };
  }

  List<Map<String, dynamic>> brokerConnectedManagers() {
    return [
      {
        'name': 'Vinod Gupta',
        'project': 'The Wadhwa Wise City, Panvel',
        'status': 'Active',
        'leads_shared': leadCountForBroker(brokerId),
        'visits_generated': visitCountForBroker(brokerId),
      }
    ];
  }

  List<Map<String, dynamic>> brokerLiveProjects() {
    return [
      {
        'title': _project['project_name'],
        'location': '${_project['area']}, ${_project['city']}',
        'status': 'Active',
        'stage': 'Active Broker',
        'leads_given': leadCountForBroker(brokerId),
        'verified_visits': _siteVisits.where((row) => row['status'] == 'completed').length,
      }
    ];
  }

  List<Map<String, dynamic>> brokerLeadRows() {
    return _leads
        .where((row) => row['source_broker_id'] == brokerId)
        .map((lead) {
          final loan = _loanForLead('${lead['id']}');
          final visit = _visitForLead('${lead['id']}');
          return {
            'alias': lead['alias'],
            'area': lead['area'],
            'budget':
                '₹${((lead['budget_min'] as num) / 100000).toStringAsFixed(0)}L–₹${((lead['budget_max'] as num) / 100000).toStringAsFixed(0)}L',
            'caller': _callerName('${lead['assigned_caller_id']}') ?? 'Unassigned',
            'project': lead['property_name'] ?? _project['project_name'],
            'loan': _humanLoanStatus(loan?['status']),
            'call_status': (lead['last_call_outcome'] ?? lead['lead_status'] ?? 'pending').toString().replaceAll('_', ' '),
            'visit_status': _humanVisitStatus(visit?['status']),
            'lock': (visit?['broker_lock_status'] ?? 'inactive').toString(),
          };
        })
        .toList();
  }

  List<Map<String, dynamic>> brokerActivityRows() => activityLogsForBroker(brokerId);

  Map<String, dynamic> callerDashboardStats(String callerId) {
    final leads = callerAssignedLeads(callerId);
    final pending = leads.where((row) => row['last_call_outcome'] == null && row['lead_status'] != 'visit_scheduled').length;
    return {
      'pending_calls': pending,
      'completed_today': _callAttempts.where((row) => row['caller_id'] == callerId).length,
      'interested_leads': leads.where((row) => row['last_call_outcome'] == 'interested').length,
      'call_later': leads.where((row) => row['last_call_outcome'] == 'call_later').length,
      'visit_scheduled': leads.where((row) => row['lead_status'] == 'visit_scheduled').length,
      'assigned_today': leads.length,
    };
  }

  String addLeadFromBroker({
    required String brokerId,
    required String alias,
    required String area,
    required String city,
    required num? budgetMin,
    required num? budgetMax,
    String notesSafe = '',
  }) {
    final id = 'lead_${DateTime.now().microsecondsSinceEpoch}';
    _leads.add({
      'id': id,
      'organization_id': organizationId,
      'source_broker_id': brokerId,
      'broker_id': brokerUserId,
      'assigned_sourcing_manager_id': sourcingManagerId,
      'assigned_manager_id': sourcingManagerId,
      'assigned_caller_id': null,
      'project_id': projectId,
      'property_name': _project['project_name'],
      'alias': alias,
      'lead_alias': alias,
      'area': area,
      'city': city,
      'budget_min': budgetMin ?? 0,
      'budget_max': budgetMax ?? 0,
      'lead_status': 'new',
      'last_call_outcome': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    _brokerActivityLogs.add({
      'id': 'activity_$id',
      'organization_id': organizationId,
      'broker_id': brokerId,
      'project_id': projectId,
      'actor_id': sourcingManagerId,
      'activity_type': 'lead_received',
      'notes_safe': notesSafe.isEmpty ? 'Broker-sourced lead received securely.' : notesSafe,
      'created_at': DateTime.now().toIso8601String(),
    });
    _auditEvents.add({
      'id': 'audit_$id',
      'actor_id': sourcingManagerId,
      'lead_id': id,
      'event_type': 'lead_received_from_broker',
      'event_context': {'broker_id': brokerId, 'source': 'external_broker'},
      'created_at': DateTime.now().toIso8601String(),
    });
    _persist();
    notifyListeners();
    return id;
  }

  bool assignLeadToCaller(String leadId, String callerId) {
    final lead = _leadById(leadId);
    final caller = _callerById(callerId);
    if (lead == null || caller == null || caller['status'] != 'active' || caller['can_call_leads'] != true) {
      return false;
    }

    lead['assigned_caller_id'] = callerId;
    lead['lead_status'] = 'loan_active';
    lead['updated_at'] = DateTime.now().toIso8601String();

    _dataLoans.removeWhere((loan) => loan['lead_id'] == leadId && loan['purpose'] == 'call' && loan['status'] == 'active');
    _dataLoans.add({
      'id': 'loan_${DateTime.now().microsecondsSinceEpoch}',
      'lead_id': leadId,
      'broker_id': brokerUserId,
      'granted_to_user_id': callerId,
      'purpose': 'call',
      'status': 'active',
      'starts_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });

    _brokerActivityLogs.add({
      'id': 'activity_assign_$leadId',
      'organization_id': organizationId,
      'broker_id': lead['source_broker_id'],
      'project_id': lead['project_id'],
      'actor_id': sourcingManagerId,
      'activity_type': 'note_added',
      'notes_safe': 'Lead assigned to caller for secure calling.',
      'created_at': DateTime.now().toIso8601String(),
    });

    _auditEvents.add({
      'id': 'audit_assign_$leadId',
      'actor_id': sourcingManagerId,
      'lead_id': leadId,
      'event_type': 'lead_assigned_to_caller',
      'event_context': {
        'organization_id': organizationId,
        'caller_id': callerId,
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    _persist();
    notifyListeners();
    return true;
  }

  bool updateCallerOutcome(String leadId, String outcome, {String notes = ''}) {
    final lead = _leadById(leadId);
    if (lead == null) return false;

    lead['last_call_outcome'] = outcome;
    lead['last_call_at'] = DateTime.now().toIso8601String();
    lead['lead_status'] = _trainingLeadStatus(outcome);
    lead['updated_at'] = DateTime.now().toIso8601String();

    _callAttempts.add({
      'id': 'call_${DateTime.now().microsecondsSinceEpoch}',
      'lead_id': leadId,
      'caller_id': callerRahulId,
      'call_status': 'completed',
      'outcome': outcome,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    // Revoke data loan if terminal outcome
    final terminalOutcomes = ['not_interested', 'wrong_lead', 'budget_mismatch', 'location_mismatch', 'interested', 'visit_scheduled'];
    if (terminalOutcomes.contains(outcome)) {
      _dataLoans.where((l) => l['lead_id'] == leadId && l['purpose'] == 'call').forEach((l) {
        l['status'] = 'revoked';
        l['revoked_at'] = DateTime.now().toIso8601String();
      });
    }

    _brokerActivityLogs.add({
      'id': 'activity_outcome_$leadId',
      'organization_id': organizationId,
      'broker_id': lead['source_broker_id'],
      'project_id': lead['project_id'],
      'actor_id': callerRahulId,
      'activity_type': outcome == 'interested' ? 'lead_received' : 'call_connected',
      'outcome': outcome,
      'notes_safe': notes.isEmpty ? 'Caller outcome updated securely.' : notes,
      'created_at': DateTime.now().toIso8601String(),
    });

    _auditEvents.add({
      'id': 'audit_outcome_$leadId',
      'actor_id': callerRahulId,
      'lead_id': leadId,
      'event_type': 'lead_call_outcome_updated',
      'event_context': {'outcome': outcome},
      'created_at': DateTime.now().toIso8601String(),
    });

    _persist();
    notifyListeners();
    return true;
  }

  bool scheduleSiteVisitFromLead(String leadId, {DateTime? scheduledAt}) {
    final lead = _leadById(leadId);
    if (lead == null) return false;

    final visitAt = scheduledAt ?? DateTime.now().add(const Duration(days: 1));
    _siteVisits.removeWhere((visit) => visit['source_lead_id'] == leadId && visit['status'] == 'scheduled');
    _siteVisits.add({
      'id': 'visit_${DateTime.now().microsecondsSinceEpoch}',
      'organization_id': organizationId,
      'lead_id': leadId,
      'source_lead_id': leadId,
      'source_broker_id': lead['source_broker_id'],
      'assigned_sourcing_manager_id': sourcingManagerId,
      'sourcing_manager_id': sourcingManagerId,
      'project_id': lead['project_id'] ?? projectId,
      'property_name': lead['property_name'] ?? _project['project_name'],
      'area': _project['area'],
      'city': _project['city'],
      'scheduled_at': visitAt.toIso8601String(),
      'visit_date': visitAt.toIso8601String(),
      'status': 'scheduled',
      'broker_lock_status': 'inactive',
      'distance_from_project_meters': null,
      'gps_status': 'pending',
      'photo_sha256': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    lead['lead_status'] = 'visit_scheduled';
    lead['last_call_outcome'] = 'visit_scheduled';
    lead['updated_at'] = DateTime.now().toIso8601String();
    
    if (_activation['broker_id'] == lead['source_broker_id']) {
      _activation['activation_stage'] = 'meeting_scheduled';
    }

    _brokerActivityLogs.add({
      'id': 'activity_visit_$leadId',
      'organization_id': organizationId,
      'broker_id': lead['source_broker_id'],
      'project_id': lead['project_id'] ?? projectId,
      'actor_id': sourcingManagerId,
      'activity_type': 'meeting_scheduled',
      'notes_safe': 'Site visit scheduled for broker-sourced lead.',
      'created_at': DateTime.now().toIso8601String(),
    });

    _auditEvents.add({
      'id': 'audit_visit_$leadId',
      'actor_id': sourcingManagerId,
      'lead_id': leadId,
      'event_type': 'site_visit_scheduled_from_broker_lead',
      'event_context': {
        'broker_id': lead['source_broker_id'],
        'project_id': lead['project_id'] ?? projectId,
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    _persist();
    notifyListeners();
    return true;
  }

  bool auditHasNoPii() {
    final serialized = _auditEvents.map((event) => event.toString()).join(' ');
    return !serialized.contains('+91') &&
        !serialized.contains('9876543210') &&
        !RegExp(r'\b\d{10}\b').hasMatch(serialized);
  }

  Map<String, dynamic>? _leadById(String leadId) {
    try {
      return _leads.firstWhere((row) => row['id'] == leadId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _callerById(String callerId) {
    try {
      return _callers.firstWhere((row) => row['user_id'] == callerId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _loanForLead(String leadId) {
    try {
      return _dataLoans.firstWhere((row) => row['lead_id'] == leadId && row['status'] == 'active');
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _visitForLead(String leadId) {
    try {
      return _siteVisits.firstWhere((row) => row['source_lead_id'] == leadId || row['lead_id'] == leadId);
    } catch (_) {
      return null;
    }
  }

  String? _callerName(String callerId) {
    final caller = _callerById(callerId);
    return caller == null ? null : caller['full_name']?.toString();
  }

  String _trainingLeadStatus(String outcome) {
    switch (outcome) {
      case 'interested':
        return 'interested';
      case 'visit_scheduled':
        return 'visit_scheduled';
      case 'not_interested':
        return 'revoked';
      case 'wrong_lead':
      case 'budget_mismatch':
      case 'location_mismatch':
        return 'blocked';
      default:
        return 'loan_active';
    }
  }

  String _humanLoanStatus(dynamic status) {
    switch ('${status ?? 'inactive'}') {
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      case 'revoked':
        return 'Revoked';
      default:
        return 'Inactive';
    }
  }

  String _humanVisitStatus(dynamic status) {
    switch ('${status ?? 'not_scheduled'}') {
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Verified';
      default:
        return 'Not Scheduled';
    }
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
