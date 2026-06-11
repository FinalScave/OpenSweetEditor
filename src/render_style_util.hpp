#ifndef SWEETEDITOR_RENDER_STYLE_UTIL_HPP
#define SWEETEDITOR_RENDER_STYLE_UTIL_HPP

#include <sweeteditor/decoration.h>
#include <sweeteditor/visual.h>

namespace NS_SWEETEDITOR {
  namespace RenderStyleUtil {
    inline bool hasRangeEffectPaint(const RangeEffectStyle& style) {
      return style.background_color != 0
          || style.border_color != 0
          || style.underline_color != 0;
    }

    inline RangeEffectKind diagnosticRangeEffectKind(DiagnosticSeverity severity) {
      switch (severity) {
        case DiagnosticSeverity::DIAG_WARNING:
          return RangeEffectKind::DIAGNOSTIC_WARNING;
        case DiagnosticSeverity::DIAG_INFO:
          return RangeEffectKind::DIAGNOSTIC_INFO;
        case DiagnosticSeverity::DIAG_HINT:
          return RangeEffectKind::DIAGNOSTIC_HINT;
        case DiagnosticSeverity::DIAG_ERROR:
        default:
          return RangeEffectKind::DIAGNOSTIC_ERROR;
      }
    }

    inline const RangeEffectStyle& diagnosticRangeEffectStyle(const EditorRangeEffectStyles& styles,
                                                             DiagnosticSeverity severity) {
      switch (severity) {
        case DiagnosticSeverity::DIAG_WARNING:
          return styles.diagnostic_warning;
        case DiagnosticSeverity::DIAG_INFO:
          return styles.diagnostic_info;
        case DiagnosticSeverity::DIAG_HINT:
          return styles.diagnostic_hint;
        case DiagnosticSeverity::DIAG_ERROR:
        default:
          return styles.diagnostic_error;
      }
    }

    inline RangeEffectKind documentHighlightRangeEffectKind(DocumentHighlightKind kind) {
      switch (kind) {
        case DocumentHighlightKind::READ:
          return RangeEffectKind::DOCUMENT_HIGHLIGHT_READ;
        case DocumentHighlightKind::WRITE:
          return RangeEffectKind::DOCUMENT_HIGHLIGHT_WRITE;
        case DocumentHighlightKind::TEXT:
        default:
          return RangeEffectKind::DOCUMENT_HIGHLIGHT_TEXT;
      }
    }

    inline const RangeEffectStyle& documentHighlightRangeEffectStyle(const EditorRangeEffectStyles& styles,
                                                                    DocumentHighlightKind kind) {
      switch (kind) {
        case DocumentHighlightKind::READ:
          return styles.document_highlight_read;
        case DocumentHighlightKind::WRITE:
          return styles.document_highlight_write;
        case DocumentHighlightKind::TEXT:
        default:
          return styles.document_highlight_text;
      }
    }
  }
}

#endif //SWEETEDITOR_RENDER_STYLE_UTIL_HPP
