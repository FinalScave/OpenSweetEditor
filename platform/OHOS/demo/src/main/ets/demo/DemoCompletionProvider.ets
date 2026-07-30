import {
  CompletionContext,
  CompletionItem,
  CompletionProvider,
  CompletionReceiver,
  CompletionResult,
  CompletionTriggerKind,
  TextRange
} from '@qiplat/sweeteditor';

const ASYNC_DELAY_MS = 200;
const TRIGGER_CHARS: string[] = ['.', ':'];

export class DemoCompletionProvider implements CompletionProvider {
  isTriggerCharacter(ch: string): boolean {
    return TRIGGER_CHARS.includes(ch);
  }

  provideCompletions(context: CompletionContext, receiver: CompletionReceiver): void {
    if (context.triggerKind === CompletionTriggerKind.CHARACTER && context.triggerCharacter === '.') {
      receiver.accept(new CompletionResult(this.createMemberItems(), false));
      return;
    }

    setTimeout(() => {
      if (receiver.isCancelled()) {
        return;
      }
      const items = this.createGeneralItems();
      const replacementRange = this.getIdentifierRange(context);
      if (replacementRange !== null) {
        items.forEach((item: CompletionItem) => {
          item.textEdit = {
            range: replacementRange,
            newText: item.insertText !== null ? item.insertText : item.label
          };
        });
      }
      receiver.accept(new CompletionResult(items, false));
    }, ASYNC_DELAY_MS);
  }

  private createMemberItems(): CompletionItem[] {
    return [
      this.item('length', 'size_t', CompletionItem.KIND_PROPERTY, 'length()', 'a_length'),
      this.item('push_back', 'void push_back(T)', CompletionItem.KIND_FUNCTION, 'push_back()', 'b_push_back'),
      this.item('begin', 'iterator', CompletionItem.KIND_FUNCTION, 'begin()', 'c_begin'),
      this.item('end', 'iterator', CompletionItem.KIND_FUNCTION, 'end()', 'd_end'),
      this.item('size', 'size_t', CompletionItem.KIND_FUNCTION, 'size()', 'e_size')
    ];
  }

  private createGeneralItems(): CompletionItem[] {
    return [
      this.item('std::string', 'class', CompletionItem.KIND_CLASS, 'std::string', 'a_string'),
      this.item('std::vector', 'template class', CompletionItem.KIND_CLASS, 'std::vector<>', 'b_vector'),
      this.item('std::cout', 'ostream', CompletionItem.KIND_VARIABLE, 'std::cout', 'c_cout'),
      this.snippet(
        'if',
        'snippet',
        'if (${1:condition}) {\n\t$0\n}',
        'd_if'
      ),
      this.snippet(
        'for',
        'snippet',
        'for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i}) {\n\t$0\n}',
        'e_for'
      ),
      this.snippet(
        'class',
        'snippet - class definition',
        'class ${1:ClassName} {\npublic:\n\t${1:ClassName}() {$2}\n\t~${1:ClassName}() {$3}\n$0\n};',
        'f_class'
      ),
      this.item('return', 'keyword', CompletionItem.KIND_KEYWORD, 'return ', 'g_return')
    ];
  }

  private item(label: string, detail: string, kind: number, insertText: string, sortKey: string): CompletionItem {
    const item = new CompletionItem();
    item.label = label;
    item.detail = detail;
    item.kind = kind;
    item.insertText = insertText;
    item.sortKey = sortKey;
    return item;
  }

  private snippet(label: string, detail: string, insertText: string, sortKey: string): CompletionItem {
    const item = this.item(label, detail, CompletionItem.KIND_SNIPPET, insertText, sortKey);
    item.insertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
    return item;
  }

  private getIdentifierRange(context: CompletionContext): TextRange | null {
    const range = context.wordRange;
    const line = context.cursorPosition.line;
    const cursorColumn = context.cursorPosition.column;
    const startColumn = range.start.column;
    const endColumn = range.end.column;
    if (range.start.line !== line || range.end.line !== line ||
      startColumn < 0 || startColumn >= endColumn ||
      cursorColumn < startColumn || cursorColumn > endColumn ||
      endColumn > context.lineText.length) {
      return null;
    }
    for (let column = startColumn; column < endColumn; column++) {
      if (!this.isWordChar(context.lineText.charCodeAt(column))) {
        return null;
      }
    }
    return range;
  }

  private isWordChar(ch: number): boolean {
    return (ch >= 0x61 && ch <= 0x7A) ||
      (ch >= 0x41 && ch <= 0x5A) ||
      (ch >= 0x30 && ch <= 0x39) ||
      ch === 0x5F ||
      ch > 0x7F;
  }
}
