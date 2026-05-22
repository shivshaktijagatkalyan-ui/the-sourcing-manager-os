import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/premium_ui.dart';
import '../app_config.dart';
import '../utils/training_runtime.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final String role;

  const ProfileCompletionScreen({super.key, required this.role});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for Broker
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _reraController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _specialityController = TextEditingController();

  // Controllers for Sourcing Manager
  final _monthlyTargetController = TextEditingController();
  final _brokerNetworkSizeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _reraController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _specialityController.dispose();
    _monthlyTargetController.dispose();
    _brokerNetworkSizeController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentProfile() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          if (widget.role == 'broker') {
            final res = await client
                .from('brokers_public')
                .select()
                .eq('linked_user_id', user.id)
                .eq('status', 'active')
                .maybeSingle();
            if (res != null && mounted) {
              setState(() {
                _nameController.text =
                    res['broker_name'] ?? res['broker_alias'] ?? '';
                _companyController.text = res['company_name'] ?? '';
                _reraController.text = res['rera_number'] ?? '';
                _areaController.text = res['area'] ?? '';
                _cityController.text = res['city'] ?? '';
                _specialityController.text = res['speciality'] ?? '';
              });
            }
          } else {
            // Fetch for sourcing manager if applicable
            final res = await client
                .from('pilot_users')
                .select()
                .eq('user_id', user.id)
                .maybeSingle();
            if (res != null && mounted) {
              setState(() {
                _monthlyTargetController.text =
                    '100'; // Default mock target for pilot
                _brokerNetworkSizeController.text =
                    '25'; // Default mock network
              });
            }
          }
        }
      } else {
        // Training Mode
        if (widget.role == 'broker') {
          final profile = TrainingRuntime.instance.brokerDashboardProfile();
          setState(() {
            _nameController.text = profile['broker_name'] ?? '';
            _companyController.text = profile['company_name'] ?? '';
            _reraController.text = profile['rera_number'] ?? '';
            _areaController.text = profile['area'] ?? '';
            _cityController.text = profile['city'] ?? '';
            _specialityController.text = profile['speciality'] ?? '';
          });
        } else {
          final stats = TrainingRuntime.instance.sourcingManagerStats();
          setState(() {
            _monthlyTargetController.text = '100';
            _brokerNetworkSizeController.text =
                '${stats['active_brokers'] ?? 5}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: PremiumUI.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          if (widget.role == 'broker') {
            final response =
                await client.functions.invoke('broker-vault-workflow', body: {
              'action': 'update_broker_profile',
              'broker_name': _nameController.text.trim(),
              'company_name': _companyController.text.trim(),
              'rera_number': _reraController.text.trim(),
              'area': _areaController.text.trim(),
              'city': _cityController.text.trim(),
              'speciality': _specialityController.text.trim(),
            });
            final data = response.data as Map<String, dynamic>?;
            if (data?['ok'] != true) {
              throw Exception(data?['reason'] ?? 'profile_update_failed');
            }
          } else {
            final pilot = await client
                .from('pilot_users')
                .select('org_id')
                .eq('user_id', user.id)
                .maybeSingle();
            final orgId = pilot?['org_id'];
            if (orgId == null) throw Exception('organization_not_found');

            final month = DateTime(DateTime.now().year, DateTime.now().month);
            await client.from('sourcing_goals').upsert({
              'user_id': user.id,
              'org_id': orgId,
              'target_leads': int.parse(_monthlyTargetController.text.trim()),
              'target_broker_activations':
                  int.parse(_brokerNetworkSizeController.text.trim()),
              'month_year': month.toIso8601String(),
              'status': 'active',
              'metadata': {'profile_completed': true},
            }, onConflict: 'user_id,month_year');
          }
        }
      } else {
        // Training Mode
        if (widget.role == 'broker') {
          TrainingRuntime.instance.updateBrokerProfile(
            brokerName: _nameController.text.trim(),
            companyName: _companyController.text.trim(),
            area: _areaController.text.trim(),
            city: _cityController.text.trim(),
            speciality: _specialityController.text.trim(),
            reraNumber: _reraController.text.trim(),
          );
        } else {
          // Training SM update
          // SM training mode: profile stored via sourcing_goals upsert above.
          // No local training state to notify.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Profile saved successfully. Business Vault Fully Unlocked!',
                style: TextStyle(color: Colors.white)),
            backgroundColor: PremiumUI.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: PremiumUI.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style:
              PremiumUI.subtitle.copyWith(fontSize: 10, color: PremiumUI.muted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: PremiumUI.cardColor,
            prefixIcon: Icon(icon, color: PremiumUI.primary, size: 18),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: PremiumUI.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PremiumUI.danger, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.role == 'broker'
        ? 'Complete Broker Vault Profile'
        : 'Complete Sourcing Profile';
    final subText = widget.role == 'broker'
        ? 'Complete required broker data for review, verified badge eligibility, secure lead allocation, and payout protection.'
        : 'Update targets, broker network metrics, and manager tracking profiles.';

    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: Text(
          widget.role == 'broker'
              ? 'BUSINESS VAULT PROFILE'
              : 'MANAGER PROFILE',
          style: PremiumUI.subtitle
              .copyWith(fontSize: 12, letterSpacing: 1.5, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PremiumUI.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PremiumUI.glassCard(
                          opacity: 0.08,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: PremiumUI.primary
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.shield,
                                        color: PremiumUI.primary, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(titleText,
                                            style: PremiumUI.h1
                                                .copyWith(fontSize: 18)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'SECURE VAULT ENCRYPTION ENABLED',
                                          style: PremiumUI.subtitle.copyWith(
                                              fontSize: 8,
                                              color: PremiumUI.secondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                subText,
                                style: const TextStyle(
                                    color: PremiumUI.muted,
                                    fontSize: 13,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (widget.role == 'broker') ...[
                          _buildBrokerBadgeReviewCard(),
                          const SizedBox(height: 20),
                        ],
                        if (widget.role == 'broker') ...[
                          _buildField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Name is required'
                                    : null,
                          ),
                          _buildField(
                            controller: _companyController,
                            label: 'Company Name',
                            icon: Icons.business,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Company name is required'
                                    : null,
                          ),
                          _buildField(
                            controller: _reraController,
                            label: 'RERA Registration Number',
                            icon: Icons.assignment_turned_in,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'RERA number is required';
                              }
                              // India RERA format: starts with letter(s), followed by digits,
                              // optionally separated by hyphens. Min 9 chars.
                              // Examples: A51800012345, A51800012345-DT, A5100012345
                              final cleaned = val.trim().toUpperCase();
                              final reraRegex =
                                  RegExp(r'^[A-Z]{1,3}[0-9A-Z\-]{8,}$');
                              if (!reraRegex.hasMatch(cleaned)) {
                                return 'Enter a valid RERA number (e.g. A51800012345)';
                              }
                              return null;
                            },
                          ),
                          _buildField(
                            controller: _areaController,
                            label: 'Primary Working Locality / Area',
                            icon: Icons.place,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Working area is required'
                                    : null,
                          ),
                          _buildField(
                            controller: _cityController,
                            label: 'City',
                            icon: Icons.location_city,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'City is required'
                                    : null,
                          ),
                          _buildField(
                            controller: _specialityController,
                            label: 'Speciality / Project Focus',
                            icon: Icons.star,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Focus / speciality is required'
                                    : null,
                          ),
                        ] else ...[
                          _buildField(
                            controller: _monthlyTargetController,
                            label: 'Monthly Target (Leads/Visits)',
                            icon: Icons.track_changes,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Target is required';
                              }
                              if (int.tryParse(val) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          _buildField(
                            controller: _brokerNetworkSizeController,
                            label: 'Active Broker Network Size',
                            icon: Icons.people,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Network size is required';
                              }
                              if (int.tryParse(val) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PremiumUI.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor:
                                PremiumUI.primary.withValues(alpha: 0.4),
                          ),
                          onPressed: _saveProfile,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_open,
                                  size: 16, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                'ACTIVATE & ENCRYPT PROFILE',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 1.1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBrokerBadgeReviewCard() {
    return PremiumUI.glassCard(
      opacity: 0.06,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified, color: PremiumUI.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Verified Broker Badge Review',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Complete profile data, keep RERA details valid, add quality leads, drive verified visits, and protect brokerage through broker locks.',
            style:
                TextStyle(color: PremiumUI.muted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ReviewChip(label: 'Profile data'),
              _ReviewChip(label: 'RERA verified'),
              _ReviewChip(label: 'Quality leads'),
              _ReviewChip(label: 'Verified visits'),
              _ReviewChip(label: 'Broker locks'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewChip extends StatelessWidget {
  const _ReviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: PremiumUI.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PremiumUI.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              color: PremiumUI.accent, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
