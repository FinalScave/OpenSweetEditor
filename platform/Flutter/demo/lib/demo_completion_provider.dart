import 'package:sweeteditor/sweeteditor.dart';
import 'package:sweeteditor/core/editor_core.dart' as core;

class DemoCompletionProvider implements CompletionProvider {
  static const _triggerChars = {'.', ':'};

  @override
  bool isTriggerCharacter(String ch) => _triggerChars.contains(ch);

  @override
  void provideCompletions(
    CompletionContext context,
    CompletionReceiver receiver,
  ) {
    if (context.triggerKind == CompletionTriggerKind.character &&
        context.triggerCharacter == '.') {
      _provideMemberCompletions(receiver);
      return;
    }
    _provideKeywordCompletions(context, receiver);
  }

  @override
  void dispose() {}

  void _provideMemberCompletions(CompletionReceiver receiver) {
    receiver.accept(
      CompletionResult(
        isIncomplete: false,
        items: [
          CompletionItem()
            ..label = 'length'
            ..detail = 'size_t'
            ..kind = CompletionItem.kindProperty
            ..insertText = 'length()'
            ..sortKey = 'a_length',
          CompletionItem()
            ..label = 'push_back'
            ..detail = 'void push_back(T)'
            ..kind = CompletionItem.kindFunction
            ..insertText = 'push_back()'
            ..sortKey = 'b_push_back',
          CompletionItem()
            ..label = 'begin'
            ..detail = 'iterator'
            ..kind = CompletionItem.kindFunction
            ..insertText = 'begin()'
            ..sortKey = 'c_begin',
          CompletionItem()
            ..label = 'end'
            ..detail = 'iterator'
            ..kind = CompletionItem.kindFunction
            ..insertText = 'end()'
            ..sortKey = 'd_end',
          CompletionItem()
            ..label = 'size'
            ..detail = 'size_t'
            ..kind = CompletionItem.kindFunction
            ..insertText = 'size()'
            ..sortKey = 'e_size',
        ],
      ),
    );
  }

  void _provideKeywordCompletions(
    CompletionContext context,
    CompletionReceiver receiver,
  ) {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (receiver.isCancelled()) return;
      final items = [
        CompletionItem()
          ..label = 'std::string'
          ..detail = 'class'
          ..kind = CompletionItem.kindClass
          ..insertText = 'std::string'
          ..sortKey = 'a_string',
        CompletionItem()
          ..label = 'std::vector'
          ..detail = 'template class'
          ..kind = CompletionItem.kindClass
          ..insertText = 'std::vector<>'
          ..sortKey = 'b_vector',
        CompletionItem()
          ..label = 'std::cout'
          ..detail = 'ostream'
          ..kind = CompletionItem.kindVariable
          ..insertText = 'std::cout'
          ..sortKey = 'c_cout',
        CompletionItem()
          ..label = 'if'
          ..detail = 'snippet'
          ..kind = CompletionItem.kindSnippet
          ..insertText = 'if (\${1:condition}) {\n\t\$0\n}'
          ..insertTextFormat = CompletionItem.insertTextFormatSnippet
          ..sortKey = 'd_if',
        CompletionItem()
          ..label = 'for'
          ..detail = 'snippet'
          ..kind = CompletionItem.kindSnippet
          ..insertText =
              'for (int \${1:i} = 0; \${1:i} < \${2:n}; ++\${1:i}) {\n\t\$0\n}'
          ..insertTextFormat = CompletionItem.insertTextFormatSnippet
          ..sortKey = 'e_for',
        CompletionItem()
          ..label = 'class'
          ..detail = 'snippet'
          ..kind = CompletionItem.kindSnippet
          ..insertText =
              'class \${1:ClassName} {\npublic:\n\t\${1:ClassName}() {\$2}\n\t~\${1:ClassName}() {\$3}\n\$0\n};'
          ..insertTextFormat = CompletionItem.insertTextFormatSnippet
          ..sortKey = 'f_class',
        CompletionItem()
          ..label = 'return'
          ..detail = 'keyword'
          ..kind = CompletionItem.kindKeyword
          ..insertText = 'return '
          ..sortKey = 'g_return',
      ];
      final replacementRange = _identifierRange(context);
      if (replacementRange != null) {
        for (final item in items) {
          item.textEdit = core.TextEdit(
            range: replacementRange,
            newText: item.insertText ?? item.label,
          );
        }
      }
      receiver.accept(CompletionResult(isIncomplete: false, items: items));
    });
  }

  core.TextRange? _identifierRange(CompletionContext context) {
    final range = context.wordRange;
    final line = context.cursorPosition.line;
    final cursorColumn = context.cursorPosition.column;
    final startColumn = range.start.column;
    final endColumn = range.end.column;
    if (range.start.line != line ||
        range.end.line != line ||
        startColumn < 0 ||
        startColumn >= endColumn ||
        cursorColumn < startColumn ||
        cursorColumn > endColumn ||
        endColumn > context.lineText.length) {
      return null;
    }
    for (var column = startColumn; column < endColumn; column++) {
      if (!_isWordChar(context.lineText.codeUnitAt(column))) return null;
    }
    return range;
  }

  bool _isWordChar(int ch) =>
      (ch >= 0x61 && ch <= 0x7A) ||
      (ch >= 0x41 && ch <= 0x5A) ||
      (ch >= 0x30 && ch <= 0x39) ||
      ch == 0x5F ||
      ch > 0x7F;
}
