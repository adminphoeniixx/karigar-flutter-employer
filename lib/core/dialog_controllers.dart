import 'package:flutter/foundation.dart';

/// How long a closed dialog or sheet may still be animating out.
const dialogExitTime = Duration(milliseconds: 600);

/// Disposes the text controllers of a dialog or sheet that has just closed.
///
/// `showDialog` returns as soon as the route is popped, while it is still
/// animating out and its text fields still use the controllers. Disposing
/// them at once crashed the app ("_dependents.isEmpty"), most of all when a
/// field had focus, e.g. right after typing the offered pay in Hire.
void disposeAfterClose(Iterable<ChangeNotifier> controllers) {
  final pending = controllers.toList();
  Future<void>.delayed(dialogExitTime, () {
    for (final controller in pending) {
      controller.dispose();
    }
  });
}
