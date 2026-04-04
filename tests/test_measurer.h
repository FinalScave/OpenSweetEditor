#ifndef SWEETEDITOR_TEST_MEASURER_H
#define SWEETEDITOR_TEST_MEASURER_H

#include "layout.h"

namespace NS_SWEETEDITOR {
  class FixedWidthTextMeasurer final : public TextMeasurer {
  public:
    explicit FixedWidthTextMeasurer(float char_width = 10.0f,
                                    float ascent = -8.0f,
                                    float descent = 2.0f)
      : m_char_width_(char_width), m_ascent_(ascent), m_descent_(descent) {}

    float measureWidth(const U16String& text, int32_t /*font_style*/) override {
      return static_cast<float>(text.size()) * m_char_width_;
    }

    float measureInlayHintWidth(const U16String& text) override {
      return static_cast<float>(text.size()) * (m_char_width_ * 0.8f);
    }

    float measureIconWidth(int32_t /*icon_id*/) override {
      return m_char_width_;
    }

    FontMetrics getFontMetrics() override {
      return {m_ascent_, m_descent_};
    }

  private:
    float m_char_width_;
    float m_ascent_;
    float m_descent_;
  };

  class FixedGraphemeWidthTextMeasurer final : public TextMeasurer {
  public:
    explicit FixedGraphemeWidthTextMeasurer(float grapheme_width = 10.0f,
                                            float ascent = -8.0f,
                                            float descent = 2.0f)
      : m_grapheme_width_(grapheme_width), m_ascent_(ascent), m_descent_(descent) {}

    float measureWidth(const U16String& text, int32_t /*font_style*/) override {
      size_t grapheme_count = 0;
      size_t column = 0;
      while (column < text.size()) {
        size_t next = UnicodeUtil::nextGraphemeBoundaryColumn(text, column);
        if (next <= column) {
          break;
        }
        ++grapheme_count;
        column = next;
      }
      return static_cast<float>(grapheme_count) * m_grapheme_width_;
    }

    float measureInlayHintWidth(const U16String& text) override {
      return measureWidth(text, FONT_STYLE_NORMAL) * 0.8f;
    }

    float measureIconWidth(int32_t /*icon_id*/) override {
      return m_grapheme_width_;
    }

    FontMetrics getFontMetrics() override {
      return {m_ascent_, m_descent_};
    }

  private:
    float m_grapheme_width_;
    float m_ascent_;
    float m_descent_;
  };
}

#endif // SWEETEDITOR_TEST_MEASURER_H
