package com.qiplat.sweeteditor.completion;

import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Completion item data model.
 * <p>Confirmation priority: textEdit → insertText → label.</p>
 */
public class CompletionItem {

    public static class TextEdit {
        public final TextRange range;
        public final String newText;

        public TextEdit(TextRange range, String newText) {
            this.range = range;
            this.newText = newText;
        }
    }

    private final String label;
    private final String detail;
    private final int iconId;
    private final String insertText;
    private final int insertTextFormat;
    private final TextEdit textEdit;
    private final String filterText;
    private final String sortKey;
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

    public String getLabel() { return label; }
    public String getDetail() { return detail; }
    public int getIconId() { return iconId; }
    public String getInsertText() { return insertText; }
    /** Insert text format: {@link #INSERT_TEXT_FORMAT_PLAIN_TEXT} or {@link #INSERT_TEXT_FORMAT_SNIPPET} */
    public int getInsertTextFormat() { return insertTextFormat; }
    public TextEdit getTextEdit() { return textEdit; }
    public String getFilterText() { return filterText; }
    public String getSortKey() { return sortKey; }
    public int getKind() { return kind; }

    public String getMatchText() {
        return filterText != null ? filterText : label;
    }

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

    public static class Builder {
        private final String label;
        private String detail;
        private int iconId;
        private String insertText;
        private int insertTextFormat = INSERT_TEXT_FORMAT_PLAIN_TEXT;
        private TextEdit textEdit;
        private String filterText;
        private String sortKey;
        private int kind;

        public Builder(String label) { this.label = label; }
        public Builder detail(String detail) { this.detail = detail; return this; }
        public Builder iconId(int iconId) { this.iconId = iconId; return this; }
        public Builder insertText(String insertText) { this.insertText = insertText; return this; }
        public Builder insertTextFormat(int insertTextFormat) { this.insertTextFormat = insertTextFormat; return this; }
        public Builder textEdit(TextEdit textEdit) { this.textEdit = textEdit; return this; }
        public Builder filterText(String filterText) { this.filterText = filterText; return this; }
        public Builder sortKey(String sortKey) { this.sortKey = sortKey; return this; }
        public Builder kind(int kind) { this.kind = kind; return this; }

        public CompletionItem build() { return new CompletionItem(this); }
    }

    @Override
    public String toString() {
        return "CompletionItem{label='" + label + "', kind=" + kind + "}";
    }
}
