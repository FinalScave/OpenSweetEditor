package com.qiplat.sweeteditor.completion;

import javax.swing.*;
import java.awt.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Completion popup controller: JWindow(undecorated) + JList.
 * <p>Cursor-following positioning, keyboard navigation, Enter to confirm, Escape to close.</p>
 */
public class CompletionPopupController implements CompletionProviderManager.CompletionUpdateListener {

    public interface CompletionConfirmListener {
        void onCompletionConfirmed(CompletionItem item);
    }

    private static final int MAX_VISIBLE_ITEMS = 6;
    private static final int ITEM_HEIGHT = 24;
    private static final int POPUP_WIDTH = 300;
    private static final int GAP = 4;

    private final JComponent anchorComponent;
    private CompletionConfirmListener confirmListener;
    private CompletionCellRenderer cellRenderer;

    private JWindow popupWindow;
    private JList<CompletionItem> list;
    private DefaultListModel<CompletionItem> listModel;
    private final List<CompletionItem> items = new ArrayList<>();
    private int selectedIndex = 0;

    // Cached cursor coordinates (component-relative), used for popup positioning
    private float cachedCursorX;
    private float cachedCursorY;
    private float cachedCursorHeight;

    public CompletionPopupController(JComponent anchorComponent) {
        this.anchorComponent = anchorComponent;
    }

    public void setConfirmListener(CompletionConfirmListener listener) {
        this.confirmListener = listener;
    }

    public void setCellRenderer(CompletionCellRenderer renderer) {
        this.cellRenderer = renderer;
        if (list != null && renderer != null) {
            list.setCellRenderer((jList, value, index, isSelected, cellHasFocus) ->
                    renderer.getCompletionCellRendererComponent(jList, value, index, isSelected));
        }
    }

    public boolean isShowing() {
        return popupWindow != null && popupWindow.isVisible();
    }

    /**
     * Update cached cursor coordinates. Repositions popup immediately if showing.
     * Should be called every frame in paintComponent.
     */
    public void updateCursorPosition(float cursorX, float cursorY, float cursorHeight) {
        cachedCursorX = cursorX;
        cachedCursorY = cursorY;
        cachedCursorHeight = cursorHeight;
        if (isShowing()) {
            applyPosition();
        }
    }

    // ==================== CompletionUpdateListener ====================

    @Override
    public void onCompletionItemsUpdated(List<CompletionItem> newItems) {
        items.clear();
        items.addAll(newItems);
        selectedIndex = 0;
        ensurePopupInitialized();
        listModel.clear();
        for (CompletionItem item : items) {
            listModel.addElement(item);
        }
        if (items.isEmpty()) {
            dismiss();
        } else {
            list.setSelectedIndex(0);
            show();
        }
    }

    @Override
    public void onCompletionDismissed() {
        dismiss();
    }

    // ==================== Keyboard Navigation ====================

    /**
     * Handle mapped native keyCode.
     * Enter=13, Escape=27, Up=38, Down=40
     */
    public boolean handleKeyDown(int keyCode) {
        if (!isShowing() || items.isEmpty()) return false;

        if (keyCode == 13) { // Enter
            confirmSelected();
            return true;
        }
        if (keyCode == 27) { // Escape
            dismiss();
            return true;
        }
        if (keyCode == 38) { // Up
            moveSelection(-1);
            return true;
        }
        if (keyCode == 40) { // Down
            moveSelection(1);
            return true;
        }
        return false;
    }

    /**
     * Handle AWT/Swing VK key codes.
     */
    public boolean handleSwingKeyCode(int vkKeyCode) {
        if (!isShowing() || items.isEmpty()) return false;
        switch (vkKeyCode) {
            case java.awt.event.KeyEvent.VK_ENTER:
                confirmSelected();
                return true;
            case java.awt.event.KeyEvent.VK_ESCAPE:
                dismiss();
                return true;
            case java.awt.event.KeyEvent.VK_UP:
                moveSelection(-1);
                return true;
            case java.awt.event.KeyEvent.VK_DOWN:
                moveSelection(1);
                return true;
            default:
                return false;
        }
    }

    // ==================== Panel Positioning ====================

    public void updatePosition(float cursorX, float cursorY, float cursorHeight) {
        if (!isShowing()) return;
        cachedCursorX = cursorX;
        cachedCursorY = cursorY;
        cachedCursorHeight = cursorHeight;
        applyPosition();
    }

    public void dismiss() {
        if (popupWindow != null && popupWindow.isVisible()) {
            popupWindow.setVisible(false);
        }
    }

    // ==================== Internal Implementation ====================

