import '../core/editor_core.dart' as core;

/// A single item in the selection context menu.
class SelectionMenuItem {
  static const String actionCut = 'cut';
  static const String actionCopy = 'copy';
  static const String actionPaste = 'paste';
  static const String actionSelectAll = 'select_all';

  const SelectionMenuItem({
    required this.id,
    required this.label,
    this.enabled = true,
  });

  final String id;
  final String label;
  final bool enabled;
}

/// Provider interface for building selection menu items.
///
/// Implement this to customize the selection context menu.
/// Called each time the menu is about to show, so items
/// can be dynamic based on editor state.
abstract class SelectionMenuItemProvider {
  List<SelectionMenuItem> provideMenuItems(SelectionMenuContext context);
}

class SelectionMenuContext {
  const SelectionMenuContext({
    required this.hasSelection,
    required this.cursorPosition,
    this.selection,
    this.selectedText = '',
  });

  final bool hasSelection;
  final core.TextPosition cursorPosition;
  final core.TextRange? selection;
  final String selectedText;
}
