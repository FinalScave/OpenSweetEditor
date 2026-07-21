//
// Created by Scave on 2026/6/4.
//
#include <algorithm>
#include <cctype>
#include <regex>
#include <sweeteditor/search.h>
#include <sweeteditor/utility.h>
#include "text_boundary.hpp"

namespace NS_SWEETEDITOR {
  namespace {
    U16Char foldAscii(U16Char ch) {
      if (ch >= CHAR16('A') && ch <= CHAR16('Z')) {
        return static_cast<U16Char>(ch - CHAR16('A') + CHAR16('a'));
      }
      return ch;
    }

    U16String foldedAsciiText(const U16String& text) {
      U16String result = text;
      for (U16Char& ch : result) {
        ch = foldAscii(ch);
      }
      return result;
    }

    uint32_t combineSurrogatePair(uint32_t high, uint32_t low) {
      return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
    }

    struct WideText {
      std::wstring text;
      Vector<size_t> wide_to_u16;
    };

    WideText toWideText(const U16String& text) {
      WideText result;
      result.wide_to_u16.reserve(text.size() + 1);
      result.text.reserve(text.size());

      size_t index = 0;
      while (index < text.size()) {
        result.wide_to_u16.push_back(index);
        uint32_t value = static_cast<uint32_t>(text[index]);
        if constexpr (sizeof(wchar_t) == 2) {
          result.text.push_back(static_cast<wchar_t>(value));
          ++index;
        } else {
          if (UnicodeUtil::isLeadSurrogate(text[index]) && index + 1 < text.size()) {
            uint32_t low = static_cast<uint32_t>(text[index + 1]);
            if (UnicodeUtil::isTrailSurrogate(text[index + 1])) {
              result.text.push_back(static_cast<wchar_t>(combineSurrogatePair(value, low)));
              index += 2;
              continue;
            }
          }
          result.text.push_back(static_cast<wchar_t>(value));
          ++index;
        }
      }
      result.wide_to_u16.push_back(text.size());
      return result;
    }

    std::wstring toWidePattern(const U16String& text) {
      return toWideText(text).text;
    }

    TextPosition positionFromOffset(const SearchSnapshot& snapshot, size_t offset) {
      if (snapshot.line_start_offsets.empty()) {
        return {};
      }

      auto it = std::upper_bound(snapshot.line_start_offsets.begin(), snapshot.line_start_offsets.end(), offset);
      size_t line = it == snapshot.line_start_offsets.begin()
                        ? 0
                        : static_cast<size_t>(std::distance(snapshot.line_start_offsets.begin(), it) - 1);
      line = std::min(line, snapshot.line_lengths.size() - 1);
      const size_t line_start = snapshot.line_start_offsets[line];
      const size_t column = std::min(offset - line_start, snapshot.line_lengths[line]);
      return {line, column};
    }

    TextRange rangeFromOffsets(const SearchSnapshot& snapshot, size_t start, size_t end) {
      return {positionFromOffset(snapshot, start), positionFromOffset(snapshot, end)};
    }

    U8String textFromOffsets(const SearchSnapshot& snapshot, size_t start, size_t end) {
      if (start >= end || start >= snapshot.text.size()) {
        return {};
      }
      end = std::min(end, snapshot.text.size());
      U8String result;
      StrUtil::convertUTF16ToUTF8(snapshot.text.substr(start, end - start), result);
      return result;
    }

    bool passesWholeWord(const SearchSnapshot& snapshot, size_t start, size_t end) {
      if (!snapshot.request.options.whole_word) {
        return true;
      }
      if (start == end) {
        return false;
      }

      const bool left_word = start > 0 && TextBoundaryUtil::isWordChar(snapshot.text[start - 1]);
      const bool first_word = start < snapshot.text.size() && TextBoundaryUtil::isWordChar(snapshot.text[start]);
      const bool last_word =
          end > 0 && end <= snapshot.text.size() && TextBoundaryUtil::isWordChar(snapshot.text[end - 1]);
      const bool right_word = end < snapshot.text.size() && TextBoundaryUtil::isWordChar(snapshot.text[end]);
      return (!left_word || !first_word) && (!last_word || !right_word);
    }

