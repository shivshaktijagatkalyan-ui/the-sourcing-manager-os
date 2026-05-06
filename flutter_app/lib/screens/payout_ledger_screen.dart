import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PayoutLedgerScreen extends StatefulWidget {
  const PayoutLedgerScreen({super.key});

  @override
  State<PayoutLedgerScreen> createState() => _PayoutLedgerScreenState();
}

class _PayoutLedgerScreenState extends State<PayoutLedgerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _payouts = [];

  @override
  void initState() {
    super.initState();
    _fetchPayouts();
  }

  Future<void> _fetchPayouts() async {
    try {
      final response = await Supabase.instance.client
          .from('payout_ledger')
          .select()
          .order('eligibility_date', ascending: false);

      if (!mounted) return;
      setState(() {
        _payouts = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout ledger blocked.')),
      );
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'eligible': return Colors.blue;
      case 'processing': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payout Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayouts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payouts.isEmpty
              ? const Center(child: Text('No payout records found.'))
              : ListView.builder(
                  itemCount: _payouts.length,
                  itemBuilder: (context, index) {
                    final payout = _payouts[index];
                    final amount = payout['amount'] as double;
                    final status = payout['status'] as String;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('${payout['currency']} ${amount.toStringAsFixed(2)}'),
                        subtitle: Text('Eligible on: ${payout['eligibility_date']}'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getStatusColor(status)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
