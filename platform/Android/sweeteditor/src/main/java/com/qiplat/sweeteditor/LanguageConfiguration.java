package com.qiplat.sweeteditor;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Language configuration describing metadata such as brackets, comments, and indentation for a specific programming language.
 * When set to EditorCore, brackets will be automatically synced to Core layer's setBracketPairs.
 */
public class LanguageConfiguration {

    /** Bracket pair */
    public static class BracketPair {
        @NonNull public final String open;
        @NonNull public final String close;

        public BracketPair(@NonNull String open, @NonNull String close) {
            this.open = open;
            this.close = close;
        }
    }

    @NonNull private final String languageId;
    @NonNull private final List<BracketPair> brackets;
    @NonNull private final List<BracketPair> autoClosingPairs;
    private final int tabSize;
    private final boolean insertSpaces;

    private LanguageConfiguration(Builder builder) {
        this.languageId = builder.languageId;
        this.brackets = Collections.unmodifiableList(new ArrayList<>(builder.brackets));
        this.autoClosingPairs = Collections.unmodifiableList(new ArrayList<>(builder.autoClosingPairs));
        this.tabSize = builder.tabSize;
        this.insertSpaces = builder.insertSpaces;
    }

    @NonNull public String getLanguageId() { return languageId; }
    @NonNull public List<BracketPair> getBrackets() { return brackets; }
    @NonNull public List<BracketPair> getAutoClosingPairs() { return autoClosingPairs; }
    public int getTabSize() { return tabSize; }
    public boolean getInsertSpaces() { return insertSpaces; }

    public static class Builder {
        @NonNull private final String languageId;
        private final List<BracketPair> brackets = new ArrayList<>();
        private final List<BracketPair> autoClosingPairs = new ArrayList<>();
        private int tabSize;
        private boolean insertSpaces;

        public Builder(@NonNull String languageId) {
            this.languageId = languageId;
        }

        public Builder addBracket(@NonNull String open, @NonNull String close) {
            brackets.add(new BracketPair(open, close));
            return this;
        }

        public Builder addAutoClosingPair(@NonNull String open, @NonNull String close) {
            autoClosingPairs.add(new BracketPair(open, close));
            return this;
        }

        public Builder setTabSize(int tabSize) {
            this.tabSize = tabSize;
            return this;
        }

        public Builder setInsertSpaces(boolean insertSpaces) {
            this.insertSpaces = insertSpaces;
            return this;
        }

        public LanguageConfiguration build() {
            return new LanguageConfiguration(this);
        }
    }
}
