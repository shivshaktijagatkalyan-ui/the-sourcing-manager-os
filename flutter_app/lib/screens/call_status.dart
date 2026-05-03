import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';

class CallStatusDialog extends StatefulWidget {
  final String leadId;
  const CallStatusDialog({super.key, required this.leadId});

  @override
  State<CallStatusDialog> createState() => _CallStatusDialogState();
}

class _CallStatusDialogState extends State<CallStatusDialog> {
  String _status = 'connecting';
  String? _reason;

  @override
  void initState() {
    super.initState();
    _initiateCall();
  }

  Future<void> _initiateCall() async {
    setState(() {
      _status = 'connecting';
      _reason = null;
    });

    if (!AppConfig.isSupabaseConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _status = 'queued');
      return;
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'initiate-call',
        body: {'lead_id': widget.leadId},
      );

      final data = response.data;
      if (data is Map && data['ok'] == true) {
        setState(() => _status = '${data['status'] ?? 'queued'}');
        return;
      }

      setState(() {
        _status = 'blocked';
        _reason = data is Map ? '${data['reason'] ?? 'access_denied'}' : 'access_denied';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'provider_failed';
        _reason = 'provider_failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(_reason ?? _status);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: _status == 'connecting'
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(style.icon, size: 40, color: style.color),
          ),
          const SizedBox(height: 24),
          Text(
            style.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            style.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_status == 'queued' ? 'Done' : 'Close'),
          ),
        ],
      ),
    );
  }
}

class _CallStyle {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const _CallStyle({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

_CallStyle _styleFor(String state) {
  switch (state) {
    case 'connecting':
      return const _CallStyle(
        title: 'Connecting',
        message: 'Validating data loan and requesting Exotel PSTN bridge.',
        icon: Icons.sync,
        color: Colors.indigo,
      );
    case 'queued':
      return const _CallStyle(
        title: 'Queued',
        message: 'The PSTN bridge was accepted. No sensitive data was returned.',
        icon: Icons.check_circle,
        color: Colors.green,
      );
    case 'loan_expired':
      return const _CallStyle(
        title: 'Expired',
        message: 'The data loan has expired. Ask the broker for a fresh grant.',
        icon: Icons.timer_off,
        color: Colors.orange,
      );
    case 'revoked':
      return const _CallStyle(
        title: 'Revoked',
        message: 'The broker revoked this data loan. Access is blocked.',
        icon: Icons.block,
        color: Colors.red,
      );
    case 'dnd_blocked':
      return const _CallStyle(
        title: 'DND Blocked',
        message: 'TRAI DND status blocks this outreach attempt.',
        icon: Icons.do_not_disturb_on,
        color: Colors.red,
      );
    case 'consent_required':
      return const _CallStyle(
        title: 'Consent Required',
        message: 'Consent is not granted for this action.',
        icon: Icons.privacy_tip,
        color: Colors.orange,
      );
    case 'provider_failed':
      return const _CallStyle(
        title: 'Provider Failed',
        message: 'The PSTN provider request failed closed.',
        icon: Icons.error,
        color: Colors.red,
      );
    default:
      return const _CallStyle(
        title: 'Blocked',
        message: 'Access denied. Active data loan required.',
        icon: Icons.lock,
        color: Colors.red,
      );
  }
}
