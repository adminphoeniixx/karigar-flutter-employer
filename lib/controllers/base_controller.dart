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
      if (kDebugMode) {
        debugPrint(
          'API controller error: ${exception.message} '
          '(status: ${exception.statusCode}, code: ${exception.code})',
        );
      }
      return null;
    } catch (exception, stackTrace) {
      error = 'Something went wrong. Please try again.';
      if (kDebugMode) {
        debugPrint('Unexpected controller error: $exception');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
