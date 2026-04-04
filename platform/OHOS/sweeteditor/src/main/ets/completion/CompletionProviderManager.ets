import {
  CompletionContext,
  CompletionItem,
  CompletionProvider,
  CompletionReceiver,
  CompletionResult,
  CompletionTriggerKind
} from './CompletionTypes';
import { SweetEditor } from '../SweetEditor';
import hilog from '@ohos.hilog';

const DEBOUNCE_CHARACTER_MS = 50;
const DEBOUNCE_INVOKED_MS = 0;
const HILOG_DOMAIN = 0x3D12;
const TAG = 'CompletionMgr';

/**
 * Listener for completion item updates and dismissals.
 */
export interface CompletionUpdateListener {
  onCompletionItemsUpdated(items: CompletionItem[]): void;

  onCompletionDismissed(): void;
}

/**
 * Completion provider manager.
 * Handles provider registration/removal, debounce, context building,
 * dispatching requests, merging/sorting/filtering results, and driving panel updates.
 */
export class CompletionProviderManager {
  private providers: CompletionProvider[] = [];
  private activeReceivers: Map<CompletionProvider, ManagedReceiver> = new Map();
  private listener: CompletionUpdateListener | null = null;
  private generation: number = 0;
  private mergedItems: CompletionItem[] = [];
  private lastTriggerKind: CompletionTriggerKind = CompletionTriggerKind.INVOKED;
  private lastTriggerChar: string | null = null;
  private debounceTimerId: number = -1;
  private editor: SweetEditor;
  private tornDown: boolean = false;

  constructor(editor: SweetEditor) {
    this.editor = editor;
  }

  setListener(listener: CompletionUpdateListener | null): void {
    if (this.tornDown) {
      return;
    }
    this.listener = listener;
  }

  addProvider(provider: CompletionProvider): void {
    if (this.tornDown) {
      return;
    }
    if (!this.providers.includes(provider)) {
      this.providers.push(provider);
    }
  }

  removeProvider(provider: CompletionProvider): void {
    if (this.tornDown) {
      return;
    }
    const idx = this.providers.indexOf(provider);
    if (idx >= 0) {
      this.providers.splice(idx, 1);
    }
    const receiver = this.activeReceivers.get(provider);
    if (receiver) {
      receiver.cancel();
      this.activeReceivers.delete(provider);
    }
  }

  triggerCompletion(triggerKind: CompletionTriggerKind, triggerCharacter: string | null): void {
    if (this.tornDown) {
      return;
    }
    if (this.providers.length === 0) {
      return;
    }

    this.lastTriggerKind = triggerKind;
    this.lastTriggerChar = triggerCharacter;

    this.clearDebounce();
    const delay = triggerKind === CompletionTriggerKind.INVOKED ? DEBOUNCE_INVOKED_MS : DEBOUNCE_CHARACTER_MS;
    if (delay > 0) {
      this.debounceTimerId = setTimeout(() => {
        this.executeRefresh(this.lastTriggerKind, this.lastTriggerChar);
      }, delay);
    } else {
      this.executeRefresh(triggerKind, triggerCharacter);
    }
  }

  dismiss(): void {
    if (this.tornDown) {
      return;
    }
    this.clearDebounce();
    this.generation++;
    this.cancelAllReceivers();
    this.mergedItems = [];
    if (this.listener) {
      this.listener.onCompletionDismissed();
    }
  }

  isTriggerCharacter(ch: string): boolean {
    if (this.tornDown) {
      return false;
    }
    for (const provider of this.providers) {
      if (provider.isTriggerCharacter(ch)) {
        return true;
      }
    }
    return false;
  }

  showItems(items: CompletionItem[]): void {
    if (this.tornDown) {
      return;
    }
    this.clearDebounce();
    this.generation++;
    this.cancelAllReceivers();
    this.mergedItems = [...items];
    if (this.listener) {
      this.listener.onCompletionItemsUpdated([...this.mergedItems]);
    }
  }

