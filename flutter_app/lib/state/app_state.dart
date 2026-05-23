import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  String _role = 'anonymous';
  bool _busy = false;

  String get role => _role;
  bool get busy => _busy;

  void setRole(String role) {
    if (_role == role) return;
    _role = role;
    notifyListeners();
  }

  void setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
