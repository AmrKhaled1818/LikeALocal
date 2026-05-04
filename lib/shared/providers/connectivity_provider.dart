import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (wasOnline != _isOnline) notifyListeners();
    });
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    notifyListeners();
  }
}
