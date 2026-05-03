import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'call_status.dart';

class LeadQueueScreen extends StatelessWidget {
  const LeadQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Queue', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10, // Mock count
        itemBuilder: (context, index) {
          return LeadCard(
            lead: {
              'id': 'uuid-$index',
              'alias': 'Lead #${1000 + index}',
              'area': 'Whitefield',
              'city': 'Bangalore',
              'property_name': 'Prestige Waterford',
              'budget_range': '₹1.5Cr - ₹2.2Cr',
              'status': index % 3 == 0 ? 'Urgent' : 'New',
              'has_active_loan': index % 2 == 0,
            },
          );
        },
      ),
    );
  }
}

class LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  const LeadCard({super.key, required this.lead});

  Future<void> _initiateSecureCall(BuildContext context) async {
    // Show connecting UI
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CallStatusDialog(leadId: lead['id']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLoan = lead['has_active_loan'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              lead['alias'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text('${lead['area']}, ${lead['city']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: lead['status'] == 'Urgent' 
                    ? Colors.red.withOpacity(0.1) 
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lead['status'],
                style: TextStyle(
                  color: lead['status'] == 'Urgent' ? Colors.red : Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Text(lead['property_name'], style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                Text(lead['budget_range'], style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                if (hasLoan)
                  const Row(
                    children: [
                      Icon(Icons.verified_user, size: 16, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Active Loan', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.lock_clock, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Loan Required', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: hasLoan ? () => _initiateSecureCall(context) : null,
                  icon: const Icon(Icons.call),
                  label: const Text('Secure Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.2),
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
