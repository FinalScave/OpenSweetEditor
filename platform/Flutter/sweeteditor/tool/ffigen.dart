import 'dart:io';
import 'package:ffigen/ffigen.dart';

const _assetId = 'package:sweeteditor/lib/sweeteditor.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');
  final outputFile = File(
    packageRoot
        .resolve('lib/sweeteditor_bindings_generated.dart')
        .toFilePath(),
  );

  FfiGenerator(
    output: Output(dartFile: outputFile.uri),
    functions: Functions(
      include: (Declaration declaration) {
        final name = declaration.originalName;
        return name.startsWith('create_') ||
            name.startsWith('free_') ||
            name.startsWith('get_document') ||
            name.startsWith('get_layout') ||
            name.startsWith('set_editor') ||
            name.startsWith('editor_') ||
            name.startsWith('handle_editor') ||
            name.startsWith('build_editor') ||
            name == 'create_editor' ||
            name == 'free_editor' ||
            name == 'free_binary_data' ||
            name == 'free_u16_string';
      },
    ),
    structs: Structs(
      include: (Declaration declaration) =>
          declaration.originalName == 'text_measurer_t',
    ),
    typedefs: Typedefs(
      include: (Declaration declaration) =>
          declaration.originalName == 'text_measurer_t',
    ),
    headers: Headers(
      entryPoints: [
        packageRoot.resolve('../../../include/sweeteditor/c_api.h'),
      ],
      compilerOptions: [
        '-I${packageRoot.resolve('../../../include').toFilePath()}',
        '-DSWEETEDITOR_EXPORT',
      ],
    ),
  ).generate();

  _patchGeneratedBindings(outputFile);
}

void _patchGeneratedBindings(File file) {
  var content = file.readAsStringSync();
  final assetIdDeclaration = "const _sweeteditorAssetId = '$_assetId';";

  if (!content.contains(assetIdDeclaration)) {
    content = content.replaceFirst(
      "import 'dart:ffi' as ffi;\n",
      "import 'dart:ffi' as ffi;\n\n$assetIdDeclaration\n",
    );
  }

  content = content.replaceAllMapped(
    RegExp(r'@ffi\.Native<([\s\S]*?)>\(([\s\S]*?)\)', dotAll: true),
    (match) {
      final generic = match.group(1)!;
      final args = match.group(2)!;
      if (args.contains('assetId:')) {
        return match.group(0)!;
      }
      if (args.trim().isEmpty) {
        return '@ffi.Native<$generic>(assetId: _sweeteditorAssetId)';
      }
      if (args.startsWith('\r\n') || args.startsWith('\n')) {
        return '@ffi.Native<$generic>(assetId: _sweeteditorAssetId,$args)';
      }
      return '@ffi.Native<$generic>(assetId: _sweeteditorAssetId, $args)';
    },
  );

  file.writeAsStringSync(content);
}
