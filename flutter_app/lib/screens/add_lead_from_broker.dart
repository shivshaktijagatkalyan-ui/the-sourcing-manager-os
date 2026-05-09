import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';

class AddLeadFromBrokerScreen extends StatefulWidget {
  final String? sourceBrokerId;
  final String? sourceBrokerAlias;

  const AddLeadFromBrokerScreen(
      {super.key, this.sourceBrokerId, this.sourceBrokerAlias});

  @override
  State<AddLeadFromBrokerScreen> createState() =>
      _AddLeadFromBrokerScreenState();
}

class _AddLeadFromBrokerScreenState extends State<AddLeadFromBrokerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _aliasController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController(text: 'Mumbai');
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedBrokerId;
  String? _selectedBrokerAlias;
  List<Map<String, dynamic>> _brokers = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedBrokerId = widget.sourceBrokerId;
    _selectedBrokerAlias = widget.sourceBrokerAlias;
    if (_selectedBrokerId == null) {
      _fetchBrokers();
    }
  }

  Future<void> _fetchBrokers() async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final data = await Supabase.instance.client
            .from('brokers_public')
            .select('id, broker_alias')
            .order('broker_alias');
        setState(() => _brokers = List<Map<String, dynamic>>.from(data));
      } else {
        setState(() {
          _brokers = TrainingRuntime.instance
              .brokersForOrganization(TrainingRuntime.organizationId);
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrokerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a broker')));
      return;
    }

    setState(() => _isSubmitting = true);
    final phone = _phoneController.text.trim();
    _phoneController.clear(); // Constitution wipe

    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final pilot = await client
            .from('pilot_users')
            .select('org_id')
            .eq('user_id', client.auth.currentUser!.id)
            .single();

        final response =
            await client.functions.invoke('lead-from-broker', body: {
          'action': 'create_lead_from_broker',
          'organization_id': pilot['org_id'],
          'source_broker_id': _selectedBrokerId,
          'lead_alias': _aliasController.text.trim(),
          'area': _areaController.text.trim(),
          'city': _cityController.text.trim(),
          'budget_min': num.tryParse(_budgetMinController.text),
          'budget_max': num.tryParse(_budgetMaxController.text),
          'phone': phone.isNotEmpty ? phone : null,
          'notes_safe': _notesController.text.trim(),
        });

        final data = response.data as Map<String, dynamic>;
        if (data['ok'] == true) {
          if (!mounted) return;
          _showSuccess(data['lead_alias']);
          _resetForm();
        } else {
          _showError(data['reason'] ?? 'unknown_error');
        }
      } else {
        TrainingRuntime.instance.addLeadFromBroker(
          brokerId: _selectedBrokerId!,
          alias: _aliasController.text.trim(),
          area: _areaController.text.trim(),
          city: _cityController.text.trim(),
          budgetMin: num.tryParse(_budgetMinController.text),
          budgetMax: num.tryParse(_budgetMaxController.text),
          notesSafe: _notesController.text.trim(),
        );
        _showSuccess(_aliasController.text);
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
    _areaController.clear();
    _budgetMinController.clear();
    _budgetMaxController.clear();
    _notesController.clear();
    _phoneController.clear();
  }

  void _showSuccess(String alias) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lead Received'),
        content: Text(
            'Lead "$alias" has been secured and connected to the broker.\n\nCustomer number encrypted rahega, screen par nahi dikhega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Broker Lead Intake',
            style: PremiumUI.h1.copyWith(fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumUI.sectionShell(
                title: 'Secure Lead Intake',
                subtitle:
                    'Lead metadata yahan dikhega. Number sirf encrypted vault mein jayega.',
                accentColor: PremiumUI.secondary,
                child: const Text(
                  'Source broker se lead lo, alias aur budget save karo, aur customer number ko screen par kabhi mat lao.',
                  style: TextStyle(color: PremiumUI.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              _brokerSelector(),
              const SizedBox(height: 24),
              _textField(
                  _aliasController, 'Lead Alias (e.g. L-542)', Icons.badge,
                  validator: (v) => v!.isEmpty ? 'Alias required' : null),
              const SizedBox(height: 12),
              _textField(
                _phoneController,
                'Secure Contact Vault Input',
                Icons.lock_outline,
                keyboardType: TextInputType.phone,
                helper: 'Encrypted at intake. Never displayed again.',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              _textField(_areaController, 'Lead Area', Icons.map_outlined),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _textField(_budgetMinController, 'Budget Min',
                          Icons.currency_rupee,
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _textField(_budgetMaxController, 'Budget Max',
                          Icons.currency_rupee,
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              _textField(
                  _notesController, 'Internal Notes', Icons.note_alt_outlined,
                  maxLines: 3),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumUI.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Secure Lead Intake',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brokerSelector() {
    if (_selectedBrokerId != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PremiumUI.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PremiumUI.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_pin, color: PremiumUI.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'Source: ${_selectedBrokerAlias ?? 'Selected Broker'}',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            if (widget.sourceBrokerId == null)
              TextButton(
                  onPressed: () => setState(() => _selectedBrokerId = null),
                  child: const Text('Change')),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
          labelText: 'Source Broker',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.people_outline)),
      items: _brokers
          .map((b) => DropdownMenuItem(
              value: b['id'].toString(), child: Text(b['broker_alias'])))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedBrokerId = val;
          _selectedBrokerAlias =
              _brokers.firstWhere((b) => b['id'] == val)['broker_alias'];
        });
      },
    );
  }

  Widget _textField(
      TextEditingController controller, String label, IconData icon,
      {String? helper,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      int maxLines = 1,
      bool obscureText = false,
      Widget? suffix}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