    void appendMatch(SearchResult& result, const SearchSnapshot& snapshot, size_t start, size_t end,
                     Vector<SearchCapture>&& captures) {
      if (start >= end || !passesWholeWord(snapshot, start, end)) {
        return;
      }

      SearchMatch match;
      match.range = rangeFromOffsets(snapshot, start, end);
      match.text = textFromOffsets(snapshot, start, end);
      match.captures = std::move(captures);
      result.matches.push_back(std::move(match));
    }

    void appendLiteralMatch(SearchResult& result, const SearchSnapshot& snapshot, size_t start, size_t end) {
      Vector<SearchCapture> captures;
      SearchCapture capture;
      capture.matched = true;
      capture.range = rangeFromOffsets(snapshot, start, end);
      capture.text = textFromOffsets(snapshot, start, end);
      captures.push_back(std::move(capture));
      appendMatch(result, snapshot, start, end, std::move(captures));
    }

    bool reachedMatchLimit(const SearchResult& result, uint32_t max_matches) {
      return max_matches != 0 && result.matches.size() >= max_matches;
    }

    SearchResult executeLiteralSearch(const SearchSnapshot& snapshot) {
      SearchResult result;
      result.state = snapshot.state;
      U16String pattern;
      StrUtil::convertUTF8ToUTF16(snapshot.request.pattern, pattern);
      if (pattern.empty()) {
        result.state.status = SearchStatus::INACTIVE;
        return result;
      }

      U16String haystack = snapshot.text;
      U16String needle = pattern;
      if (!snapshot.request.options.case_sensitive) {
        haystack = foldedAsciiText(haystack);
        needle = foldedAsciiText(needle);
      }

      size_t search_from = 0;
      while (search_from <= haystack.size()) {
        size_t found = haystack.find(needle, search_from);
        if (found == U16String::npos) {
          break;
        }
        appendLiteralMatch(result, snapshot, found, found + needle.size());
        if (reachedMatchLimit(result, snapshot.request.options.max_matches)) {
          break;
        }
        search_from = found + std::max<size_t>(needle.size(), 1);
      }
      return result;
    }

    SearchResult executeRegexSearch(const SearchSnapshot& snapshot) {
      SearchResult result;
      result.state = snapshot.state;
      U16String pattern_u16;
      StrUtil::convertUTF8ToUTF16(snapshot.request.pattern, pattern_u16);
      if (pattern_u16.empty()) {
        result.state.status = SearchStatus::INACTIVE;
        return result;
      }

      try {
        WideText wide_text = toWideText(snapshot.text);
        const std::wstring wide_pattern = toWidePattern(pattern_u16);
        auto flags = std::regex_constants::ECMAScript;
        if (!snapshot.request.options.case_sensitive) {
          flags |= std::regex_constants::icase;
        }
        std::wregex regex(wide_pattern, flags);

        auto search_begin = wide_text.text.cbegin();
        const auto search_end = wide_text.text.cend();
        while (search_begin <= search_end) {
          std::wsmatch match;
          if (!std::regex_search(search_begin, search_end, match, regex)) {
            break;
          }

          const size_t base_wide = static_cast<size_t>(std::distance(wide_text.text.cbegin(), search_begin));
          const size_t start_wide = base_wide + static_cast<size_t>(match.position(0));
          const size_t end_wide = start_wide + static_cast<size_t>(match.length(0));
          const size_t start_u16 = wide_text.wide_to_u16[std::min(start_wide, wide_text.wide_to_u16.size() - 1)];
          const size_t end_u16 = wide_text.wide_to_u16[std::min(end_wide, wide_text.wide_to_u16.size() - 1)];

          Vector<SearchCapture> captures;
          captures.reserve(match.size());
          for (size_t i = 0; i < match.size(); ++i) {
            SearchCapture capture;
            capture.matched = match[i].matched;
            if (capture.matched) {
              const size_t capture_start_wide = base_wide + static_cast<size_t>(match.position(i));
              const size_t capture_end_wide = capture_start_wide + static_cast<size_t>(match.length(i));
              const size_t capture_start_u16 =
                  wide_text.wide_to_u16[std::min(capture_start_wide, wide_text.wide_to_u16.size() - 1)];
              const size_t capture_end_u16 =
                  wide_text.wide_to_u16[std::min(capture_end_wide, wide_text.wide_to_u16.size() - 1)];
              capture.range = rangeFromOffsets(snapshot, capture_start_u16, capture_end_u16);
              capture.text = textFromOffsets(snapshot, capture_start_u16, capture_end_u16);
            }
            captures.push_back(std::move(capture));
          }

          appendMatch(result, snapshot, start_u16, end_u16, std::move(captures));
          if (reachedMatchLimit(result, snapshot.request.options.max_matches)) {
            break;
          }

          size_t next_wide = end_wide;
          if (start_wide == end_wide) {
            next_wide = start_wide + 1;
          }
          if (next_wide > wide_text.text.size()) {
            break;
          }
          search_begin = wide_text.text.cbegin() + static_cast<std::ptrdiff_t>(next_wide);
        }
      } catch (const std::regex_error& error) {
        result.matches.clear();
        result.state.status = SearchStatus::FAILED;
        result.state.error_message = error.what();
      }
      return result;
    }

