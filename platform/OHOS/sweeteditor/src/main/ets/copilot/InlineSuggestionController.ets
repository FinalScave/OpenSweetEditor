import { InlineSuggestion, InlineSuggestionListener } from './InlineSuggestionTypes';
import { PhantomText } from '../core/CoreAdornments';
import { TextPosition } from '../core/CoreFoundation';
import { CursorChangedEvent, EditorEvent, EditorEventListener, ScrollChangedEvent, TextChangedEvent } from '../event/EditorEvent';
import { EditorEventBus } from '../event/EditorEventBus';
import { SweetEditor } from '../SweetEditor';

/**
 * Callback for inline suggestion action bar Accept/Dismiss interaction.
 */
export interface InlineSuggestionActionCallback {
  onAcceptClicked(): void;

  onDismissClicked(): void;
}

/**
 * Manages inline suggestion lifecycle: phantom text injection, event subscriptions,
 * Tab/Esc key interception, and action bar state.
 */
export class InlineSuggestionController implements InlineSuggestionActionCallback {
  private editor: SweetEditor;
  private eventBus: EditorEventBus;
  private currentSuggestion: InlineSuggestion | null = null;
  private listener: InlineSuggestionListener | null = null;
  private showing: boolean = false;
  private suppressAutoDismiss: boolean = false;
  private cachedCursorX: number = 0;
  private cachedCursorY: number = 0;
  private cachedCursorHeight: number = 0;
  private onShowCallback: ((x: number, y: number, height: number) => void) | null = null;
  private onUpdatePositionCallback: ((x: number, y: number, height: number) => void) | null = null;
  private onDismissCallback: (() => void) | null = null;
  private textWatcher: EditorEventListener<TextChangedEvent> = () => this.autoDismiss();
  private cursorWatcher: EditorEventListener<CursorChangedEvent> = () => this.autoDismiss();
  private scrollWatcher: EditorEventListener<ScrollChangedEvent> = () => {
    if (this.showing && this.onUpdatePositionCallback) {
      this.onUpdatePositionCallback(this.cachedCursorX, this.cachedCursorY, this.cachedCursorHeight);
    }
  };

  constructor(editor: SweetEditor, eventBus: EditorEventBus) {
    this.editor = editor;
    this.eventBus = eventBus;
  }

  setListener(listener: InlineSuggestionListener | null): void {
    this.listener = listener;
  }

  setOnShowCallback(cb: ((x: number, y: number, height: number) => void) | null): void {
    this.onShowCallback = cb;
  }

  setOnUpdatePositionCallback(cb: ((x: number, y: number, height: number) => void) | null): void {
    this.onUpdatePositionCallback = cb;
  }

  setOnDismissCallback(cb: (() => void) | null): void {
    this.onDismissCallback = cb;
  }

  isShowing(): boolean {
    return this.showing;
  }

  show(suggestion: InlineSuggestion): void {
    if (this.showing) {
      this.clearQuietly();
    }
    this.currentSuggestion = suggestion;
    this.injectPhantomText(suggestion);

    const rect = this.editor.getPositionRect(suggestion.line, suggestion.column);
    this.cachedCursorX = rect.x;
    this.cachedCursorY = rect.y;
    this.cachedCursorHeight = rect.height;

    this.showing = true;
    if (this.onShowCallback) {
      this.onShowCallback(this.cachedCursorX, this.cachedCursorY, this.cachedCursorHeight);
    }
    this.subscribeEvents();
    this.editor.flush();
  }

  accept(): void {
    if (!this.currentSuggestion) {
      return;
    }
    const suggestion = this.currentSuggestion;

    this.withSuppressedAutoDismiss(() => {
      this.unsubscribeEvents();
      this.editor.clearPhantomTexts();
      const pos: TextPosition = { line: suggestion.line, column: suggestion.column };
      this.editor.replaceText({ start: pos, end: pos }, suggestion.text);
      this.showing = false;
      if (this.onDismissCallback) {
        this.onDismissCallback();
      }
      this.currentSuggestion = null;
    });

    if (this.listener) {
      this.listener.onSuggestionAccepted(suggestion);
    }
  }

  dismiss(): void {
    if (!this.currentSuggestion) {
      return;
    }
    const suggestion = this.currentSuggestion;

    this.withSuppressedAutoDismiss(() => {
      this.unsubscribeEvents();
      this.editor.clearPhantomTexts();
      this.editor.flush();
      this.showing = false;
      if (this.onDismissCallback) {
        this.onDismissCallback();
      }
      this.currentSuggestion = null;
    });

    if (this.listener) {
      this.listener.onSuggestionDismissed(suggestion);
    }
  }

  /**
   * Handle key codes. Returns true if consumed.
   * Tab �?accept, Escape �?dismiss.
   */
  handleKeyCode(keyCode: number): boolean {
    if (!this.showing) {
      return false;
    }
    if (keyCode === 61) { // Tab
      this.accept();
      return true;
    }
    if (keyCode === 111) { // Escape
      this.dismiss();
      return true;
    }
    return false;
  }

  updatePosition(cursorX: number, cursorY: number, cursorHeight: number): void {
    this.cachedCursorX = cursorX;
    this.cachedCursorY = cursorY;
    this.cachedCursorHeight = cursorHeight;
    if (this.showing && this.onUpdatePositionCallback) {
      this.onUpdatePositionCallback(cursorX, cursorY, cursorHeight);
    }
  }

  onAcceptClicked(): void {
    this.accept();
  }

  onDismissClicked(): void {
    this.dismiss();
  }

  private autoDismiss(): void {
    if (this.suppressAutoDismiss) {
      return;
    }
    this.dismiss();
  }

  private clearQuietly(): void {
    this.withSuppressedAutoDismiss(() => {
      this.unsubscribeEvents();
      this.editor.clearPhantomTexts();
      this.showing = false;
      if (this.onDismissCallback) {
        this.onDismissCallback();
      }
      this.currentSuggestion = null;
    });
  }

  private withSuppressedAutoDismiss(action: () => void): void {
    this.suppressAutoDismiss = true;
    try {
      action();
    } finally {
      this.suppressAutoDismiss = false;
    }
  }

  private injectPhantomText(suggestion: InlineSuggestion): void {
    const phantoms = new Map<number, PhantomText[]>();
    phantoms.set(suggestion.line, [{ column: suggestion.column, text: suggestion.text } as PhantomText]);
    this.editor.clearPhantomTexts();
    this.editor.setBatchLinePhantomTexts(phantoms);
  }

  private subscribeEvents(): void {
    this.eventBus.on('textChanged', this.textWatcher as EditorEventListener<EditorEvent>);
    this.eventBus.on('cursorChanged', this.cursorWatcher as EditorEventListener<EditorEvent>);
    this.eventBus.on('scrollChanged', this.scrollWatcher as EditorEventListener<EditorEvent>);
  }

  private unsubscribeEvents(): void {
    this.eventBus.off('textChanged', this.textWatcher as EditorEventListener<EditorEvent>);
    this.eventBus.off('cursorChanged', this.cursorWatcher as EditorEventListener<EditorEvent>);
    this.eventBus.off('scrollChanged', this.scrollWatcher as EditorEventListener<EditorEvent>);
  }
}

