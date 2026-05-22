import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../app_config.dart';

class OfflineCheckInRecord {
  const OfflineCheckInRecord({
    required this.id,
    required this.siteVisitId,
    required this.encryptedPayload,
    required this.createdAt,
    required this.retryCount,
  });

  final String id;
  final String siteVisitId;
  final String encryptedPayload;
  final DateTime createdAt;
  final int retryCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_visit_id': siteVisitId,
        'encrypted_payload': encryptedPayload,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
      };

  static OfflineCheckInRecord fromJson(Map<dynamic, dynamic> json) {
    return OfflineCheckInRecord(
      id: json['id'] as String,
      siteVisitId: json['site_visit_id'] as String,
      encryptedPayload: json['encrypted_payload'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
    );
  }

  OfflineCheckInRecord incrementRetry() {
    return OfflineCheckInRecord(
      id: id,
      siteVisitId: siteVisitId,
      encryptedPayload: encryptedPayload,
      createdAt: createdAt,
      retryCount: retryCount + 1,
    );
  }
}

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();
  static const _queueBoxName = 'futuretrust_offline_checkins_v1';
  static const _queueSecret = String.fromEnvironment('OFFLINE_QUEUE_KEY',
      defaultValue: 'futuretrust-local-offline-queue-key');

  final _uuid = const Uuid();
  final _algorithm = AesGcm.with256bits();
  Box<Map<dynamic, dynamic>>? _queueBox;
  Timer? _syncTimer;
  bool _syncInProgress = false;

  Future<void> initialize() async {
    if (_queueBox != null) return;
    await Hive.initFlutter();
    _queueBox = await Hive.openBox<Map<dynamic, dynamic>>(_queueBoxName);
  }

  void startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(syncPendingCheckIns());
    });
  }

  Future<int> pendingCount() async {
    await initialize();
    return _queueBox?.length ?? 0;
  }

  Future<OfflineCheckInRecord> queueOfflineCheckIn({
    required String siteVisitId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required Uint8List photoBytes,
    DateTime? visitWindowExpiresAt,
  }) async {
    await initialize();
    final compressedPhoto = compressVisitPhoto(photoBytes);
    final payload = {
      'site_visit_id': siteVisitId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'photo_jpeg_base64': base64Encode(compressedPhoto),
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'visit_window_expires_at':
          visitWindowExpiresAt?.toUtc().toIso8601String(),
    };

    final encryptedPayload = await _encryptJson(payload);
    final record = OfflineCheckInRecord(
      id: _uuid.v4(),
      siteVisitId: siteVisitId,
      encryptedPayload: encryptedPayload,
      createdAt: DateTime.now().toUtc(),
      retryCount: 0,
    );
    await _queueBox!.put(record.id, record.toJson());
    return record;
  }

  Uint8List compressVisitPhoto(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = img.copyResize(decoded, width: 800, height: 600);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  }

  Future<void> syncPendingCheckIns() async {
    await initialize();
    if (_syncInProgress || _queueBox == null || _queueBox!.isEmpty) return;
    _syncInProgress = true;

    try {
      final client = Supabase.instance.client;
      final keys = _queueBox!.keys.toList(growable: false);
      for (final key in keys) {
        final stored = _queueBox!.get(key);
        if (stored == null) continue;
        final record = OfflineCheckInRecord.fromJson(stored);
        try {
          final payload = await _decryptJson(record.encryptedPayload);
          final gpsResponse = await client.functions.invoke(
            'verify-site-gps',
            body: {
              'site_visit_id': record.siteVisitId,
              'latitude': payload['latitude'],
              'longitude': payload['longitude'],
              'accuracy_meters': payload['accuracy_meters'],
              'offline_sync': true,
              'offline_captured_at': payload['captured_at'],
            },
          );

          if (gpsResponse.status != 200 && gpsResponse.status != 202) {
            throw StateError('gps_sync_failed_${gpsResponse.status}');
          }

          final photoBytes =
              base64Decode(payload['photo_jpeg_base64'] as String);
          final uploadResponse = await _uploadCompressedPhoto(
              client, record.siteVisitId, photoBytes);
          if (uploadResponse < 200 || uploadResponse >= 300) {
            throw StateError('photo_sync_failed_$uploadResponse');
          }

          await _queueBox!.delete(key);
        } catch (error) {
          debugPrint('SyncService: offline check-in sync failed: $error');
          await _queueBox!.put(key, record.incrementRetry().toJson());
        }
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<int> _uploadCompressedPhoto(
      SupabaseClient client, String siteVisitId, Uint8List bytes) async {
    final functionUri =
        Uri.parse('${AppConfig.supabaseUrl}/functions/v1/upload-site-photo');
    final request = http.MultipartRequest('POST', functionUri)
      ..headers['Authorization'] =
          'Bearer ${client.auth.currentSession?.accessToken}'
      ..fields['site_visit_id'] = siteVisitId
      ..files.add(
          http.MultipartFile.fromBytes('photo', bytes, filename: 'visit.jpg'));

    final response = await request.send();
    return response.statusCode;
  }

  Future<String> _encryptJson(Map<String, dynamic> payload) async {
    final secretKey = await _secretKey();
    final nonce = _randomNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
      nonce: nonce,
    );
    return jsonEncode({
      'nonce': base64Encode(secretBox.nonce),
      'cipher_text': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  Future<Map<String, dynamic>> _decryptJson(String encryptedPayload) async {
    final payload = jsonDecode(encryptedPayload) as Map<String, dynamic>;
    final secretKey = await _secretKey();
    final secretBox = SecretBox(
      base64Decode(payload['cipher_text'] as String),
      nonce: base64Decode(payload['nonce'] as String),
      mac: Mac(base64Decode(payload['mac'] as String)),
    );
    final clearBytes =
        await _algorithm.decrypt(secretBox, secretKey: secretKey);
    return jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
  }

  Future<SecretKey> _secretKey() async {
    final hash = await Sha256().hash(utf8.encode(_queueSecret));
    return SecretKey(hash.bytes);
  }

  List<int> _randomNonce() {
    final random = Random.secure();
    return List<int>.generate(12, (_) => random.nextInt(256));
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
