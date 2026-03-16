package com.qiplat.sweeteditor.completion;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Completion item data model.
 * <p>Confirmation priority: textEdit → insertText → label.</p>
 */
public class CompletionItem {

    /**
     * Exact replacement edit (specifies replacement range + new text).
     */
    public static class TextEdit {
        @NonNull public final TextRange range;
        @NonNull public final String newText;

        public TextEdit(@NonNull TextRange range, @NonNull String newText) {
            this.range = range;
            this.newText = newText;
        }

        @NonNull @Override
        public String toString() {
            return "TextEdit{range=" + range + ", newText='" + newText + "'}";
        }
    }

    @NonNull private final String label;
    @Nullable private final String detail;
    private final int iconId;
    @Nullable private final String insertText;
    private final int insertTextFormat;
    @Nullable private final TextEdit textEdit;
    @Nullable private final String filterText;
    @Nullable private final String sortKey;
    private final int kind;

    private CompletionItem(Builder builder) {
        this.label = builder.label;
        this.detail = builder.detail;
        this.iconId = builder.iconId;
        this.insertText = builder.insertText;
        this.insertTextFormat = builder.insertTextFormat;
        this.textEdit = builder.textEdit;
        this.filterText = builder.filterText;
        this.sortKey = builder.sortKey;
        this.kind = builder.kind;
    }

    @NonNull public String getLabel() { return label; }
    @Nullable public String getDetail() { return detail; }
    public int getIconId() { return iconId; }
    @Nullable public String getInsertText() { return insertText; }
    /** Insert text format: {@link #INSERT_TEXT_FORMAT_PLAIN_TEXT} or {@link #INSERT_TEXT_FORMAT_SNIPPET} */
    public int getInsertTextFormat() { return insertTextFormat; }
    @Nullable public TextEdit getTextEdit() { return textEdit; }
    @Nullable public String getFilterText() { return filterText; }
    @Nullable public String getSortKey() { return sortKey; }
    public int getKind() { return kind; }

    /**
     * Get text used for filtering/matching (prefers filterText, falls back to label).
     */
    @NonNull
    public String getMatchText() {
        return filterText != null ? filterText : label;
    }

    // ==================== Kind Constants ====================

    public static final int KIND_KEYWORD = 0;
    public static final int KIND_FUNCTION = 1;
    public static final int KIND_VARIABLE = 2;
    public static final int KIND_CLASS = 3;
    public static final int KIND_INTERFACE = 4;
    public static final int KIND_MODULE = 5;
    public static final int KIND_PROPERTY = 6;
    public static final int KIND_SNIPPET = 7;
    public static final int KIND_TEXT = 8;

    // ==================== InsertTextFormat Constants ====================

    /** Plain text format (default) */
    public static final int INSERT_TEXT_FORMAT_PLAIN_TEXT = 1;
    /** VSCode Snippet format (supports $1, ${1:default}, $0, etc. placeholders) */
    public static final int INSERT_TEXT_FORMAT_SNIPPET = 2;

    // ==================== Builder ====================

    public static class Builder {
        @NonNull private final String label;
        @Nullable private String detail;
        private int iconId;
        @Nullable private String insertText;
        private int insertTextFormat = INSERT_TEXT_FORMAT_PLAIN_TEXT;
        @Nullable private TextEdit textEdit;
        @Nullable private String filterText;
        @Nullable private String sortKey;
        private int kind;

        public Builder(@NonNull String label) {
            this.label = label;
        }

        public Builder detail(@Nullable String detail) { this.detail = detail; return this; }
        public Builder iconId(int iconId) { this.iconId = iconId; return this; }
        public Builder insertText(@Nullable String insertText) { this.insertText = insertText; return this; }
        public Builder insertTextFormat(int insertTextFormat) { this.insertTextFormat = insertTextFormat; return this; }
        public Builder textEdit(@Nullable TextEdit textEdit) { this.textEdit = textEdit; return this; }
        public Builder filterText(@Nullable String filterText) { this.filterText = filterText; return this; }
        public Builder sortKey(@Nullable String sortKey) { this.sortKey = sortKey; return this; }
        public Builder kind(int kind) { this.kind = kind; return this; }

        @NonNull
        public CompletionItem build() {
            return new CompletionItem(this);
        }
    }

    @NonNull @Override
    public String toString() {
        return "CompletionItem{label='" + label + "', kind=" + kind + "}";
    }
}
