import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';

const String _assetId = 'lib/sweeteditor.dart';

final Map<_NativeTarget, _NativeBinary> _nativeBinaries =
    <_NativeTarget, _NativeBinary>{
      _NativeTarget(OS.windows, Architecture.x64): _NativeBinary(
        relativePath: 'windows/x64/sweeteditor.dll',
        fileName: 'sweeteditor.dll',
      ),
      _NativeTarget(OS.linux, Architecture.x64): _NativeBinary(
        relativePath: 'linux/x86_64/libsweeteditor.so',
        fileName: 'libsweeteditor.so',
      ),
      _NativeTarget(OS.linux, Architecture.arm64): _NativeBinary(
        relativePath: 'linux/aarch64/libsweeteditor.so',
        fileName: 'libsweeteditor.so',
      ),
      _NativeTarget(OS.android, Architecture.arm64): _NativeBinary(
        relativePath: 'android/arm64-v8a/libsweeteditor.so',
        fileName: 'libsweeteditor.so',
      ),
      _NativeTarget(OS.android, Architecture.x64): _NativeBinary(
        relativePath: 'android/x86_64/libsweeteditor.so',
        fileName: 'libsweeteditor.so',
      ),
      _NativeTarget(OS.macOS, Architecture.arm64): _NativeBinary(
        relativePath: 'osx/arm64/libsweeteditor.dylib',
        fileName: 'libsweeteditor.dylib',
      ),
      _NativeTarget(OS.macOS, Architecture.x64): _NativeBinary(
        relativePath: 'osx/x86_64/libsweeteditor.dylib',
        fileName: 'libsweeteditor.dylib',
      ),
      _NativeTarget(
        OS.iOS,
        Architecture.arm64,
        iosSdk: IOSSdk.iPhoneOS,
      ): _NativeBinary(
        relativePath: 'ios/arm64/libsweeteditor.dylib',
        fileName: 'libsweeteditor.dylib',
      ),
      _NativeTarget(
        OS.iOS,
        Architecture.arm64,
        iosSdk: IOSSdk.iPhoneSimulator,
      ): _NativeBinary(
        relativePath: 'ios/simulator-arm64/libsweeteditor.dylib',
        fileName: 'libsweeteditor.dylib',
      ),
    };

void main(List<String> args) async {
  _initLogger();

  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final targetOS = input.config.code.targetOS;
    final targetArchitecture = input.config.code.targetArchitecture;
    final targetIOSSdk = targetOS == OS.iOS
        ? input.config.code.iOS.targetSdk
        : null;
    final nativeBinary =
        _nativeBinaries[_NativeTarget(
          targetOS,
          targetArchitecture,
          iosSdk: targetIOSSdk,
        )];
    if (nativeBinary == null) {
      final supportedTargets = _nativeBinaries.keys
          .map((target) => target.displayName)
          .join(', ');
      throw UnsupportedError(
        'Unsupported target: '
        '${_NativeTarget(targetOS, targetArchitecture, iosSdk: targetIOSSdk).displayName}.\n'
        'Supported targets: $supportedTargets',
      );
    }

    final sourceUri = input.packageRoot.resolve(
      'native/${nativeBinary.relativePath}',
    );
    final sourceFile = File(sourceUri.toFilePath());
    if (!sourceFile.existsSync()) {
      throw StateError(
        'Native library not found: ${sourceFile.path}\n'
        'packageRoot: ${input.packageRoot}\n'
        'requested: ${nativeBinary.relativePath}\n'
        'Run `dart tool/sync_native_binaries.dart` in the sweeteditor package '
        'directory to populate native binaries.',
      );
    }

    final outFile = input.outputDirectory.resolve(nativeBinary.fileName);
    await sourceFile.copy(outFile.toFilePath());
    output.dependencies.add(sourceUri);

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetId,
        linkMode: DynamicLoadingBundled(),
        file: outFile,
      ),
    );
  });
}

void _initLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    stdout.writeln('[${record.level.name}] ${record.message}');
  });
}

final class _NativeTarget {
  const _NativeTarget(this.os, this.architecture, {this.iosSdk});

  final OS os;
  final Architecture architecture;
  final IOSSdk? iosSdk;

  String get displayName {
    if (os == OS.iOS && iosSdk != null) {
      return '${os.name}/${architecture.name}/${iosSdk!.type}';
    }
    return '${os.name}/${architecture.name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _NativeTarget &&
          runtimeType == other.runtimeType &&
          os == other.os &&
          architecture == other.architecture &&
          iosSdk == other.iosSdk;

  @override
  int get hashCode => Object.hash(os, architecture, iosSdk);
}

final class _NativeBinary {
  const _NativeBinary({required this.relativePath, required this.fileName});

  final String relativePath;
  final String fileName;
}
