import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/training_runtime.dart';

class AddLeadFromBrokerScreen extends StatefulWidget {
  final String? sourceBrokerId;
  final String? sourceBrokerAlias;

  const AddLeadFromBrokerScreen({
    super.key,
    this.sourceBrokerId,
    this.sourceBrokerAlias,
  });

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
  final _uuid = const Uuid();

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
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
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
    } catch (_) {}
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
    _phoneController.clear(); // Constitution PII Wipe

    // Idempotency key for field resilience
    final idempotencyKey = _uuid.v4();

    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final client = Supabase.instance.client;
        final pilot = await client
            .from('pilot_users')
            .select('org_id')
            .eq('user_id', client.auth.currentUser!.id)
            .single();

        final response =
            await client.functions.invoke('lead-from-broker', body: {
          'action': 'create_lead_from_broker',
          'idempotency_key': idempotencyKey,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: PremiumUI.secondary, size: 64),
            const SizedBox(height: 24),
            Text('LEAD SECURED', style: PremiumUI.h1),
            const SizedBox(height: 12),
            Text(
              'Lead "$alias" has been successfully ingested.\n\nPII has been encrypted in the Secure Vault. It will never be displayed in plain text.',
              textAlign: TextAlign.center,
              style: PremiumUI.subtitle,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumUI.secondary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CONTINUE',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SECURITY ALERT: $message'),
        backgroundColor: PremiumUI.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('SECURE INTAKE',
            style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildBrokerSelector(),
              const SizedBox(height: 24),
              _buildPremiumField(
                  _aliasController, 'LEAD ALIAS', Icons.badge_outlined,
                  hint: 'e.g. L-542'),
              const SizedBox(height: 20),
              _buildPremiumField(
                _phoneController,
                'CONTACT VAULT (ENCRYPTED)',
                Icons.lock_outline,
                keyboardType: TextInputType.phone,
                obscure: true,
                helper:
                    'Value is wiped from UI memory immediately after intake.',
              ),
              const SizedBox(height: 20),
              _buildPremiumField(_areaController, 'PREFERRED AREA',
                  Icons.location_on_outlined),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _buildPremiumField(_budgetMinController,
                          'BUDGET MIN', Icons.remove_circle_outline,
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildPremiumField(_budgetMaxController,
                          'BUDGET MAX', Icons.add_circle_outline,
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 20),
              _buildPremiumField(_notesController, 'INTERNAL METADATA',
                  Icons.note_alt_outlined,
                  maxLines: 3),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumUI.secondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 8,
                    shadowColor: PremiumUI.secondary.withValues(alpha: 0.5),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('INGEST LEAD TO VAULT',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return PremiumUI.glassCard(
      color: PremiumUI.secondary,
      opacity: 0.1,
      child: Column(
        children: [
          const Icon(Icons.shield_outlined,
              color: PremiumUI.secondary, size: 32),
          const SizedBox(height: 16),
          const Text('DATALESS INTAKE ENGINE',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            'In compliance with Zero-Trust Architecture. No raw PII will be stored in public-facing tables.',
            textAlign: TextAlign.center,
            style: PremiumUI.subtitle.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SOURCE CHANNEL PARTNER',
            style: TextStyle(
                color: PremiumUI.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        InkWell(
          onTap: widget.sourceBrokerId == null ? _showBrokerPicker : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.handshake_outlined,
                    color: Colors.white38, size: 18),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _selectedBrokerAlias ?? 'SELECT BROKER...',
                    style: TextStyle(
                      color: _selectedBrokerAlias == null
                          ? Colors.white24
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: _selectedBrokerAlias == null
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.sourceBrokerId == null)
                  const Icon(Icons.expand_more,
                      color: Colors.white24, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showBrokerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('SELECT SOURCE BROKER',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _brokers.length,
                itemBuilder: (context, index) {
                  final b = _brokers[index];
                  return ListTile(
                    onTap: () {
                      setState(() {
                        _selectedBrokerId = b['id'].toString();
                        _selectedBrokerAlias = b['broker_alias'];
                      });
                      Navigator.pop(context);
                    },
                    leading: const Icon(Icons.person_outline,
                        color: PremiumUI.primary),
                    title: Text(b['broker_alias'],
                        style: const TextStyle(color: Colors.white)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    String? helper,
    bool obscure = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: PremiumUI.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: const TextStyle(color: Colors.white24, fontSize: 9),
            prefixIcon: Icon(icon, color: Colors.white38, size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PremiumUI.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PremiumUI.danger),
            ),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
      ],
    );
  }
}
