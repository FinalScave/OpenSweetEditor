import 'dart:io';

const List<String> _supportedRoots = <String>[
  'android',
  'ios',
  'macos',
  'windows',
  'linux',
];

void main() {
  final scriptFile = File.fromUri(Platform.script).absolute;
  final packageRoot = scriptFile.parent.parent;
  final repoRoot = packageRoot.parent.parent.parent;
  final prebuiltRoot = Directory(
    '${repoRoot.path}${Platform.pathSeparator}prebuilt',
  );
  final nativeRoot = Directory(
    '${packageRoot.path}${Platform.pathSeparator}native',
  );

  if (!prebuiltRoot.existsSync()) {
    throw StateError('Prebuilt directory not found: ${prebuiltRoot.path}');
  }

  if (nativeRoot.existsSync()) {
    nativeRoot.deleteSync(recursive: true);
  }
  nativeRoot.createSync(recursive: true);

  final copiedTargets = <String>[];
  for (final rootName in _supportedRoots) {
    final sourceDir = Directory(
      '${prebuiltRoot.path}${Platform.pathSeparator}$rootName',
    );
    if (!sourceDir.existsSync()) {
      continue;
    }
    final copiedCount = _copyDirectoryContents(
      sourceDir,
      Directory('${nativeRoot.path}${Platform.pathSeparator}$rootName'),
    );
    if (copiedCount > 0) {
      copiedTargets.add('$rootName ($copiedCount files)');
    }
  }

  if (copiedTargets.isEmpty) {
    stdout.writeln('No native binaries were copied from ${prebuiltRoot.path}.');
    return;
  }

  stdout.writeln('Synced native binaries to ${nativeRoot.path}:');
  for (final target in copiedTargets) {
    stdout.writeln('  - $target');
  }
}

int _copyDirectoryContents(Directory sourceDir, Directory destinationDir) {
  var copiedFiles = 0;
  for (final entity in sourceDir.listSync(followLinks: false)) {
    final name = _entityName(entity.path);
    if (name.isEmpty || name.startsWith('.')) {
      continue;
    }

    final destinationPath =
        '${destinationDir.path}${Platform.pathSeparator}$name';
    if (entity is File) {
      if (_shouldCopyFile(entity)) {
        destinationDir.createSync(recursive: true);
        entity.copySync(destinationPath);
        copiedFiles++;
      }
    } else if (entity is Directory) {
      copiedFiles += _copyDirectory(entity, Directory(destinationPath));
    }
  }
  return copiedFiles;
}

int _copyDirectory(Directory sourceDir, Directory destinationDir) {
  var copiedFiles = 0;
  for (final entity in sourceDir.listSync(followLinks: false)) {
    final name = _entityName(entity.path);
    if (name.isEmpty || name.startsWith('.')) {
      continue;
    }

    final destinationPath =
        '${destinationDir.path}${Platform.pathSeparator}$name';
    if (entity is File) {
      if (_shouldCopyFile(entity)) {
        destinationDir.createSync(recursive: true);
        entity.copySync(destinationPath);
        copiedFiles++;
      }
    } else if (entity is Directory) {
      final nestedCopiedFiles = _copyDirectory(
        entity,
        Directory(destinationPath),
      );
      copiedFiles += nestedCopiedFiles;
    }
  }
  return copiedFiles;
}

bool _shouldCopyFile(File file) {
  final lowerPath = file.path.toLowerCase();
  return lowerPath.endsWith('.dll') ||
      lowerPath.endsWith('.so') ||
      lowerPath.endsWith('.dylib');
}

String _entityName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final segments = normalized.split('/');
  return segments.isEmpty ? '' : segments.last;
}
