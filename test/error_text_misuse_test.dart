import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// errorText() turns anything that is not an exception into "Something went
/// wrong". Once it was pasted onto plain data (`.map((e) => errorText(e))`
/// over KYC document keys), and every document showed that text instead.
void main() {
  test('errorText is only used on caught errors, never mapped over data', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'\.map\(\(\w+\) => errorText\(').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
