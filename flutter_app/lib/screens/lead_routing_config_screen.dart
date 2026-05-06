import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeadRoutingConfigScreen extends StatefulWidget {
  const LeadRoutingConfigScreen({super.key});

  @override
  State<LeadRoutingConfigScreen> createState() => _LeadRoutingConfigScreenState();
}

class _LeadRoutingConfigScreenState extends State<LeadRoutingConfigScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _configs = [];

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
  }

  Future<void> _fetchConfigs() async {
    try {
      final response = await Supabase.instance.client
          .from('lead_routing_configs')
          .select()
          .order('priority', ascending: false);

      if (!mounted) return;
      setState(() {
        _configs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routing config blocked.')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Routing Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement Add Config Dialog
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? const Center(child: Text('No routing configurations found.'))
              : ListView.builder(
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    final config = _configs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.route),
                        title: Text('Tier: ${config['tier_name'].toString().toUpperCase()}'),
                        subtitle: Text('Min Trust: ${config['min_trust_score']} | Loan: ${config['max_loan_duration_hours']}h'),
                        trailing: Switch(
                          value: config['auto_revoke_enabled'] ?? false,
                          onChanged: (val) {
                            // TODO: Implement toggle
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
