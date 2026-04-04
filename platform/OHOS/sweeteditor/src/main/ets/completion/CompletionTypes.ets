import { TextPosition, TextRange } from '../core/CoreFoundation';
import { EditorMetadata, LanguageConfiguration } from '../EditorTypes';

/**
 * Completion item data model.
 * Confirmation priority: textEdit > insertText > label.
 */
export class CompletionItem {
  static readonly KIND_KEYWORD = 0;
  static readonly KIND_FUNCTION = 1;
  static readonly KIND_VARIABLE = 2;
  static readonly KIND_CLASS = 3;
  static readonly KIND_INTERFACE = 4;
  static readonly KIND_MODULE = 5;
  static readonly KIND_PROPERTY = 6;
  static readonly KIND_SNIPPET = 7;
  static readonly KIND_TEXT = 8;
  static readonly INSERT_TEXT_FORMAT_PLAIN_TEXT = 1;
  static readonly INSERT_TEXT_FORMAT_SNIPPET = 2;
  label: string = '';
  detail: string | null = null;
  insertText: string | null = null;
  insertTextFormat: number = CompletionItem.INSERT_TEXT_FORMAT_PLAIN_TEXT;
  textEdit: CompletionTextEdit | null = null;
  filterText: string | null = null;
  sortKey: string | null = null;
  kind: number = CompletionItem.KIND_TEXT;

  getMatchText(): string {
    return this.filterText !== null ? this.filterText : this.label;
  }
}

export class CompletionTextEdit {
  readonly range: TextRange;
  readonly newText: string;

  constructor(range: TextRange, newText: string) {
    this.range = range;
    this.newText = newText;
  }
}

export enum CompletionTriggerKind {
  INVOKED = 'invoked',
  CHARACTER = 'character',
  RETRIGGER = 'retrigger'
}

export class CompletionContext {
  readonly triggerKind: CompletionTriggerKind;
  readonly triggerCharacter: string | null;
  readonly cursorPosition: TextPosition;
  readonly lineText: string;
  readonly wordRange: TextRange;
  readonly languageConfiguration: LanguageConfiguration | null;
  readonly editorMetadata: EditorMetadata | null;

  constructor(triggerKind: CompletionTriggerKind, triggerCharacter: string | null,
    cursorPosition: TextPosition, lineText: string, wordRange: TextRange,
    languageConfiguration: LanguageConfiguration | null,
    editorMetadata: EditorMetadata | null) {
    this.triggerKind = triggerKind;
    this.triggerCharacter = triggerCharacter;
    this.cursorPosition = cursorPosition;
    this.lineText = lineText;
    this.wordRange = wordRange;
    this.languageConfiguration = languageConfiguration;
    this.editorMetadata = editorMetadata;
  }
}

export class CompletionResult {
  static readonly EMPTY = new CompletionResult([], false);
  readonly items: CompletionItem[];
  readonly isIncomplete: boolean;

  constructor(items: CompletionItem[], isIncomplete: boolean) {
    this.items = items;
    this.isIncomplete = isIncomplete;
  }
}

/**
 * Async callback for providers to submit completion results.
 * `accept(...)` may be called synchronously or asynchronously, including from a
 * background thread. The manager will switch back to the UI event loop before
 * applying the result to editor state or updating host-visible UI.
 */
export interface CompletionReceiver {
  accept(result: CompletionResult): boolean;

  isCancelled(): boolean;
}

/**
 * Completion provider interface.
 * Host applications implement this to provide completion candidates.
 * `provideCompletions(...)` is invoked from the editor's UI thread / UI event loop.
 * Providers may compute results asynchronously and call the receiver later.
 */
export interface CompletionProvider {
  isTriggerCharacter(ch: string): boolean;

  provideCompletions(context: CompletionContext, receiver: CompletionReceiver): void;
}

/**
 * Custom completion item view builder interface.
 * Host applications implement this to customize completion item appearance.
 * Returns an ArkUI @Builder function reference for rendering each item.
 */
export interface CompletionItemViewBuilder {
  buildItemView(item: CompletionItem, isSelected: boolean): void;
}

