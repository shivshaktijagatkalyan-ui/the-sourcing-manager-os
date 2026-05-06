import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';

class AddBrokerScreen extends StatefulWidget {
  const AddBrokerScreen({super.key});

  @override
  State<AddBrokerScreen> createState() => _AddBrokerScreenState();
}

class _AddBrokerScreenState extends State<AddBrokerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic Info
  final _aliasController = TextEditingController();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController(text: 'Mumbai');
  final _specialityController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Sensitive Info (Wiped after submit)
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Metadata
  String _category = 'new';
  String _interestLevel = 'unknown';
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _aliasController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _specialityController.dispose();
    _notesController.dispose();
    _phoneController.clear();
    _phoneController.dispose();
    _emailController.clear();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    
    // Wipe sensitive fields immediately from UI controllers
    _phoneController.clear();
    _emailController.clear();

    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        // 1. Get Org ID from Pilot Record
        final pilotResponse = await client
            .from('pilot_users')
            .select('org_id')
            .eq('user_id', client.auth.currentUser!.id)
            .maybeSingle();
            
        final orgId = pilotResponse?['org_id'];
        if (orgId == null) throw Exception('No active organization found');

        // 2. Call Edge Function
        final response = await client.functions.invoke(
          'manage-external-broker',
          body: {
            'action': 'create_broker',
            'organization_id': orgId,
            'broker_alias': _aliasController.text.trim(),
            'broker_name': _nameController.text.trim(),
            'company_name': _companyController.text.trim(),
            'area': _areaController.text.trim(),
            'city': _cityController.text.trim(),
            'speciality': _specialityController.text.trim(),
            'category': _category,
            'interest_level': _interestLevel,
            'notes_safe': _notesController.text.trim(),
            'phone': phone.isNotEmpty ? phone : null,
            'email': email.isNotEmpty ? email : null,
          },
        );

        final data = response.data as Map<String, dynamic>;
        if (data['ok'] == true) {
          if (!mounted) return;
          _showSuccess(data['broker_id'].toString(), _aliasController.text);
          _resetForm();
        } else {
          _showError(data['reason'] ?? 'unknown_error');
        }
      } else {
        // Demo Mode
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        _showSuccess('demo-uuid', _aliasController.text);
        _resetForm();
      }
    } catch (e) {
      _showError('request_failed');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _aliasController.clear();
    _nameController.clear();
    _companyController.clear();
    _areaController.clear();
    _specialityController.clear();
    _notesController.clear();
    setState(() {
      _category = 'new';
      _interestLevel = 'unknown';
    });
  }

  void _showSuccess(String id, String alias) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broker Added Securely'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The contact details were encrypted and discarded from this device.'),
            const SizedBox(height: 16),
            Text('Alias: $alias'),
            Text('ID: $id'),
            const SizedBox(height: 8),
            const Text('Hinglish: Broker ka number save ho gaya hai, par screen par kabhi nahi dikhega.', 
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Great')),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Broker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoCard(),
              const SizedBox(height: 24),
              _sectionHeader('Identification'),
              _textField(_aliasController, 'Broker Alias (Required)', Icons.badge, validator: (v) => v!.isEmpty ? 'Alias required' : null),
              const SizedBox(height: 12),
              _textField(_nameController, 'Full Name (Safe)', Icons.person_outline),
              const SizedBox(height: 12),
              _textField(_companyController, 'Company / Agency', Icons.business),
              const SizedBox(height: 24),
              _sectionHeader('Secure Contact'),
              _textField(_phoneController, 'Phone Number (Protected)', Icons.lock_outline, helper: 'Will be encrypted immediately.', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _textField(_emailController, 'Email Address (Protected)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 24),
              _sectionHeader('Location & Expertise'),
              _textField(_areaController, 'Primary Area (e.g. Panvel)', Icons.map_outlined),
              const SizedBox(height: 12),
              _textField(_cityController, 'City', Icons.location_city),
              const SizedBox(height: 12),
              _textField(_specialityController, 'Speciality (e.g. Luxury, Resale)', Icons.star_outline),
              const SizedBox(height: 24),
              _sectionHeader('Classification'),
              _dropdown('Category', _category, ['new', 'warm', 'hot', 'active', 'inactive', 'dead'], (val) => setState(() => _category = val!)),
              const SizedBox(height: 12),
              _dropdown('Interest Level', _interestLevel, ['unknown', 'low', 'medium', 'high'], (val) => setState(() => _interestLevel = val!)),
              const SizedBox(height: 24),
              _sectionHeader('Notes'),
              _textField(_notesController, 'Internal Notes', Icons.note_alt_outlined, maxLines: 3),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF6366F1),
                ),
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Add Broker Securely', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('Broker contact is protected. Calls happen securely.', style: TextStyle(fontSize: 12, color: Colors.white54))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF10B981)),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Dataless Constitution: Phone numbers are encrypted and discarded from memory after submission. They are NEVER displayed in the UI.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
    );
  }

  Widget _textField(TextEditingController controller, String label, IconData icon, {String? helper, TextInputType? keyboardType, String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, void Function(String?)? onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
