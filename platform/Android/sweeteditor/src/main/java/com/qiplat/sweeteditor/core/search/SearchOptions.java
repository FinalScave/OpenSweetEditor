package com.qiplat.sweeteditor.core.search;

public final class SearchOptions {
    public boolean caseSensitive = false;
    public boolean wholeWord = false;
    public boolean useRegex = false;
    public boolean wrapAround = true;
    public int maxMatches = 10000;

    public SearchOptions() {
    }

    public SearchOptions(boolean caseSensitive, boolean wholeWord, boolean useRegex, boolean wrapAround, int maxMatches) {
        this.caseSensitive = caseSensitive;
        this.wholeWord = wholeWord;
        this.useRegex = useRegex;
        this.wrapAround = wrapAround;
        this.maxMatches = maxMatches;
    }
}
