import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationOnboardingWizard extends StatefulWidget {
  const OrganizationOnboardingWizard({super.key});

  @override
  State<OrganizationOnboardingWizard> createState() => _OrganizationOnboardingWizardState();
}

class _OrganizationOnboardingWizardState extends State<OrganizationOnboardingWizard> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createOrg() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final response = await Supabase.instance.client.functions.invoke(
        'create-organization',
        body: {
          'organization_name': _nameController.text,
          'city': _cityController.text,
          'state': _stateController.text,
        },
      );

      if (response.status != 200) throw Exception(response.data['reason'] ?? 'Failed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization created in paused status.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization onboarding blocked.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Organization Onboarding')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Initialize a new enterprise organization in paused status. Activation requires compliance approval.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Organization Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createOrg,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Create Paused Organization'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
