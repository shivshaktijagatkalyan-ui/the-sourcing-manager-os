import 'package:flutter/material.dart';

class BrokerUploadScreen extends StatefulWidget {
  const BrokerUploadScreen({super.key});

  @override
  State<BrokerUploadScreen> createState() => _BrokerUploadScreenState();
}

class _BrokerUploadScreenState extends State<BrokerUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _aliasController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Call Supabase Edge Function: broker-upload-lead
    // The phone number is sent ONCE and then discarded from memory.
    
    await Future.delayed(const Duration(seconds: 2)); // Simulate

    if (mounted) {
      setState(() => _isSubmitting = false);
      _phoneController.clear(); // WIPE phone from UI controller immediately
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lead Secured'),
        content: const Text(
          'Lead has been uploaded and encrypted. Phone number is now invisible to all users, including yourself. Only PSTN bridging is allowed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Lead Upload')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                color: Color(0xFF1E293B),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'SYSTEM ENFORCEMENT: Phone numbers entered here are encrypted instantly and never displayed again.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _aliasController,
                decoration: const InputDecoration(
                  labelText: 'Lead Alias (e.g. John D - Bangalore)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Alias required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone Number',
                  helperText: 'Will be encrypted. Never visible again.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android),
                ),
                validator: (v) => v!.isEmpty ? 'Phone required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Property Interest',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitLead,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ENCRYPT & SECURE LEAD'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
