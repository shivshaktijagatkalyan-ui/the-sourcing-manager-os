import 'package:flutter/material.dart';

class ErrorMapper {
  static Map<String, String> getTranslation(String code, {bool useHinglish = true}) {
    switch (code) {
      case 'outside_geofence':
        return {
          'title': 'Aap Geofence ke bahar hain',
          'message': 'Visit complete karne ke liye site ke paas hona zaroori hai. (Please move closer to the site.)',
        };
      case 'gps_accuracy_too_weak':
        return {
          'title': 'Low GPS Accuracy',
          'message': 'Location signal kamzor hai. Khule aasmaan ke neeche try karein. (Please move to an open area.)',
        };
      case 'dnd_blocked':
        return {
          'title': 'DND Blocked',
          'message': 'Customer DND par hai. Call nahi kiya ja sakta. (Customer is registered on DND.)',
        };
      case 'loan_expired':
        return {
          'title': 'Data Loan Expired',
          'message': 'Call karne ka samay khatam ho gaya hai. Loan renew karein. (Access period has ended.)',
        };
      case 'user_suspended':
        return {
          'title': 'Account Suspended',
          'message': 'Aapka account suspend kar diya gaya hai. Manager se baat karein. (Contact your admin.)',
        };
      case 'org_paused':
        return {
          'title': 'Org Paused',
          'message': 'Aapki company ka access temporary pause hai. (Organization access is paused.)',
        };
      case 'consent_required':
        return {
          'title': 'Consent Missing',
          'message': 'Customer ki permission (Consent) zaroori hai. (Customer consent not granted.)',
        };
      default:
        return {
          'title': 'Kuch galat hua',
          'message': 'Dubara try karein ya support ko contact karein. (Error: $code)',
        };
    }
  }

  static void showErrorSnackBar(BuildContext context, String code) {
    final t = getTranslation(code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(t['message']!, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
