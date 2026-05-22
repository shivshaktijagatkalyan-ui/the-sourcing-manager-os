import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/premium_ui.dart';

class ExecutiveOnboardingScreen extends StatefulWidget {
  final VoidCallback? onAuthStateChanged;
  final String? initialRole;

  const ExecutiveOnboardingScreen({
    super.key,
    this.onAuthStateChanged,
    this.initialRole,
  });

  @override
  State<ExecutiveOnboardingScreen> createState() => _ExecutiveOnboardingScreenState();
}

class _ExecutiveOnboardingScreenState extends State<ExecutiveOnboardingScreen> {
  bool _isProcessing = false;
  String? _selectedRole;

  final _formKey = GlobalKey<FormState>();
  
  // Common fields
  final _fullNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  
  // Broker fields
  final _companyNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  
  // Sourcing Manager fields
  final _projectCtrl = TextEditingController();
  
  // Caller fields
  final _inviteCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRole = _roleLabel(widget.initialRole);
  }

  String? _roleLabel(String? role) {
    switch (role) {
      case 'broker_owner':
      case 'broker':
        return 'Broker';
      case 'sourcing_manager':
        return 'Sourcing Manager';
      case 'caller':
        return 'Caller';
      case 'admin':
      case 'developer_admin':
        return 'Admin Request';
      default:
        return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final roleMapping = {
        'Broker': 'broker_owner',
        'Sourcing Manager': 'sourcing_manager',
        'Caller': 'caller',
        'Admin Request': 'admin',
      };

      final payload = {
        'role': roleMapping[_selectedRole],
        'full_name': _fullNameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'company_name': _companyNameCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'primary_project': _projectCtrl.text.trim(),
        'invite_code': _inviteCodeCtrl.text.trim(),
      };

      final res = await Supabase.instance.client.functions.invoke(
        'complete-onboarding',
        body: payload,
      );

      if (res.status == 200) {
        if (_selectedRole == 'Admin Request') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access Request Submitted. Awaiting approval.')),
            );
          }
        } else {
          widget.onAuthStateChanged?.call();
        }
      } else {
        throw Exception('Server error: ${res.status}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator(color: PremiumUI.primary))
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Welcome to Sourcing Manager OS', style: PremiumUI.h1.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          Text('Select your role to configure your dashboard.', style: PremiumUI.subtitle),
                          const SizedBox(height: 32),
                          DropdownButtonFormField<String>(
                            dropdownColor: PremiumUI.cardColor,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Select Role',
                              labelStyle: const TextStyle(color: PremiumUI.muted),
                              filled: true,
                              fillColor: PremiumUI.cardColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            initialValue: _selectedRole,
                            items: ['Broker', 'Sourcing Manager', 'Caller', 'Admin Request']
                                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedRole = val),
                            validator: (val) => val == null ? 'Please select a role' : null,
                          ),
                          const SizedBox(height: 24),
                          
                          if (_selectedRole != null && _selectedRole != 'Admin Request') ...[
                            TextFormField(
                              controller: _fullNameCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Full Name'),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            if (_selectedRole == 'Broker') ...[
                              TextFormField(controller: _companyNameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Company Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                              const SizedBox(height: 16),
                              TextFormField(controller: _areaCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Operating Area'), validator: (v) => v!.isEmpty ? 'Required' : null),
                              const SizedBox(height: 16),
                              TextFormField(controller: _cityCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('City'), validator: (v) => v!.isEmpty ? 'Required' : null),
                            ] else if (_selectedRole == 'Sourcing Manager') ...[
                              TextFormField(controller: _projectCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Primary Project Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                              const SizedBox(height: 16),
                              TextFormField(controller: _cityCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('City'), validator: (v) => v!.isEmpty ? 'Required' : null),
                            ] else if (_selectedRole == 'Caller') ...[
                              TextFormField(controller: _inviteCodeCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Invite Code (Required)'), validator: (v) => v!.isEmpty ? 'Required' : null),
                            ],
                            const SizedBox(height: 32),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PremiumUI.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _submit,
                              child: const Text('COMPLETE SETUP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ),
                          ],
                          if (_selectedRole == 'Admin Request') ...[
                            const SizedBox(height: 16),
                            const Text('Request administrative access. Our team will review your application.', style: TextStyle(color: PremiumUI.muted)),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PremiumUI.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _submit,
                              child: const Text('SUBMIT REQUEST', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: PremiumUI.muted),
      filled: true,
      fillColor: PremiumUI.cardColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: PremiumUI.primary)),
    );
  }
}
