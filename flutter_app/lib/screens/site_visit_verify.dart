import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../services/sync_service.dart';
import '../utils/training_runtime.dart';
import '../utils/premium_ui.dart';

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
      if (AppConfig.isTrainingMode) {
        final runtime = TrainingRuntime.instance;
        final visits =
            runtime.siteVisitsForManager(TrainingRuntime.sourcingManagerId);
        final visit = visits.firstWhere((v) => v['id'] == widget.visitId);
        setState(() {
          _visitData = visit;
          _isLoading = false;
        });
        return;
      }

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

  Future<void> _invokeEdgeFunction(
      String name, Map<String, dynamic> body) async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final response = await client.functions.invoke(name, body: body);

        if (response.status != 200) {
          final errorData = response.data;
          throw Exception(errorData['error'] ?? 'Function failed');
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }

      await _loadVisit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: PremiumUI.danger));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startVisit() async {
    if (AppConfig.isTrainingMode) {
      await TrainingRuntime.instance.startSiteVisit(widget.visitId);
      await _loadVisit();
      return;
    }
    await _invokeEdgeFunction(
        'start-site-visit', {'site_visit_id': widget.visitId});
  }

  Future<void> _verifyGPS() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission denied.');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (AppConfig.isTrainingMode) {
        await TrainingRuntime.instance.verifySiteGps(
            widget.visitId, position.latitude, position.longitude);
        await _loadVisit();
        return;
      }

      await _invokeEdgeFunction('verify-site-gps', {
        'site_visit_id': widget.visitId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_meters': position.accuracy,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('GPS Error: $e'), backgroundColor: PremiumUI.danger));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPhoto() async {
    setState(() => _isLoading = true);
    Uint8List? originalPhotoBytes;
    Position? offlinePosition;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      originalPhotoBytes = await image.readAsBytes();
      offlinePosition = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (AppConfig.isTrainingMode) {
        await TrainingRuntime.instance.uploadSitePhoto(widget.visitId);
        await _loadVisit();
        return;
      }

      final client = Supabase.instance.client;
      final bytes = SyncService.instance.compressVisitPhoto(originalPhotoBytes);

      const functionUrl =
          '${AppConfig.supabaseUrl}/functions/v1/upload-site-photo';
      final uri = Uri.parse(functionUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] =
            'Bearer ${client.auth.currentSession?.accessToken}'
        ..fields['site_visit_id'] = widget.visitId
        ..files.add(http.MultipartFile.fromBytes('photo', bytes,
            filename: 'visit.jpg'));

      final response = await request.send();
      if (response.statusCode != 200) {
        final respBody = await response.stream.bytesToString();
        throw Exception('Upload failed: $respBody');
      }

      await _loadVisit();
    } catch (e) {
      if (!mounted) return;
      if (!AppConfig.isTrainingMode &&
          originalPhotoBytes != null &&
          offlinePosition != null) {
        try {
          final visitDate =
              DateTime.tryParse('${_visitData?['visit_date'] ?? ''}');
          await SyncService.instance.queueOfflineCheckIn(
            siteVisitId: widget.visitId,
            latitude: offlinePosition.latitude,
            longitude: offlinePosition.longitude,
            accuracyMeters: offlinePosition.accuracy,
            photoBytes: originalPhotoBytes,
            visitWindowExpiresAt: visitDate,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Offline proof queued. It will sync when connection returns.'),
              backgroundColor: PremiumUI.warning,
            ),
          );
          return;
        } catch (queueError) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Queue Error: $queueError'),
                backgroundColor: PremiumUI.danger),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload Error: $e'),
          backgroundColor: PremiumUI.danger));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _visitData == null) {
      return const Scaffold(
          backgroundColor: PremiumUI.background,
          body: Center(
              child: CircularProgressIndicator(color: PremiumUI.primary)));
    }
    if (_errorMessage != null) {
      return Scaffold(
          backgroundColor: PremiumUI.background,
          body: Center(
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.white))));
    }

    final visit = _visitData!;
    final status = visit['status'];
    final projectName = visit['projects']['project_name'];

    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: Text('SITE VERIFICATION',
            style: PremiumUI.h1.copyWith(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoPanel(projectName, visit['leads_public']['alias']),
            const SizedBox(height: 40),
            _buildTimelineStep(
              number: '01',
              title: 'SESSION INITIALIZATION',
              subtitle: 'Securing audit trail and timestamp.',
              isCompleted: status != 'scheduled',
              isActive: status == 'scheduled',
              onPressed: _startVisit,
              buttonLabel: 'START SESSION',
            ),
            _buildTimelineStep(
              number: '02',
              title: 'GPS GEOFENCE VALIDATION',
              subtitle: visit['distance_from_project_meters'] != null
                  ? 'Distance: ${visit['distance_from_project_meters'].toStringAsFixed(1)}m from site'
                  : 'Proving physical presence at project site.',
              isCompleted: visit['gps_status'] == 'verified',
              isActive: status == 'started' || status == 'gps_submitted',
              onPressed: _verifyGPS,
              buttonLabel: 'VALIDATE LOCATION',
            ),
            _buildTimelineStep(
              number: '03',
              title: 'PHOTO EVIDENCE',
              subtitle: 'Live camera capture for proof of visit.',
              isCompleted:
                  status == 'broker_review_pending' || status == 'completed',
              isActive: status == 'gps_verified',
              onPressed: _uploadPhoto,
              buttonLabel: 'CAPTURE PHOTO',
              isLast: true,
            ),
            const SizedBox(height: 40),
            if (status == 'broker_review_pending')
              _buildStatusAlert(
                'VERIFICATION PENDING',
                'Visit captured successfully. Waiting for Broker to verify and activate the 45-day lock.',
                PremiumUI.warning,
                Icons.hourglass_bottom,
              )
            else if (status == 'completed')
              _buildStatusAlert(
                'VISIT VERIFIED',
                'Performance audit complete. 45-day Broker Lock is now ACTIVE in the Business Vault.',
                PremiumUI.secondary,
                Icons.verified,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel(String project, String lead) {
    return PremiumUI.glassCard(
      color: PremiumUI.accent,
      opacity: 0.1,
      child: Column(
        children: [
          Text(lead.toUpperCase(),
              style: PremiumUI.h1.copyWith(fontSize: 22, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.apartment, color: PremiumUI.accent, size: 16),
              const SizedBox(width: 8),
              Text(project,
                  style: const TextStyle(
                      color: PremiumUI.accent, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String number,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required VoidCallback onPressed,
    required String buttonLabel,
    bool isLast = false,
  }) {
    final color = isCompleted
        ? PremiumUI.secondary
        : (isActive
            ? PremiumUI.primary
            : PremiumUI.muted.withValues(alpha: 0.3));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: color, size: 16)
                      : Text(number,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: isActive || isCompleted
                          ? Colors.white
                          : Colors.white24,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                      color: isActive || isCompleted
                          ? PremiumUI.muted
                          : Colors.white10,
                      fontSize: 11,
                    )),
                if (isActive) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : onPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumUI.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : Text(buttonLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAlert(
      String title, String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
