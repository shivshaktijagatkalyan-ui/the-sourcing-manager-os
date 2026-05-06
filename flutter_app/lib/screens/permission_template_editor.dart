import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PermissionTemplateEditor extends StatefulWidget {
  const PermissionTemplateEditor({super.key});

  @override
  State<PermissionTemplateEditor> createState() => _PermissionTemplateEditorState();
}

class _PermissionTemplateEditorState extends State<PermissionTemplateEditor> {
  final _orgController = TextEditingController();
  final _nameController = TextEditingController(text: 'operator_template');
  final Set<String> _selected = {'can_manage_org_users'};
  bool _isSaving = false;

  static const _permissions = [
    'can_upload_leads',
    'can_grant_data_loans',
    'can_call_leads',
    'can_create_site_visits',
    'can_verify_site_visits',
    'can_review_site_visits',
    'can_view_disputes',
    'can_resolve_disputes',
    'can_view_payouts',
    'can_generate_statements',
    'can_view_compliance_reports',
    'can_manage_org_users',
    'can_pause_org',
    'can_suspend_user',
    'can_view_risk_dashboard',
  ];

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'update-permission-template',
        body: {
          'organization_id': _orgController.text.trim(),
          'name': _nameController.text.trim(),
          'permissions': _selected.toList(),
        },
      );
      if (!mounted) return;
      final ok = response.status == 200 && response.data?['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Template saved.' : 'Template update blocked.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permission Templates')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _orgController,
            decoration: const InputDecoration(labelText: 'Organization ID', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Template Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ..._permissions.map((permission) => CheckboxListTile(
                value: _selected.contains(permission),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(permission);
                    } else {
                      _selected.remove(permission);
                    }
                  });
                },
                title: Text(permission.replaceAll('_', ' ')),
                dense: true,
              )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Saving...' : 'Save Template'),
          ),
        ],
      ),
    );
  }
}
