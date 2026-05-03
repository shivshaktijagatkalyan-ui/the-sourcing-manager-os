import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import 'call_status.dart';

class LeadQueueScreen extends StatefulWidget {
  const LeadQueueScreen({super.key});

  @override
  State<LeadQueueScreen> createState() => _LeadQueueScreenState();
}

class _LeadQueueScreenState extends State<LeadQueueScreen> {
  late Future<List<LeadQueueItem>> _futureLeads;

  @override
  void initState() {
    super.initState();
    _futureLeads = _loadLeads();
  }

  Future<List<LeadQueueItem>> _loadLeads() async {
    if (!AppConfig.isSupabaseConfigured) return LeadQueueItem.demoItems;

    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('leads_public')
          .select('id, alias, area, city, property_name, budget_min, budget_max, lead_status')
          .order('created_at', ascending: false);

      final loans = await client
          .from('data_loans')
          .select('lead_id, status, starts_at, expires_at, revoked_at, purpose');

      final activeLoanLeadIds = <String>{};
      final now = DateTime.now().toUtc();

      for (final loan in loans as List<dynamic>) {
        final map = loan as Map<String, dynamic>;
        final startsAt = DateTime.tryParse('${map['starts_at']}')?.toUtc();
        final expiresAt = DateTime.tryParse('${map['expires_at']}')?.toUtc();
        if (map['purpose'] == 'call' &&
            map['status'] == 'active' &&
            map['revoked_at'] == null &&
            startsAt != null &&
            expiresAt != null &&
            !startsAt.isAfter(now) &&
            expiresAt.isAfter(now)) {
          activeLoanLeadIds.add('${map['lead_id']}');
        }
      }

      return (rows as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        final id = '${map['id']}';
        return LeadQueueItem(
          id: id,
          alias: '${map['alias']}',
          area: '${map['area'] ?? 'Unassigned'}',
          city: '${map['city'] ?? 'Mumbai'}',
          propertyName: '${map['property_name'] ?? 'Residential inquiry'}',
          budgetRange: _budgetRange(map['budget_min'], map['budget_max']),
          status: '${map['lead_status'] ?? 'new'}',
          hasActiveLoan: activeLoanLeadIds.contains(id),
        );
      }).toList();
    } catch (_) {
      return LeadQueueItem.demoItems;
    }
  }

  static String _budgetRange(dynamic min, dynamic max) {
    if (min == null && max == null) return 'Budget pending';
    if (min != null && max != null) return 'Rs $min - Rs $max';
    if (min != null) return 'From Rs $min';
    return 'Up to Rs $max';
  }

  void _refresh() {
    setState(() {
      _futureLeads = _loadLeads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caller Lead Queue', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<LeadQueueItem>>(
        future: _futureLeads,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final leads = snapshot.data!;
          if (leads.isEmpty) {
            return const Center(child: Text('No active lead metadata available.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leads.length,
            itemBuilder: (context, index) => LeadCard(lead: leads[index]),
          );
        },
      ),
    );
  }
}

class LeadQueueItem {
  final String id;
  final String alias;
  final String area;
  final String city;
  final String propertyName;
  final String budgetRange;
  final String status;
  final bool hasActiveLoan;

  const LeadQueueItem({
    required this.id,
    required this.alias,
    required this.area,
    required this.city,
    required this.propertyName,
    required this.budgetRange,
    required this.status,
    required this.hasActiveLoan,
  });

  static const demoItems = [
    LeadQueueItem(
      id: '11111111-1111-4111-8111-111111111111',
      alias: 'Lead-Alpha-101',
      area: 'Worli',
      city: 'Mumbai',
      propertyName: 'Premium 3BHK inquiry',
      budgetRange: 'Rs 45000000 - Rs 60000000',
      status: 'new',
      hasActiveLoan: true,
    ),
    LeadQueueItem(
      id: '22222222-2222-4222-8222-222222222222',
      alias: 'Lead-Beta-204',
      area: 'Bandra West',
      city: 'Mumbai',
      propertyName: 'Sea-facing resale inquiry',
      budgetRange: 'Budget pending',
      status: 'visit_scheduled',
      hasActiveLoan: true,
    ),
    LeadQueueItem(
      id: '33333333-3333-4333-8333-333333333333',
      alias: 'Lead-Gamma-318',
      area: 'Powai',
      city: 'Mumbai',
      propertyName: 'Investor shortlist',
      budgetRange: 'Rs 25000000 - Rs 30000000',
      status: 'new',
      hasActiveLoan: false,
    ),
  ];
}

class LeadCard extends StatelessWidget {
  final LeadQueueItem lead;
  const LeadCard({super.key, required this.lead});

  void _initiateSecureCall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CallStatusDialog(leadId: lead.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              lead.alias,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text('${lead.area}, ${lead.city}'),
            trailing: _StatusPill(status: lead.status),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lead.propertyName,
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(lead.budgetRange, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                _LoanBadge(active: lead.hasActiveLoan),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: lead.hasActiveLoan ? () => _initiateSecureCall(context) : null,
                  icon: const Icon(Icons.call),
                  label: const Text('Secure PSTN Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanBadge extends StatelessWidget {
  final bool active;
  const _LoanBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(active ? Icons.verified_user : Icons.lock_clock, size: 16, color: active ? Colors.green : Colors.orange),
        const SizedBox(width: 4),
        Text(
          active ? 'Active Loan' : 'Loan Required',
          style: TextStyle(color: active ? Colors.green : Colors.orange, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'revoked' ? Colors.red : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
