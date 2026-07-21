import 'dart:io';

String get testBashExecutable {
  if (!Platform.isWindows) return 'bash';
  final roots = [
    Platform.environment['ProgramFiles'],
    Platform.environment['LOCALAPPDATA'],
  ].whereType<String>();
  for (final root in roots) {
    for (final suffix in [
      'Git/usr/bin/bash.exe',
      'Programs/Git/usr/bin/bash.exe',
    ]) {
      final candidate = File('$root/$suffix');
      if (candidate.existsSync()) return candidate.path;
    }
  }
  throw StateError(
    'Git for Windows bash.exe is required for POSIX workflow tests.',
  );
}

String bashPath(String path) {
  if (!Platform.isWindows) return path;
  final normalized = File(path).absolute.path.replaceAll('\\', '/');
  final drive = RegExp(r'^([A-Za-z]):/(.*)$').firstMatch(normalized);
  return drive == null
      ? normalized
      : '/${drive.group(1)!.toLowerCase()}/${drive.group(2)}';
}

MapEntry<String, String> pathWithPrefix(String directory) {
  final key = Platform.environment.keys.firstWhere(
    (candidate) => candidate.toUpperCase() == 'PATH',
    orElse: () => 'PATH',
  );
  final separator = Platform.isWindows ? ';' : ':';
  return MapEntry(
    key,
    '$directory$separator${Platform.environment[key] ?? ''}',
  );
}
