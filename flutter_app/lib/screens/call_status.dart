import 'package:flutter/material.dart';

class CallStatusDialog extends StatefulWidget {
  final String leadId;
  const CallStatusDialog({super.key, required this.leadId});

  @override
  State<CallStatusDialog> createState() => _CallStatusDialogState();
}

class _CallStatusDialogState extends State<CallStatusDialog> {
  String _status = 'connecting'; // connecting, queued, failed, etc.
  String? _error;

  @override
  void initState() {
    super.initState();
    _initiateCall();
  }

  Future<void> _initiateCall() async {
    // Simulated call to Edge Function: initiate-call
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _status = 'queued';
      });
    }

    // In a real app, we would listen to status changes via Supabase Realtime
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bridge call established. Please check your phone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              color: _status == 'failed' ? Colors.red.withOpacity(0.1) : Colors.indigo.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: _status == 'connecting' 
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    _status == 'queued' ? Icons.check_circle : Icons.error,
                    size: 40,
                    color: _status == 'queued' ? Colors.green : Colors.red,
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            _status == 'connecting' ? 'Initiating Secure Bridge...' : 
            _status == 'queued' ? 'Call Queued' : 'Call Failed',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _status == 'connecting' ? 'Connecting to Exotel PSTN Bridge' :
            _status == 'queued' ? 'Your phone will ring shortly to connect you to the lead.' :
            _error ?? 'An unexpected error occurred.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 32),
          if (_status == 'failed')
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }
}
