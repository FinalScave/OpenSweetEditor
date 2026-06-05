#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum SearchStatus {
        INACTIVE = 0,
        SEARCHING = 1,
        READY = 2,
        STALE = 3,
        FAILED = 4
    }

    public sealed partial class SearchOptions {
        public bool CaseSensitive { get; set; } = false;
        public bool WholeWord { get; set; } = false;
        public bool UseRegex { get; set; } = false;
        public bool WrapAround { get; set; } = true;
        public int MaxMatches { get; set; } = 10000;
    }

    public sealed partial class SearchRequest {
        public string Pattern { get; set; } = string.Empty;
        public SearchOptions Options { get; set; } = new SearchOptions();
    }

    public sealed partial class SearchState {
        public SearchStatus Status { get; set; } = SearchStatus.INACTIVE;
        public string Pattern { get; set; } = string.Empty;
        public SearchOptions Options { get; set; } = new SearchOptions();
        public long Generation { get; set; } = 0L;
        public int MatchCount { get; set; } = 0;
        public int CurrentIndex { get; set; } = -1;
        public bool HasCurrentMatch { get; set; } = false;
        public TextRange CurrentRange { get; set; } = new TextRange();
        public string ErrorMessage { get; set; } = string.Empty;
    }
}
