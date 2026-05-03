import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';

class SiteVisitVerifyScreen extends StatefulWidget {
  final String visitId;
  const SiteVisitVerifyScreen({super.key, required this.visitId});

  @override
  State<SiteVisitVerifyScreen> createState() => _SiteVisitVerifyScreenState();
}

class _SiteVisitVerifyScreenState extends State<SiteVisitVerifyScreen> {
  Map<String, dynamic>? _visitData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVisit();
  }

  Future<void> _loadVisit() async {
    try {
      final client = Supabase.instance.client;
      final data = await client
          .from('site_visits')
          .select('*, projects(*), leads_public(alias)')
          .eq('id', widget.visitId)
          .single();
      setState(() {
        _visitData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _invokeEdgeFunction(String name, Map<String, dynamic> body) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(name, body: body);
      
      if (response.status != 200) {
        final errorData = response.data;
        throw Exception(errorData['error'] ?? 'Function failed');
      }
      
      await _loadVisit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startVisit() async {
    await _invokeEdgeFunction('start-site-visit', {'site_visit_id': widget.visitId});
  }

  Future<void> _verifyGPS() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permission denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      await _invokeEdgeFunction('verify-site-gps', {
        'site_visit_id': widget.visitId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_meters': position.accuracy,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPhoto() async {
    setState(() => _isLoading = true);
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      final client = Supabase.instance.client;
      final bytes = await image.readAsBytes();
      
      // We use a manual multipart request because supabase-flutter functions 
      // invoke currently doesn't support multipart/form-data directly for file uploads easily
      const functionUrl = '${AppConfig.supabaseUrl}/functions/v1/upload-site-photo';
      final uri = Uri.parse(functionUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${client.auth.currentSession?.accessToken}'
        ..fields['site_visit_id'] = widget.visitId
        ..files.add(http.MultipartFile.fromBytes('photo', bytes, filename: 'visit.jpg'));

      final response = await request.send();
      if (response.statusCode != 200) {
        final respBody = await response.stream.bytesToString();
        throw Exception('Upload failed: $respBody');
      }

      await _loadVisit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _visitData == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(body: Center(child: Text(_errorMessage!)));

    final visit = _visitData!;
    final status = visit['status'];
    final projectName = visit['projects']['project_name'];

    return Scaffold(
      appBar: AppBar(title: const Text('Visit Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoCard(projectName: projectName, leadAlias: visit['leads_public']['alias']),
            const SizedBox(height: 32),
            _StepItem(
              title: '1. Start Visit session',
              isCompleted: status != 'scheduled',
              isActive: status == 'scheduled',
              onPressed: _startVisit,
              buttonLabel: 'Initialize Session',
            ),
            _StepItem(
              title: '2. GPS Geofence Check',
              isCompleted: visit['gps_status'] == 'verified',
              isActive: status == 'started' || status == 'gps_submitted',
              onPressed: _verifyGPS,
              buttonLabel: 'Capture Location',
              subtitle: visit['distance_from_project_meters'] != null 
                ? 'Distance: ${visit['distance_from_project_meters'].toStringAsFixed(1)}m' : null,
            ),
            _StepItem(
              title: '3. Live Photo Evidence',
              isCompleted: status == 'broker_review_pending' || status == 'completed',
              isActive: status == 'gps_verified',
              onPressed: _uploadPhoto,
              buttonLabel: 'Take Site Photo',
            ),
            const SizedBox(height: 32),
            if (status == 'broker_review_pending')
              const _ReviewPendingCard()
            else if (status == 'completed')
              const _VerifiedSuccessCard(),
            
            if (_isLoading) const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isCompleted;
  final bool isActive;
  final VoidCallback onPressed;
  final String buttonLabel;

  const _StepItem({
    required this.title,
    this.subtitle,
    required this.isCompleted,
    required this.isActive,
    required this.onPressed,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? Colors.green : (isActive ? Colors.blue : Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActive || isCompleted ? Colors.white : Colors.white24)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (isActive) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String projectName;
  final String leadAlias;
  const _InfoCard({required this.projectName, required this.leadAlias});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(leadAlias, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(projectName, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReviewPendingCard extends StatelessWidget {
  const _ReviewPendingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
      child: const Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(child: Text('Verification Complete. Waiting for Broker approval to activate lock.', style: TextStyle(color: Colors.orange, fontSize: 12))),
        ],
      ),
    );
  }
}

class _VerifiedSuccessCard extends StatelessWidget {
  const _VerifiedSuccessCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
      child: const Row(
        children: [
          Icon(Icons.verified, color: Colors.green),
          SizedBox(width: 12),
          Expanded(child: Text('Visit Completed & Verified. 45-day Broker Lock is now ACTIVE.', style: TextStyle(color: Colors.green, fontSize: 12))),
        ],
      ),
    );
  }
}
