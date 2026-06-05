package com.qiplat.sweeteditor.core.search;

import com.qiplat.sweeteditor.core.foundation.TextRange;

public final class SearchState {
    public SearchStatus status = SearchStatus.INACTIVE;
    public String pattern = "";
    public SearchOptions options = new SearchOptions();
    public long generation = 0L;
    public int matchCount = 0;
    public int currentIndex = -1;
    public boolean hasCurrentMatch = false;
    public TextRange currentRange = new TextRange();
    public String errorMessage = "";

    public SearchState() {
    }

    public SearchState(SearchStatus status, String pattern, SearchOptions options, long generation, int matchCount, int currentIndex, boolean hasCurrentMatch, TextRange currentRange, String errorMessage) {
        this.status = status;
        this.pattern = pattern;
        this.options = options;
        this.generation = generation;
        this.matchCount = matchCount;
        this.currentIndex = currentIndex;
        this.hasCurrentMatch = hasCurrentMatch;
        this.currentRange = currentRange;
        this.errorMessage = errorMessage;
    }
}
