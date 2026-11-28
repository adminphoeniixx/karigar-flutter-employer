/// GSTIN (GST number) checks, the same as the server's `App\Support\Gstin`:
/// 15 characters, the right shape, a real state code and the check character
/// GSTN works out from the first 14 (it catches a mistyped character).
library;

/// Upper-case, without the spaces, dots and dashes people type; the server
/// drops exactly these.
String normalizeGstin(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');

/// What is wrong with a typed GST number, or null when it is fine or empty.
/// Callers that require one check for empty themselves.
String? gstinProblem(String? value) {
  final gst = normalizeGstin(value ?? '');
  if (gst.isEmpty) return null;
  if (gst.length != 15) {
    return 'A GST number has 15 characters, like 22ABCDE1234F1ZA.';
  }
  if (!RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
  ).hasMatch(gst)) {
    return 'Enter the GST number in the format 22ABCDE1234F1ZA.';
  }
  final stateCode = int.parse(gst.substring(0, 2));
  final knownState =
      (stateCode >= 1 &&
          stateCode <= 38 &&
          stateCode != 25 &&
          stateCode != 28) ||
      stateCode == 97;
  if (!knownState) {
    return 'A GST number starts with a state code (01–38). Check the first two digits.';
  }
  const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  var sum = 0;
  for (var index = 0; index < 14; index++) {
    final value = chars.indexOf(gst[index]) * (index.isEven ? 1 : 2);
    sum += value ~/ 36 + value % 36;
  }
  if (gst[14] != chars[(36 - sum % 36) % 36]) {
    return 'This GST number is not valid. Check it for a typing mistake.';
  }
  return null;
}
