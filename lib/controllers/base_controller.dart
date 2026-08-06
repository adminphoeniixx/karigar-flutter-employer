import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';

abstract class BaseController extends ChangeNotifier {
  bool loading = false;
  String? error;

  Future<T?> run<T>(Future<T> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      return await action();
    } on ApiException catch (exception) {
      error = exception.message;
      return null;
    } catch (_) {
      error = 'Kuch galat ho gaya. Dobara try karein.';
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
