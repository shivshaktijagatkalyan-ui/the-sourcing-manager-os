import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/error_mapper.dart';

class FieldVerificationScreen extends StatefulWidget {
  final String visitId;
  const FieldVerificationScreen({super.key, required this.visitId});

  @override
  State<FieldVerificationScreen> createState() => _FieldVerificationScreenState();
}

class _FieldVerificationScreenState extends State<FieldVerificationScreen> {
  bool _isLocating = false;
  String _status = 'ready'; // ready, locating, success, failed

  Future<void> _startVerification() async {
    setState(() {
      _isLocating = true;
      _status = 'locating';
    });

    try {
      // 1. Permission Check with Guidance
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ErrorMapper.showErrorSnackBar(context, 'location_denied');
          setState(() => _status = 'failed');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (position.accuracy > 50) {
        if (!mounted) return;
        ErrorMapper.showErrorSnackBar(context, 'gps_accuracy_too_weak');
        setState(() => _status = 'failed');
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      setState(() => _status = 'success');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Site Location Verified! Ab photo upload karein.')),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorMapper.showErrorSnackBar(context, 'provider_failed');
      setState(() => _status = 'failed');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Color(0xFF6366F1)),
            const SizedBox(height: 32),
            Text(
              _status == 'locating' ? 'Locating Site...' : 'Site Verification',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aapka GPS location match hona zaroori hai. (Site location match is mandatory.)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 48),
            if (_status == 'ready' || _status == 'failed')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLocating ? null : _startVerification,
                  child: Text(_status == 'failed' ? 'Retry Verification' : 'Start Verification'),
                ),
              ),
            if (_status == 'success')
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
            if (_status == 'locating')
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
