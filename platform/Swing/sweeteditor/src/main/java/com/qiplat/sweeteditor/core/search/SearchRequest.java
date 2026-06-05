package com.qiplat.sweeteditor.core.search;

public final class SearchRequest {
    public String pattern = "";
    public SearchOptions options = new SearchOptions();

    public SearchRequest() {
    }

    public SearchRequest(String pattern, SearchOptions options) {
        this.pattern = pattern;
        this.options = options;
    }
}
