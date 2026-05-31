import 'package:flutter/widgets.dart';

import '../core/editor_core.dart' as core;
import '../editor_types.dart';

/// Completion item data model.
/// Confirmation priority: textEdit > insertText > label.
class CompletionItem {
  static const int kindKeyword = 0;
  static const int kindFunction = 1;
  static const int kindVariable = 2;
  static const int kindClass = 3;
  static const int kindInterface = 4;
  static const int kindModule = 5;
  static const int kindProperty = 6;
  static const int kindSnippet = 7;
  static const int kindText = 8;
  static const int insertTextFormatPlainText = 1;
  static const int insertTextFormatSnippet = 2;

  String label = '';
  String? detail;
  String? insertText;
  int insertTextFormat = insertTextFormatPlainText;
  CompletionTextEdit? textEdit;
  String? filterText;
  String? sortKey;
  int kind = kindText;

  String get matchText => filterText ?? label;
}

class CompletionTextEdit {
  const CompletionTextEdit({required this.range, required this.newText});

  final core.TextRange range;
  final String newText;
}

enum CompletionTriggerKind { invoked, character, retrigger }

class CompletionContext {
  const CompletionContext({
    required this.triggerKind,
    this.triggerCharacter,
    required this.cursorPosition,
    required this.lineText,
    required this.wordRange,
    this.languageConfiguration,
    this.editorMetadata,
  });

  final CompletionTriggerKind triggerKind;
  final String? triggerCharacter;
  final core.TextPosition cursorPosition;
  final String lineText;
  final core.TextRange wordRange;
  final LanguageConfiguration? languageConfiguration;
  final EditorMetadata? editorMetadata;
}

class CompletionResult {
  static final CompletionResult empty = CompletionResult(
    items: [],
    isIncomplete: false,
  );

  const CompletionResult({required this.items, required this.isIncomplete});

  final List<CompletionItem> items;
  final bool isIncomplete;
}

/// Async callback for providers to submit completion results.
abstract class CompletionReceiver {
  bool accept(CompletionResult result);
  bool isCancelled();
}

/// Completion provider interface.
/// Host applications implement this to provide completion candidates.
abstract class CompletionProvider {
  bool isTriggerCharacter(String ch);
  void provideCompletions(
    CompletionContext context,
    CompletionReceiver receiver,
  );
  void dispose();
}

typedef CompletionItemWidgetBuilder =
    Widget Function(
      BuildContext context,
      CompletionItem item,
      int index,
      bool selected,
    );
