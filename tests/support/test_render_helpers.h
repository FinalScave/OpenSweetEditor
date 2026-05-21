#ifndef SWEETEDITOR_TEST_RENDER_HELPERS_H
#define SWEETEDITOR_TEST_RENDER_HELPERS_H

#include <algorithm>
#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/utility.h>
#include <sweeteditor/visual.h>

namespace NS_SWEETEDITOR {

  inline U8String collectVisualLineText(const VisualLine& line) {
    U8String out;
    for (const VisualRun& run : line.runs) {
      if (run.text.empty()) continue;
      U8String text;
      StrUtil::convertUTF16ToUTF8(run.text, text);
      out += text;
    }
    return out;
  }

  inline const VisualLine& findCodeLensVisualLine(const EditorRenderModel& model, size_t logical_line) {
    auto it = std::find_if(model.lines.begin(), model.lines.end(), [logical_line](const VisualLine& line) {
      return line.logical_line == logical_line && line.kind == VisualLineKind::CODELENS;
    });
    REQUIRE(it != model.lines.end());
    return *it;
  }

  inline const VisualRun& findNthCodeLensRun(const VisualLine& line, size_t index) {
    size_t current = 0;
    for (const VisualRun& run : line.runs) {
      if (run.type != VisualRunType::CODELENS) continue;
      if (current == index) return run;
      ++current;
    }
    REQUIRE(false);
    return line.runs.front();
  }

  inline const VisualRun& findFirstRunOfType(const VisualLine& line, VisualRunType type) {
    for (const VisualRun& run : line.runs) {
      if (run.type == type) {
        return run;
      }
    }
    REQUIRE(false);
    return line.runs.front();
  }

  inline Vector<const VisualRun*> findRunsOfType(const EditorRenderModel& model,
                                                 size_t logical_line,
                                                 VisualRunType type) {
    Vector<const VisualRun*> runs;
    for (const VisualLine& line : model.lines) {
      if (line.logical_line != logical_line) continue;
      for (const VisualRun& run : line.runs) {
        if (run.type == type) {
          runs.push_back(&run);
        }
      }
    }
    return runs;
  }

}

#endif // SWEETEDITOR_TEST_RENDER_HELPERS_H
