// ignore_for_file: unused_element

part of 'editor_core.dart';

enum SearchStatus {
  inactive(0),
  searching(1),
  ready(2),
  stale(3),
  failed(4);

  const SearchStatus(this.value);
  final int value;

  static SearchStatus fromValue(int value) {
    switch (value) {
      case 0: return inactive;
      case 1: return searching;
      case 2: return ready;
      case 3: return stale;
      case 4: return failed;
      default: return inactive;
    }
  }
}

class SearchOptions {
  const SearchOptions({
    this.caseSensitive = false,
    this.wholeWord = false,
    this.useRegex = false,
    this.wrapAround = true,
    this.maxMatches = 10000,
  });

  final bool caseSensitive;
  final bool wholeWord;
  final bool useRegex;
  final bool wrapAround;
  final int maxMatches;
}

class SearchReplaceRequest {
  const SearchReplaceRequest({
    this.replacement = '',
  });

  final String replacement;
}

class SearchRequest {
  const SearchRequest({
    this.pattern = '',
    this.options = const SearchOptions(),
  });

  final String pattern;
  final SearchOptions options;
}

class SearchState {
  const SearchState({
    this.status = SearchStatus.inactive,
    this.pattern = '',
    this.options = const SearchOptions(),
    this.generation = 0,
    this.documentRevision = 0,
    this.matchCount = 0,
    this.currentIndex = -1,
    this.hasCurrentMatch = false,
    this.currentRange = const TextRange(),
    this.errorMessage = '',
  });

  final SearchStatus status;
  final String pattern;
  final SearchOptions options;
  final int generation;
  final int documentRevision;
  final int matchCount;
  final int currentIndex;
  final bool hasCurrentMatch;
  final TextRange currentRange;
  final String errorMessage;
}
