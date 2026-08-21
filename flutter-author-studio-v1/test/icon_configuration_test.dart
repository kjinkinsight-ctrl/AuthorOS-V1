import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthorOS icon source exists, is square, and is the only launcher source',
      () {
    const sourcePath = 'assets/icon/authoros_icon.png';
    final iconFile = File(sourcePath);

    expect(iconFile.existsSync(), isTrue, reason: 'Missing $sourcePath');

    final bytes = iconFile.readAsBytesSync();
    expect(bytes.length, greaterThan(24));
    expect(bytes.sublist(0, 8), const [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'IHDR');

    final data = ByteData.sublistView(bytes);
    final width = data.getUint32(16, Endian.big);
    final height = data.getUint32(20, Endian.big);
    expect(width, height);

    final pubspecLines = const LineSplitter().convert(
      File('pubspec.yaml').readAsStringSync(),
    );

    final launcherConfigLines = <String>[];
    var inLauncherConfig = false;
    for (final line in pubspecLines) {
      if (line == 'flutter_launcher_icons:') {
        inLauncherConfig = true;
        launcherConfigLines.add(line);
        continue;
      }
      if (inLauncherConfig && line.isNotEmpty && !line.startsWith(' ')) {
        break;
      }
      if (inLauncherConfig) {
        launcherConfigLines.add(line);
      }
    }

    final imagePathPattern = RegExp(r'image_path(?:_[a-z]+)?\s*:\s*"([^"]+)"');
    final imagePaths = <String>[];
    for (final line in launcherConfigLines) {
      final match = imagePathPattern.firstMatch(line);
      if (match != null) {
        imagePaths.add(match.group(1)!);
      }
    }

    expect(imagePaths, isNotEmpty);
    expect(imagePaths, everyElement(sourcePath));
  });
}
