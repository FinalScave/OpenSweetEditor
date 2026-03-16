package com.qiplat.sweeteditor.completion;

import javax.swing.*;
import java.awt.*;

/**
 * Custom renderer interface, allowing host applications to replace the default completion candidate rendering.
 */
public interface CompletionCellRenderer {
    Component getCompletionCellRendererComponent(JList<?> list, CompletionItem item, int index, boolean isSelected);
}