  private executeRefresh(triggerKind: CompletionTriggerKind, triggerCharacter: string | null): void {
    if (this.tornDown) {
      return;
    }
    const currentGen = ++this.generation;
    this.cancelAllReceivers();
    this.mergedItems = [];

    const context = this.buildContext(triggerKind, triggerCharacter);
    if (!context) {
      this.dismiss();
      return;
    }

    for (const provider of this.providers) {
      const receiver = new ManagedReceiver(provider, currentGen, this);
      this.activeReceivers.set(provider, receiver);
      try {
        provider.provideCompletions(context, receiver);
      } catch (e) {
        hilog.error(HILOG_DOMAIN, TAG, 'provider failed: %{public}s', `${e}`);
      }
    }
  }

  private cancelAllReceivers(): void {
    this.activeReceivers.forEach(receiver => receiver.cancel());
    this.activeReceivers.clear();
  }

  private buildContext(triggerKind: CompletionTriggerKind,
    triggerCharacter: string | null): CompletionContext | null {
    const cursor = this.editor.getCursorPosition();
    if (!cursor) {
      return null;
    }
    const document = this.editor.getDocument();
    const lineText = document ? (document.getLineText(cursor.line) || '') : '';
    const wordRange = this.editor.getWordRangeAtCursor();
    return new CompletionContext(
      triggerKind, triggerCharacter, cursor, lineText, wordRange,
      this.editor.getLanguageConfiguration(), this.editor.getMetadata()
    );
  }

  /** @internal Called by ManagedReceiver when a provider submits results. */
  onProviderResult(provider: CompletionProvider, result: CompletionResult, receiverGeneration: number): void {
    if (this.tornDown) {
      return;
    }
    if (receiverGeneration !== this.generation) {
      return;
    }

    this.mergedItems.push(...result.items);
    this.mergedItems.sort((a, b) => {
      const sa = a.sortKey !== null ? a.sortKey : a.label;
      const sb = b.sortKey !== null ? b.sortKey : b.label;
      return sa.localeCompare(sb);
    });

    if (this.mergedItems.length === 0) {
      if (this.listener) {
        this.listener.onCompletionDismissed();
      }
    } else {
      if (this.listener) {
        this.listener.onCompletionItemsUpdated([...this.mergedItems]);
      }
    }
  }

  getGeneration(): number {
    return this.generation;
  }

  teardown(): void {
    if (this.tornDown) {
      return;
    }
    this.tornDown = true;
    this.clearDebounce();
    this.generation++;
    this.cancelAllReceivers();
    this.providers = [];
    this.mergedItems = [];
    this.listener = null;
    this.lastTriggerChar = null;
  }

  private clearDebounce(): void {
    if (this.debounceTimerId >= 0) {
      clearTimeout(this.debounceTimerId);
      this.debounceTimerId = -1;
    }
  }
}

class ManagedReceiver implements CompletionReceiver {
  private provider: CompletionProvider;
  private receiverGeneration: number;
  private manager: CompletionProviderManager;
  private cancelled: boolean = false;

  constructor(provider: CompletionProvider, receiverGeneration: number, manager: CompletionProviderManager) {
    this.provider = provider;
    this.receiverGeneration = receiverGeneration;
    this.manager = manager;
  }

  cancel(): void {
    this.cancelled = true;
  }

  accept(result: CompletionResult): boolean {
    if (this.cancelled || this.receiverGeneration !== this.manager.getGeneration()) {
      return false;
    }
    setTimeout(() => {
      if (this.cancelled || this.receiverGeneration !== this.manager.getGeneration()) {
        return;
      }
      this.manager.onProviderResult(this.provider, result, this.receiverGeneration);
    }, 0);
    return true;
  }

  isCancelled(): boolean {
    return this.cancelled || this.receiverGeneration !== this.manager.getGeneration();
  }
}

