-- Define permissions that Edge Functions already require so protected
-- workflows fail closed by role/template policy, not by missing metadata.

INSERT INTO public.permission_definitions (id, name, description) VALUES
  ('can_manage_payouts', 'Manage Payouts', 'Run payout eligibility and generate payout statements'),
  ('can_flag_abuse', 'Flag Abuse Events', 'Create sanitized operational abuse events'),
  ('can_resolve_abuse', 'Resolve Abuse Events', 'Resolve sanitized abuse events'),
  ('can_generate_risk_summaries', 'Generate Risk Summaries', 'Generate sanitized organization risk summaries'),
  ('can_run_trust_decay', 'Run Trust Decay', 'Run explainable trust score decay jobs'),
  ('can_view_audit_logs', 'View Audit Logs', 'Read sanitized audit logs for scoring and review')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

INSERT INTO public.role_permissions (role_id, permission_id) VALUES
  ('platform_admin', 'can_manage_payouts'),
  ('platform_admin', 'can_flag_abuse'),
  ('platform_admin', 'can_resolve_abuse'),
  ('platform_admin', 'can_generate_risk_summaries'),
  ('platform_admin', 'can_run_trust_decay'),
  ('platform_admin', 'can_view_audit_logs'),
  ('developer_admin', 'can_generate_risk_summaries'),
  ('developer_admin', 'can_view_audit_logs'),
  ('dispute_admin', 'can_flag_abuse'),
  ('dispute_admin', 'can_resolve_abuse'),
  ('dispute_admin', 'can_view_audit_logs'),
  ('finance_admin', 'can_manage_payouts'),
  ('read_only_auditor', 'can_view_audit_logs')
ON CONFLICT DO NOTHING;
