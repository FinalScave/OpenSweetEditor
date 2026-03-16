//
// Created by Scave on 2025/12/7.
//
#include <visual.h>

namespace NS_SWEETEDITOR {
#pragma region [Class: VisualRun]
  U8String VisualRun::dump() const {
    return "VisualRun {type = " + dumpEnum(type) + ", x = " + std::to_string(x) + ", y = " + std::to_string(y)
      + "style = {font_style = " + std::to_string(style.font_style) + ", color = " + std::to_string(style.color) + "} }";
  }
#pragma endregion

#pragma region [Class: VisualLine]
  U8String VisualLine::dump() const {
    U8String result = "VisualLine {logical_line = " + std::to_string(logical_line) + ", runs = [";
    for (const VisualRun& run : runs) {
      result += "\n  ";
      result += run.dump();
    }
    result += "\n]\n}";
    return result;
  }
#pragma endregion

#pragma region [Class: Cursor]
  U8String Cursor::dump() const {
    return "Cursor = {text_position = " + text_position.dump() + ", position = " + position.dump()
      + ", height = " + std::to_string(height) + ", visible = " + std::to_string(visible)
      + ", show_dragger = " + std::to_string(show_dragger) + "}";
  }
#pragma endregion

#pragma region [Class: EditorRenderModel]
  U8String EditorRenderModel::dump() const {
    U8String result = "EditorRenderModel {current_line = " + current_line.dump() + ", visual_lines = [";
    for (const VisualLine& line : lines) {
      result += "\n  ";
      result += line.dump();
    }
    result += "\n], cursor = " + cursor.dump() + "}";
    return result;
  }

  U8String EditorRenderModel::toJson() const {
    nlohmann::json root = *this;
    return root.dump(2);
  }
#pragma endregion

#pragma region [Class: LayoutMetrics]
  U8String LayoutMetrics::toJson() const {
    nlohmann::json root = *this;
    return root.dump(2);
  }
#pragma endregion

  U8String dumpEnum(VisualRunType type) {
    switch (type) {
    case VisualRunType::TEXT:
      return "TEXT";
    case VisualRunType::WHITESPACE:
      return "WHITESPACE";
    case VisualRunType::NEWLINE:
      return "NEWLINE";
    case VisualRunType::INLAY_HINT:
      return "INLAY_HINT";
    case VisualRunType::PHANTOM_TEXT:
      return "PHANTOM_TEXT";
    default:
      return "UNDEFINED";
    }
  }

  U8String dumpEnum(GuideDirection direction) {
    switch (direction) {
    case GuideDirection::VERTICAL:   return "VERTICAL";
    case GuideDirection::HORIZONTAL: return "HORIZONTAL";
    default:                         return "UNDEFINED";
    }
  }

  U8String dumpEnum(GuideType type) {
    switch (type) {
    case GuideType::INDENT:    return "INDENT";
    case GuideType::BRACKET:   return "BRACKET";
    case GuideType::FLOW:      return "FLOW";
    case GuideType::SEPARATOR: return "SEPARATOR";
    default:                   return "UNDEFINED";
    }
  }

  U8String dumpEnum(GuideStyle style) {
    switch (style) {
    case GuideStyle::SOLID:  return "SOLID";
    case GuideStyle::DASHED: return "DASHED";
    case GuideStyle::DOUBLE: return "DOUBLE";
    default:                 return "UNDEFINED";
    }
  }
}
