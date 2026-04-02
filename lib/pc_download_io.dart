import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [bytes] to the user's Downloads folder (or platform equivalent).
/// Picks a non-colliding file name. Returns the full path, or null if unavailable.
Future<String?> saveBytesToDownloads(List<int> bytes, String fileName) async {
  final Directory? dir = await getDownloadsDirectory();
  if (dir == null) return null;

  var path = '${dir.path}${Platform.pathSeparator}$fileName';
  if (await File(path).exists()) {
    final dot = fileName.lastIndexOf('.');
    final base = dot <= 0 ? fileName : fileName.substring(0, dot);
    final ext = dot < 0 ? '' : fileName.substring(dot);
    var i = 1;
    do {
      path = '${dir.path}${Platform.pathSeparator}$base ($i)$ext';
      i++;
    } while (await File(path).exists());
  }

  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
