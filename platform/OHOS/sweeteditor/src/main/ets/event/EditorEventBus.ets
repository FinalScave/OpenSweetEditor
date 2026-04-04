import { EditorEvent, EditorEventListener } from './EditorEvent';

/**
 * Internal editor event bus. Public APIs expose typed onXxx/offXxx methods,
 * while the bus keeps a single listener registry keyed by fixed event names.
 */
export class EditorEventBus {
  private listeners: Map<string, EditorEventListener<EditorEvent>[]> = new Map();

  on(type: string, listener: EditorEventListener<EditorEvent>): void {
    let list = this.listeners.get(type);
    if (!list) {
      list = [];
      this.listeners.set(type, list);
    }
    if (!list.includes(listener)) {
      list.push(listener);
    }
  }

  off(type: string, listener: EditorEventListener<EditorEvent>): void {
    const list = this.listeners.get(type);
    if (!list) {
      return;
    }
    const idx = list.indexOf(listener);
    if (idx >= 0) {
      list.splice(idx, 1);
    }
  }

  emit(type: string, event: EditorEvent): void {
    const list = this.listeners.get(type);
    if (!list || list.length === 0) {
      return;
    }
    for (const listener of list) {
      listener(event);
    }
  }

  clear(): void {
    this.listeners.clear();
  }
}
