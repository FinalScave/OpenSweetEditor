import { EditorMetadata, LanguageConfiguration } from '../EditorTypes';

/**
 * Newline action result, describing the text to be inserted after pressing Enter.
 */
export class NewLineAction {
  readonly text: string;

  constructor(text: string) {
    this.text = text;
  }
}

/**
 * Newline context, provided to NewLineActionProvider for indent calculation.
 */
export class NewLineContext {
  readonly lineNumber: number;
  readonly column: number;
  readonly lineText: string;
  readonly languageConfiguration: LanguageConfiguration | null;
  readonly editorMetadata: EditorMetadata | null;

  constructor(lineNumber: number, column: number, lineText: string,
    languageConfiguration: LanguageConfiguration | null,
    editorMetadata: EditorMetadata | null) {
    this.lineNumber = lineNumber;
    this.column = column;
    this.lineText = lineText;
    this.languageConfiguration = languageConfiguration;
    this.editorMetadata = editorMetadata;
  }
}

/**
 * Smart newline provider interface.
 * Return null to indicate the current provider does not handle this,
 * pass to the next provider in the chain.
 * `provideNewLineAction(...)` runs on the editor input path on the UI thread /
 * UI event loop and must return synchronously.
 */
export interface NewLineActionProvider {
  provideNewLineAction(context: NewLineContext | null): NewLineAction | null;
}