    private void ensurePopupInitialized() {
        if (popupWindow != null) return;
        Window ancestor = SwingUtilities.getWindowAncestor(anchorComponent);
        popupWindow = new JWindow(ancestor);
        popupWindow.setType(Window.Type.POPUP);
        popupWindow.setFocusable(false);
        popupWindow.setFocusableWindowState(false);

        listModel = new DefaultListModel<>();
        list = new JList<>(listModel);
        list.setFixedCellHeight(ITEM_HEIGHT);
        list.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        list.setBackground(new Color(0xF5, 0xF5, 0xF5));
        list.setCellRenderer(new DefaultCompletionCellRenderer());

        // If custom renderer is already set, apply immediately
        if (cellRenderer != null) {
            list.setCellRenderer((jList, value, index, isSelected, cellHasFocus) ->
                    cellRenderer.getCompletionCellRendererComponent(jList, value, index, isSelected));
        }

        list.addMouseListener(new java.awt.event.MouseAdapter() {
            @Override
            public void mouseClicked(java.awt.event.MouseEvent e) {
                int index = list.locationToIndex(e.getPoint());
                if (index >= 0) {
                    selectedIndex = index;
                    confirmSelected();
                }
            }
        });

        JScrollPane scrollPane = new JScrollPane(list);
        scrollPane.setBorder(BorderFactory.createLineBorder(Color.GRAY));
        popupWindow.getContentPane().add(scrollPane);
    }

    private void show() {
        ensurePopupInitialized();
        int visibleCount = Math.min(items.size(), MAX_VISIBLE_ITEMS);
        int height = visibleCount * ITEM_HEIGHT + 2;
        popupWindow.setSize(POPUP_WIDTH, height);
        applyPosition();
        if (!popupWindow.isVisible()) {
            popupWindow.setVisible(true);
        }
    }

    private void applyPosition() {
        if (popupWindow == null || !anchorComponent.isShowing()) return;
        Point screenPos = anchorComponent.getLocationOnScreen();
        int x = screenPos.x + (int) cachedCursorX;
        int y = screenPos.y + (int) (cachedCursorY + cachedCursorHeight + GAP);

            // Flip above if insufficient space below
        int popupHeight = popupWindow.getHeight();
        Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
        if (y + popupHeight > screenSize.height) {
            y = screenPos.y + (int) cachedCursorY - popupHeight - GAP;
        }
            // Prevent right edge overflow
        if (x + POPUP_WIDTH > screenSize.width) {
            x = screenSize.width - POPUP_WIDTH;
        }
        if (x < 0) x = 0;

        popupWindow.setLocation(x, y);
    }

    private void moveSelection(int delta) {
        if (items.isEmpty()) return;
        int old = selectedIndex;
        selectedIndex = Math.max(0, Math.min(items.size() - 1, selectedIndex + delta));
        if (old != selectedIndex) {
            list.setSelectedIndex(selectedIndex);
            list.ensureIndexIsVisible(selectedIndex);
        }
    }

    private void confirmSelected() {
        if (selectedIndex >= 0 && selectedIndex < items.size()) {
            CompletionItem item = items.get(selectedIndex);
            dismiss();
            if (confirmListener != null) {
                confirmListener.onCompletionConfirmed(item);
            }
        }
    }

    // ==================== Default Renderer ====================

    private static class DefaultCompletionCellRenderer extends JPanel implements ListCellRenderer<CompletionItem> {
        private final JLabel labelView = new JLabel();
        private final JLabel detailView = new JLabel();

        DefaultCompletionCellRenderer() {
            setLayout(new BorderLayout(8, 0));
            setBorder(BorderFactory.createEmptyBorder(2, 6, 2, 6));
            labelView.setFont(new Font(Font.MONOSPACED, Font.PLAIN, 12));
            detailView.setFont(new Font(Font.SANS_SERIF, Font.PLAIN, 10));
            detailView.setForeground(Color.GRAY);
            add(labelView, BorderLayout.CENTER);
            add(detailView, BorderLayout.EAST);
        }

        @Override
        public Component getListCellRendererComponent(JList<? extends CompletionItem> jList,
                                                       CompletionItem value, int index,
                                                       boolean isSelected, boolean cellHasFocus) {
            labelView.setText(value.getLabel());
            detailView.setText(value.getDetail() != null ? value.getDetail() : "");
            if (isSelected) {
                setBackground(new Color(0xD0, 0xE8, 0xFF));
            } else {
                setBackground(new Color(0xF5, 0xF5, 0xF5));
            }
            setOpaque(true);
            return this;
        }
    }
}
