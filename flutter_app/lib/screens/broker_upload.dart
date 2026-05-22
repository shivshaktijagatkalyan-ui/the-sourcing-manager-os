import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../utils/training_runtime.dart';

class BrokerUploadScreen extends StatefulWidget {
  const BrokerUploadScreen({super.key});

  @override
  State<BrokerUploadScreen> createState() => _BrokerUploadScreenState();
}

class _BrokerUploadScreenState extends State<BrokerUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _aliasController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController(text: 'Mumbai');
  final _propertyController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePhone = true;

  @override
  void dispose() {
    _phoneController.clear();
    _phoneController.dispose();
    _aliasController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _propertyController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    super.dispose();
  }

  Future<void> _submitLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    String? oneTimePhone = _phoneController.text.trim();
    _phoneController.clear();

    try {
      Map<String, dynamic> result;

      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final response = await Supabase.instance.client.functions.invoke(
          'broker-upload-lead',
          body: {
            'phone': oneTimePhone,
            'alias': _aliasController.text.trim(),
            'area': _areaController.text.trim(),
            'city': _cityController.text.trim(),
            'property_name': _propertyController.text.trim(),
            'budget_min': _parseAmount(_budgetMinController.text),
            'budget_max': _parseAmount(_budgetMaxController.text),
          },
        );

        result = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{'ok': false, 'reason': 'server_error'};
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final leadId = TrainingRuntime.instance.addLeadFromBroker(
          brokerId: TrainingRuntime.brokerId,
          alias: _aliasController.text.trim(),
          area: _areaController.text.trim(),
          city: _cityController.text.trim(),
          propertyName: _propertyController.text.trim(),
          budgetMin: _parseAmount(_budgetMinController.text),
          budgetMax: _parseAmount(_budgetMaxController.text),
        );
        result = <String, dynamic>{
          'ok': true,
          'lead_id': leadId,
          'alias': _aliasController.text.trim(),
        };
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result['ok'] == true) {
        _showSuccessDialog('${result['lead_id']}', '${result['alias']}');
      } else {
        _showFailure('${result['reason'] ?? 'server_error'}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showFailure('server_error');
    } finally {
      oneTimePhone = null;
    }
  }

  num? _parseAmount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return num.tryParse(trimmed);
  }

  void _showFailure(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: $reason')),
    );
  }

  void _showSuccessDialog(String leadId, String alias) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lead Secured'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'The sensitive value was encrypted and discarded from the form.'),
            const SizedBox(height: 16),
            Text('Alias: $alias'),
            Text('Lead ID: $leadId'),
          ],
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
      appBar: AppBar(title: const Text('Broker Lead Upload')),
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
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'One-time sensitive entry. After submit, only alias and metadata remain visible.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _textField(
                controller: _aliasController,
                label: 'Lead Alias',
                icon: Icons.badge_outlined,
                validator: (value) => _required(value, 'Alias required'),
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _phoneController,
                label: 'Phone Number',
                helper: 'Submitted once to the secure Edge Function.',
                icon: Icons.lock_outline,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                obscureText: _obscurePhone,
                suffix: IconButton(
                  icon: Icon(
                      _obscurePhone ? Icons.visibility_off : Icons.visibility,
                      size: 18),
                  onPressed: () =>
                      setState(() => _obscurePhone = !_obscurePhone),
                ),
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _areaController,
                label: 'Area',
                icon: Icons.map_outlined,
                validator: (value) => _required(value, 'Area required'),
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _cityController,
                label: 'City',
                icon: Icons.location_city,
                validator: (value) => _required(value, 'City required'),
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _propertyController,
                label: 'Property Info',
                icon: Icons.home_work_outlined,
                validator: (value) =>
                    _required(value, 'Property info required'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _budgetMinController,
                      label: 'Budget Min',
                      icon: Icons.currency_rupee,
                      keyboardType: TextInputType.number,
                      validator: _optionalAmount,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _budgetMaxController,
                      label: 'Budget Max',
                      icon: Icons.currency_rupee,
                      keyboardType: TextInputType.number,
                      validator: _validateBudgetMax,
                    ),
                  ),
                ],
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
                    : const Text('Encrypt and Secure Lead'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helper,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
      validator: validator,
    );
  }

  String? _required(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Required for one-time encrypted upload';
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(trimmed)) {
      return 'Enter a valid value';
    }
    return null;
  }

  String? _optionalAmount(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return num.tryParse(trimmed) == null ? 'Number required' : null;
  }

  String? _validateBudgetMax(String? value) {
    final amountError = _optionalAmount(value);
    if (amountError != null) return amountError;

    final min = _parseAmount(_budgetMinController.text);
    final max = _parseAmount(value ?? '');
    if (min != null && max != null && max < min) {
      return 'Budget max must be greater than min';
    }
    return null;
  }
}
