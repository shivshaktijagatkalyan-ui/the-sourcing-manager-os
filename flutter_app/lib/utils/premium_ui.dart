import 'package:flutter/material.dart';
import 'dart:ui';

class PremiumUI {
  static const Color background = Color(0xFF0F172A);
  static const Color cardColor = Color(0xFF18212F);
  static const Color panelColor = Color(0xFF111827);
  static const Color primary = Color(0xFFF5B545);
  static const Color secondary = Color(0xFF10B981);
  static const Color accent = Color(0xFF38BDF8);
  static const Color hot = Color(0xFF8B5CF6);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF97316);
  static const Color muted = Color(0xFF94A3B8);

  static BoxDecoration glassBox({Color? color, double opacity = 0.05, double blur = 10}) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: (color ?? Colors.white).withValues(alpha: 0.1)),
    );
  }

  static Widget glassCard({required Widget child, Color? color, double opacity = 0.05}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: glassBox(color: color, opacity: opacity),
          child: child,
        ),
      ),
    );
  }

  static BoxDecoration cyberPanel({required Color color}) {
    return BoxDecoration(
      color: panelColor,
      borderRadius: BorderRadius.circular(12),
      border: Border(
        left: BorderSide(color: color, width: 4),
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static TextStyle h1 = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: Colors.white,
  );

  static TextStyle subtitle = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: Colors.white54,
  );

  static Widget kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color, blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: h1.copyWith(color: Colors.white, fontSize: 22)),
              const SizedBox(height: 4),
              Text(label.toUpperCase(), style: subtitle.copyWith(color: color, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget sectionShell({
    required String title,
    String? subtitle,
    required Widget child,
    Color accentColor = primary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.45), blurRadius: 10)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: subtitle == null
                      ? PremiumUI.subtitle.copyWith(color: Colors.white)
                      : PremiumUI.subtitle.copyWith(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  static Widget statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'active':
      case 'verified':
      case 'completed':
      case 'approved':
        return secondary;
      case 'pending':
      case 'scheduled':
      case 'assigned':
        return accent;
      case 'follow_up':
      case 'follow-up':
      case 'due':
        return warning;
      case 'hot':
      case 'interested':
        return hot;
      case 'critical':
      case 'severe':
      case 'blocked':
      case 'rejected':
      case 'expired':
      case 'revoked':
      case 'invalid':
        return danger;
      case 'high':
      case 'medium':
        return warning;
      default:
        return muted;
    }
  }
}
