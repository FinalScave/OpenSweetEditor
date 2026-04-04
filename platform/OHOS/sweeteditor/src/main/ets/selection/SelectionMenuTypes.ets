/**
 * Data class representing a single item in the selection context menu.
 */
export class SelectionMenuItem {
  static readonly ACTION_CUT = 'cut';
  static readonly ACTION_COPY = 'copy';
  static readonly ACTION_PASTE = 'paste';
  static readonly ACTION_SELECT_ALL = 'select_all';
  readonly id: string;
  readonly label: string;
  readonly enabled: boolean;

  constructor(id: string, label: string, enabled: boolean = true) {
    this.id = id;
    this.label = label;
    this.enabled = enabled;
  }
}

export interface SelectionMenuState {
  visible: boolean;
  items: SelectionMenuItem[];
  x: number;
  y: number;
}

/**
 * Provider interface for building selection menu items.
 * Implement this to customize the selection context menu.
 */
export interface SelectionMenuItemProvider {
  provideMenuItems(): SelectionMenuItem[];
}