    const U8String& captureTextOrEmpty(const SearchMatch& match, size_t index) {
      static const U8String empty;
      if (index >= match.captures.size() || !match.captures[index].matched) {
        return empty;
      }
      return match.captures[index].text;
    }

#if SWEETEDITOR_SEARCH_IMPL_STD
    class StdSearchEngine final : public SearchEngine {
    public:
      SearchResult search(const SearchSnapshot& snapshot) const override {
        SearchResult result =
            snapshot.request.options.use_regex ? executeRegexSearch(snapshot) : executeLiteralSearch(snapshot);
        if (result.state.status != SearchStatus::FAILED && result.state.status != SearchStatus::INACTIVE) {
          result.state.status = SearchStatus::READY;
        }
        result.state.match_count = static_cast<uint32_t>(result.matches.size());
        result.state.has_current_match =
            result.state.current_index >= 0 && static_cast<size_t>(result.state.current_index) < result.matches.size();
        if (result.state.has_current_match) {
          result.state.current_range = result.matches[static_cast<size_t>(result.state.current_index)].range;
        } else {
          result.state.current_index = result.matches.empty() ? -1 : 0;
          result.state.has_current_match = !result.matches.empty();
          if (result.state.has_current_match) {
            result.state.current_range = result.matches.front().range;
          }
        }
        return result;
      }

      U8String buildReplacement(const SearchMatch& match, const U8String& replacement,
                                const SearchOptions& options) const override {
        if (!options.use_regex) {
          return replacement;
        }

        U8String result;
        result.reserve(replacement.size());
        for (size_t i = 0; i < replacement.size(); ++i) {
          char ch = replacement[i];
          if (ch != '$' || i + 1 >= replacement.size()) {
            result.push_back(ch);
            continue;
          }

          char next = replacement[i + 1];
          if (next == '$') {
            result.push_back('$');
            ++i;
            continue;
          }
          if (next == '&') {
            result += captureTextOrEmpty(match, 0);
            ++i;
            continue;
          }
          if (next >= '0' && next <= '9') {
            size_t capture_index = static_cast<size_t>(next - '0');
            size_t consumed = 1;
            if (i + 2 < replacement.size() && std::isdigit(static_cast<unsigned char>(replacement[i + 2]))) {
              const size_t two_digit = capture_index * 10 + static_cast<size_t>(replacement[i + 2] - '0');
              if (two_digit < match.captures.size()) {
                capture_index = two_digit;
                consumed = 2;
              }
            }
            result += captureTextOrEmpty(match, capture_index);
            i += consumed;
            continue;
          }

          result.push_back('$');
        }
        return result;
      }
    };
#else
    class UnavailableSearchEngine final : public SearchEngine {
    public:
      SearchResult search(const SearchSnapshot& snapshot) const override {
        SearchResult result;
        result.state = snapshot.state;
        result.state.status = SearchStatus::FAILED;
        result.state.error_message = "Search implementation is not available";
        return result;
      }

      U8String buildReplacement(const SearchMatch&, const U8String& replacement, const SearchOptions&) const override {
        return replacement;
      }
    };
#endif
  }

  const SearchEngine& getSearchEngine() {
#if SWEETEDITOR_SEARCH_IMPL_STD
    static const StdSearchEngine engine;
#else
    static const UnavailableSearchEngine engine;
#endif
    return engine;
  }
}
