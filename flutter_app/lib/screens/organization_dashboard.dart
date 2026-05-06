import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  State<OrganizationDashboard> createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  bool _isLoading = true;
  Map<String, dynamic>? _orgData;

  @override
  void initState() {
    super.initState();
    _fetchOrg();
  }

  Future<void> _fetchOrg() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final pu = await Supabase.instance.client
          .from('pilot_users')
          .select('org_id, organizations(*)')
          .eq('user_id', user.id)
          .single();
      
      setState(() {
        _orgData = pu['organizations'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_orgData == null) return const Scaffold(body: Center(child: Text('No organization context found.')));

    return Scaffold(
      appBar: AppBar(title: Text(_orgData!['name'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildStatCard('Organization Status', _orgData!['status'].toUpperCase(), 
                _orgData!['status'] == 'active' ? Colors.green : Colors.red),
            const SizedBox(height: 24),
            _buildActionTile(context, Icons.person_add, 'Invite Team Member', () {
              // Navigate to Invite
            }),
            _buildActionTile(context, Icons.people, 'Manage Roles & Access', () {
              // Navigate to Role Management
            }),
            _buildActionTile(context, Icons.pause_circle_outline, 'Pause Organization', () {
               // Emergency action
            }, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
