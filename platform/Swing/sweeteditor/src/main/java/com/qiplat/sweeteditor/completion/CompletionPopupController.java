package com.qiplat.sweeteditor.completion;

import com.qiplat.sweeteditor.EditorTheme;

import javax.swing.*;
import java.awt.*;
import java.awt.geom.RoundRectangle2D;
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
    private static final int ITEM_HEIGHT = 50;
    private static final int POPUP_WIDTH = 600;
    private static final int GAP = 4;

    private Color panelBg;
    private Color panelBorder;
    private Color selectedBg;
    private Color labelColor;
    private Color detailColor;

    private final JComponent anchorComponent;
    private CompletionConfirmListener confirmListener;
    private CompletionCellRenderer cellRenderer;

    private JWindow popupWindow;
    private JList<CompletionItem> list;
    private DefaultListModel<CompletionItem> listModel;
    private final List<CompletionItem> items = new ArrayList<>();
    private int selectedIndex = 0;

    private float cachedCursorX;
    private float cachedCursorY;
    private float cachedCursorHeight;

    public CompletionPopupController(JComponent anchorComponent, EditorTheme theme) {
        this.anchorComponent = anchorComponent;
        applyThemeColors(theme);
    }

    public void applyTheme(EditorTheme theme) {
        applyThemeColors(theme);
        if (popupWindow != null) {
            popupWindow.getContentPane().setBackground(panelBg);
            if (list != null) {
                list.setBackground(panelBg);
                if (list.getCellRenderer() instanceof DefaultCompletionCellRenderer dcr) {
                    dcr.updateColors(panelBg, selectedBg, labelColor, detailColor);
                }
                list.repaint();
            }
        }
    }

    private void applyThemeColors(EditorTheme theme) {
        panelBg = theme.completionBgColor;
        panelBorder = theme.completionBorderColor;
        selectedBg = theme.completionSelectedBgColor;
        labelColor = theme.completionLabelColor;
        detailColor = theme.completionDetailColor;
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

    /**
     * Handle mapped native keyCode.
     * Enter=13, Escape=27, Up=38, Down=40
     */
    public boolean handleKeyDown(int keyCode) {
        if (!isShowing() || items.isEmpty()) return false;

        if (keyCode == 13) {
            confirmSelected();
            return true;
        }
        if (keyCode == 27) {
            dismiss();
            return true;
        }
        if (keyCode == 38) {
            moveSelection(-1);
            return true;
        }
        if (keyCode == 40) {
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

    private void ensurePopupInitialized() {
        if (popupWindow != null) return;
        Window ancestor = SwingUtilities.getWindowAncestor(anchorComponent);
        popupWindow = new JWindow(ancestor);
        popupWindow.setType(Window.Type.NORMAL);
        popupWindow.setFocusable(false);
        popupWindow.setFocusableWindowState(false);

        listModel = new DefaultListModel<>();
        list = new JList<>(listModel);
        list.setFixedCellHeight(ITEM_HEIGHT);
        list.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        list.setBackground(panelBg);
        list.setCellRenderer(new DefaultCompletionCellRenderer(panelBg, selectedBg, labelColor, detailColor));

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
        scrollPane.setBorder(BorderFactory.createLineBorder(panelBorder));
        scrollPane.getViewport().setBackground(panelBg);
        scrollPane.setBackground(panelBg);
        popupWindow.getContentPane().setBackground(panelBg);
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

        int popupHeight = popupWindow.getHeight();
        Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
        if (y + popupHeight > screenSize.height) {
            y = screenPos.y + (int) cachedCursorY - popupHeight - GAP;
        }
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

    private static Color kindColor(int kind) {
        switch (kind) {
            case CompletionItem.KIND_KEYWORD:   return new Color(0xC6, 0x78, 0xDD);
            case CompletionItem.KIND_FUNCTION:  return new Color(0x61, 0xAF, 0xEF);
            case CompletionItem.KIND_VARIABLE:  return new Color(0xE5, 0xC0, 0x7B);
            case CompletionItem.KIND_CLASS:     return new Color(0xE0, 0x6C, 0x75);
            case CompletionItem.KIND_INTERFACE: return new Color(0x56, 0xB6, 0xC2);
            case CompletionItem.KIND_MODULE:    return new Color(0xD1, 0x9A, 0x66);
            case CompletionItem.KIND_PROPERTY:  return new Color(0x98, 0xC3, 0x79);
            case CompletionItem.KIND_SNIPPET:   return new Color(0xBE, 0x50, 0x46);
            default:                            return new Color(0x7A, 0x84, 0x94);
        }
    }

    private static String kindLetter(int kind) {
        switch (kind) {
            case CompletionItem.KIND_KEYWORD:   return "K";
            case CompletionItem.KIND_FUNCTION:  return "F";
            case CompletionItem.KIND_VARIABLE:  return "V";
            case CompletionItem.KIND_CLASS:     return "C";
            case CompletionItem.KIND_INTERFACE: return "I";
            case CompletionItem.KIND_MODULE:    return "M";
            case CompletionItem.KIND_PROPERTY:  return "P";
            case CompletionItem.KIND_SNIPPET:   return "S";
            default:                            return "T";
        }
    }

    private static class DefaultCompletionCellRenderer extends JPanel implements ListCellRenderer<CompletionItem> {
        private CompletionItem currentItem;
        private boolean currentSelected;

        private static final Font LABEL_FONT = new Font(Font.MONOSPACED, Font.PLAIN, 26);
        private static final Font DETAIL_FONT = new Font(Font.SANS_SERIF, Font.PLAIN, 24);
        private static final Font BADGE_FONT = new Font(Font.SANS_SERIF, Font.BOLD, 24);
        private static final int BADGE_SIZE = 36;
        private static final int BADGE_ARC = 6;

        private Color bgColor;
        private Color selColor;
        private Color lblColor;
        private Color dtlColor;

        DefaultCompletionCellRenderer(Color bgColor, Color selColor, Color lblColor, Color dtlColor) {
            setOpaque(true);
            this.bgColor = bgColor;
            this.selColor = selColor;
            this.lblColor = lblColor;
            this.dtlColor = dtlColor;
        }

        void updateColors(Color bgColor, Color selColor, Color lblColor, Color dtlColor) {
            this.bgColor = bgColor;
            this.selColor = selColor;
            this.lblColor = lblColor;
            this.dtlColor = dtlColor;
        }

        @Override
        public Component getListCellRendererComponent(JList<? extends CompletionItem> jList,
                                                       CompletionItem value, int index,
                                                       boolean isSelected, boolean cellHasFocus) {
            currentItem = value;
            currentSelected = isSelected;
            setBackground(bgColor);
            return this;
        }

        @Override
        protected void paintComponent(Graphics g) {
            super.paintComponent(g);
            if (currentItem == null) return;
            Graphics2D g2 = (Graphics2D) g.create();
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_LCD_HRGB);

            int w = getWidth(), h = getHeight();
            int insetX = 4, insetY = 2;

            if (currentSelected) {
                g2.setColor(selColor);
                g2.fill(new RoundRectangle2D.Float(insetX, insetY, w - insetX * 2, h - insetY * 2, 8, 8));
            }

            int x = 8;
            int centerY = h / 2;

            Color badgeColor = kindColor(currentItem.kind);
            String letter = kindLetter(currentItem.kind);
            int badgeY = centerY - BADGE_SIZE / 2;
            g2.setColor(badgeColor);
            g2.fill(new RoundRectangle2D.Float(x, badgeY, BADGE_SIZE, BADGE_SIZE, BADGE_ARC, BADGE_ARC));
            g2.setFont(BADGE_FONT);
            FontMetrics bfm = g2.getFontMetrics();
            int lx = x + (BADGE_SIZE - bfm.stringWidth(letter)) / 2;
            int ly = badgeY + (BADGE_SIZE - bfm.getHeight()) / 2 + bfm.getAscent();
            g2.setColor(Color.WHITE);
            g2.drawString(letter, lx, ly);
            x += BADGE_SIZE + 8;

            g2.setFont(LABEL_FONT);
            FontMetrics lfm = g2.getFontMetrics();
            g2.setColor(lblColor);
            String label = currentItem.label;
            int labelMaxWidth = w - x - 8;
            String detail = currentItem.detail;
            if (detail != null && !detail.isEmpty()) {
                FontMetrics dfm = g2.getFontMetrics(DETAIL_FONT);
                int detailWidth = dfm.stringWidth(detail) + 12;
                labelMaxWidth = w - x - detailWidth - 8;
            }
            label = truncateText(lfm, label, labelMaxWidth);
            g2.drawString(label, x, centerY - lfm.getHeight() / 2 + lfm.getAscent());

            if (detail != null && !detail.isEmpty()) {
                g2.setFont(DETAIL_FONT);
                FontMetrics dfm = g2.getFontMetrics();
                g2.setColor(dtlColor);
                int detailX = w - dfm.stringWidth(detail) - 8;
                g2.drawString(detail, detailX, centerY - dfm.getHeight() / 2 + dfm.getAscent());
            }

            g2.dispose();
        }

        private static String truncateText(FontMetrics fm, String text, int maxWidth) {
            if (fm.stringWidth(text) <= maxWidth) return text;
            String ellipsis = "...";
            int ellipsisW = fm.stringWidth(ellipsis);
            for (int i = text.length() - 1; i > 0; i--) {
                if (fm.stringWidth(text.substring(0, i)) + ellipsisW <= maxWidth) {
                    return text.substring(0, i) + ellipsis;
                }
            }
            return ellipsis;
        }
    }
}
