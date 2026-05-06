import 'package:flutter/material.dart';

class ConnectivityManager {
  static void listen(BuildContext context) {
    // No-op fallback: avoids adding runtime network dependencies to the PWA shell.
  }

  static Future<bool> hasConnection() async => true;
}
