package com.qiplat.sweeteditor.completion;

import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;

/**
 * Custom completion item layout extension interface.
 * <p>Host applications implement this interface to customize the appearance of completion items.</p>
 */
public interface CompletionItemViewFactory {
    /**
     * Create item view.
     * @param parent parent container (RecyclerView)
     * @return item view
     */
    @NonNull
    View createItemView(@NonNull ViewGroup parent);

    /**
     * Bind item data to view.
     * @param view view returned by createItemView
     * @param item item data
     * @param isSelected whether this item is currently selected
     */
    void bindItemView(@NonNull View view, @NonNull CompletionItem item, boolean isSelected);
}
