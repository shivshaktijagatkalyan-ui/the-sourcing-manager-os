import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDiagnosticsScreen extends StatefulWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  State<AdminDiagnosticsScreen> createState() => _AdminDiagnosticsScreenState();
}

class _AdminDiagnosticsScreenState extends State<AdminDiagnosticsScreen> {
  bool _isLoading = true;
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchDiagnostics();
  }

  Future<void> _fetchDiagnostics() async {
    try {
      final client = Supabase.instance.client;
      
      final orgs = await client.from('organizations').select('id');
      final users = await client.from('pilot_users').select('user_id');
      final loans = await client.from('data_loans').select('id');
      final calls = await client.from('call_attempts').select('id');
      final visits = await client.from('site_visits').select('id');
      final payouts = await client.from('payout_ledger').select('id');

      if (!mounted) return;
      setState(() {
        _stats = {
          'organizations': (orgs as List).length,
          'users': (users as List).length,
          'active_loans': (loans as List).length,
          'calls_total': (calls as List).length,
          'site_visits': (visits as List).length,
          'payouts_total': (payouts as List).length,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Diagnostics Snapshot')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Operational Metadata (Aggregated)', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                _buildStatTile('Active Organizations', _stats['organizations']!),
                _buildStatTile('Total Pilot Users', _stats['users']!),
                _buildStatTile('Active Data Loans', _stats['active_loans']!),
                _buildStatTile('Total Call Attempts', _stats['calls_total']!),
                _buildStatTile('Total Site Visits', _stats['site_visits']!),
                _buildStatTile('Payout Ledger Entries', _stats['payouts_total']!),
                const Divider(height: 48),
                const Text('System snapshot loaded', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
    );
  }

  Widget _buildStatTile(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
