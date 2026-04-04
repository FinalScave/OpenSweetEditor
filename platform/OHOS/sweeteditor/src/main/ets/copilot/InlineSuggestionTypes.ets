/**
 * Immutable value object describing a single inline suggestion (phantom text + position).
 */
export class InlineSuggestion {
  readonly line: number;
  readonly column: number;
  readonly text: string;

  constructor(line: number, column: number, text: string) {
    this.line = line;
    this.column = column;
    this.text = text;
  }
}

/**
 * Callback for inline suggestion accept/dismiss events.
 */
export interface InlineSuggestionListener {
  onSuggestionAccepted(suggestion: InlineSuggestion): void;

  onSuggestionDismissed(suggestion: InlineSuggestion): void;
}

