//
// Created by Scave on 2026/6/4.
//
#ifndef SWEETEDITOR_SEARCH_H
#define SWEETEDITOR_SEARCH_H

#include <cstdint>
#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR {

  enum class SE_PROTOCOL_ENUM(search, INACTIVE) SearchStatus : uint8_t {
    INACTIVE = 0,
    SEARCHING = 1,
    READY = 2,
    STALE = 3,
    FAILED = 4,
  };

  struct SE_PROTOCOL_VALUE(search) SearchOptions {
    bool case_sensitive {false};
    bool whole_word {false};
    bool use_regex {false};
    bool wrap_around {true};
    uint32_t max_matches {10000};
  };

  struct SE_PROTOCOL_IN(search) SearchRequest {
    U8String pattern;
    SearchOptions options;
  };

  struct SE_PROTOCOL_OUT(search) SearchState {
    SE_PROTOCOL_WIRE(enum_i32)
    SearchStatus status {SearchStatus::INACTIVE};
    U8String pattern;
    SearchOptions options;
    SE_PROTOCOL_WIRE(u64)
    uint64_t generation {0};
    uint32_t match_count {0};
    int32_t current_index {-1};
    bool has_current_match {false};
    TextRange current_range;
    U8String error_message;
  };

  struct SearchCapture {
    bool matched {false};
    TextRange range;
    U8String text;
  };

  struct SearchMatch {
    TextRange range;
    U8String text;
    Vector<SearchCapture> captures;
  };

  struct SearchSnapshot {
    U16String text;
    Vector<size_t> line_start_offsets;
    Vector<size_t> line_lengths;
    SearchRequest request;
    SearchState state;
    TextPosition cursor_position;
  };

  struct SearchResult {
    SearchState state;
    Vector<SearchMatch> matches;
  };

  class SearchEngine {
  public:
    virtual ~SearchEngine() = default;

    virtual SearchResult search(const SearchSnapshot& snapshot) const = 0;

    virtual U8String buildReplacement(const SearchMatch& match,
                                      const U8String& replacement,
                                      const SearchOptions& options) const = 0;
  };

  const SearchEngine& getSearchEngine();
}

#endif //SWEETEDITOR_SEARCH_H
