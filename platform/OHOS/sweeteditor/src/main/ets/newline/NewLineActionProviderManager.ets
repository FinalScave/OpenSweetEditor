import { EditorMetadata, LanguageConfiguration } from '../EditorTypes';
import { NewLineAction, NewLineActionProvider, NewLineContext } from './NewLineTypes';

/**
 * Chain-based manager for newline providers.
 * Iterates until the first non-null provider takes effect.
 */
export class NewLineActionProviderManager {
  private providers: NewLineActionProvider[] = [];
  private tornDown: boolean = false;

  addProvider(provider: NewLineActionProvider): void {
    if (this.tornDown) {
      return;
    }
    this.providers.push(provider);
  }

  removeProvider(provider: NewLineActionProvider): void {
    if (this.tornDown) {
      return;
    }
    const idx = this.providers.indexOf(provider);
    if (idx >= 0) {
      this.providers.splice(idx, 1);
    }
  }

  provideNewLineAction(lineNumber: number, column: number, lineText: string,
    languageConfiguration: LanguageConfiguration | null,
    editorMetadata: EditorMetadata | null): NewLineAction | null {
    if (this.tornDown) {
      return null;
    }
    const context = new NewLineContext(lineNumber, column, lineText,
      languageConfiguration, editorMetadata);
    for (const provider of this.providers) {
      const action = provider.provideNewLineAction(context);
      if (action !== null) {
        return action;
      }
    }
    return null;
  }

  teardown(): void {
    if (this.tornDown) {
      return;
    }
    this.tornDown = true;
    this.providers = [];
  }
}

