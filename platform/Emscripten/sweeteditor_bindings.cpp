#include <emscripten/bind.h>
#include <emscripten/val.h>

#include <decoration.h>
#include <document.h>
#include <editor_core.h>
#include <foundation.h>
#include <gesture.h>
#include <layout.h>
#include <linked_editing.h>
#include <utility.h>
#include <visual.h>

namespace {
using namespace emscripten;
using namespace NS_SWEETEDITOR;

class JsTextMeasurer final : public TextMeasurer {
public:
  explicit JsTextMeasurer(val callbacks): callbacks_(std::move(callbacks)) {}

  float measureWidth(const U16String& text, int32_t font_style) override {
    val fn = callbacks_["measureTextWidth"];
    if (fn.isUndefined() || fn.isNull()) {
      return 0.0f;
    }
    return fn(toU8(text), font_style).as<float>();
  }

  float measureInlayHintWidth(const U16String& text) override {
    val fn = callbacks_["measureInlayHintWidth"];
    if (fn.isUndefined() || fn.isNull()) {
      return 0.0f;
    }
    return fn(toU8(text)).as<float>();
  }

  float measureIconWidth(int32_t icon_id) override {
    val fn = callbacks_["measureIconWidth"];
    if (fn.isUndefined() || fn.isNull()) {
      return 0.0f;
    }
    return fn(icon_id).as<float>();
  }

  FontMetrics getFontMetrics() override {
    FontMetrics metrics {0.0f, 0.0f};
    val fn = callbacks_["getFontMetrics"];
    if (fn.isUndefined() || fn.isNull()) {
      return metrics;
    }

    val result = fn();
    if (result.isArray()) {
      const unsigned len = result["length"].as<unsigned>();
      if (len > 0) metrics.ascent = result[0].as<float>();
      if (len > 1) metrics.descent = result[1].as<float>();
      return metrics;
    }

    val ascent = result["ascent"];
    val descent = result["descent"];
    if (!ascent.isUndefined() && !ascent.isNull()) metrics.ascent = ascent.as<float>();
    if (!descent.isUndefined() && !descent.isNull()) metrics.descent = descent.as<float>();
    return metrics;
  }

private:
  static U8String toU8(const U16String& input) {
    U8String out;
    StrUtil::convertUTF16ToUTF8(input, out);
    return out;
  }

  val callbacks_;
};

struct LineStyleSpansEntry {
  size_t line {0};
  Vector<StyleSpan> spans;
};

struct LineInlayHintsEntry {
  size_t line {0};
  Vector<InlayHint> hints;
};

struct LinePhantomTextsEntry {
  size_t line {0};
  Vector<PhantomText> phantoms;
};

struct LineGutterIconsEntry {
  size_t line {0};
  Vector<GutterIcon> icons;
};

struct LineDiagnosticsEntry {
  size_t line {0};
  Vector<DiagnosticSpan> diagnostics;
};

Ptr<EditorCore> createEditorCore(const val& callbacks, const EditorOptions& options) {
  return makePtr<EditorCore>(makePtr<JsTextMeasurer>(callbacks), options);
}

Ptr<LineArrayDocument> createLineArrayDocument(const U8String& text) {
  return makePtr<LineArrayDocument>(text);
}

Ptr<PieceTableDocument> createPieceTableDocument(const U8String& text) {
  return makePtr<PieceTableDocument>(text);
}

TextStyle registryGetStyle(TextStyleRegistry& registry, uint32_t style_id) {
  return registry.getStyle(style_id);
}

LayoutMetrics editorGetLayoutMetrics(EditorCore& editor) {
  return editor.getLayoutMetrics();
}

EditorRenderModel editorBuildRenderModel(EditorCore& editor) {
  EditorRenderModel model;
  editor.buildRenderModel(model);
  return model;
}

U8String editorRenderModelDump(const EditorRenderModel& model) {
  return model.dump();
}

U8String editorRenderModelToJson(const EditorRenderModel& model) {
  return model.toJson();
}

float layoutMetricsGutterWidth(const LayoutMetrics& metrics) {
  return metrics.gutterWidth();
}

float layoutMetricsTextAreaX(const LayoutMetrics& metrics) {
  return metrics.textAreaX();
}

U8String layoutMetricsToJson(const LayoutMetrics& metrics) {
  return metrics.toJson();
}

U8String editorOptionsDump(const EditorOptions& options) {
  return options.dump();
}

U8String editorSettingsDump(const EditorSettings& settings) {
  return settings.dump();
}

CompositionState editorGetCompositionState(const EditorCore& editor) {
  return editor.getCompositionState();
}

void editorRegisterTextStyle(EditorCore& editor, uint32_t style_id, const TextStyle& style) {
  auto copy = style;
  editor.registerTextStyle(style_id, std::move(copy));
}

void editorSetLineSpans(EditorCore& editor, size_t line, SpanLayer layer, const Vector<StyleSpan>& spans) {
  auto copy = spans;
  editor.setLineSpans(line, layer, std::move(copy));
}

void editorSetBatchLineSpans(EditorCore& editor, SpanLayer layer, const Vector<LineStyleSpansEntry>& entries) {
  Vector<std::pair<size_t, Vector<StyleSpan>>> native_entries;
  native_entries.reserve(entries.size());
  for (const auto& entry : entries) {
    native_entries.emplace_back(entry.line, entry.spans);
  }
  editor.setBatchLineSpans(layer, std::move(native_entries));
}

void editorSetLineInlayHints(EditorCore& editor, size_t line, const Vector<InlayHint>& hints) {
  auto copy = hints;
  editor.setLineInlayHints(line, std::move(copy));
}

void editorSetBatchLineInlayHints(EditorCore& editor, const Vector<LineInlayHintsEntry>& entries) {
  Vector<std::pair<size_t, Vector<InlayHint>>> native_entries;
  native_entries.reserve(entries.size());
  for (const auto& entry : entries) {
    native_entries.emplace_back(entry.line, entry.hints);
  }
  editor.setBatchLineInlayHints(std::move(native_entries));
}

void editorSetLinePhantomTexts(EditorCore& editor, size_t line, const Vector<PhantomText>& phantoms) {
  auto copy = phantoms;
  editor.setLinePhantomTexts(line, std::move(copy));
}

void editorSetBatchLinePhantomTexts(EditorCore& editor, const Vector<LinePhantomTextsEntry>& entries) {
  Vector<std::pair<size_t, Vector<PhantomText>>> native_entries;
  native_entries.reserve(entries.size());
  for (const auto& entry : entries) {
    native_entries.emplace_back(entry.line, entry.phantoms);
  }
  editor.setBatchLinePhantomTexts(std::move(native_entries));
}

void editorSetLineGutterIcons(EditorCore& editor, size_t line, const Vector<GutterIcon>& icons) {
  auto copy = icons;
  editor.setLineGutterIcons(line, std::move(copy));
}

void editorSetBatchLineGutterIcons(EditorCore& editor, const Vector<LineGutterIconsEntry>& entries) {
  Vector<std::pair<size_t, Vector<GutterIcon>>> native_entries;
  native_entries.reserve(entries.size());
  for (const auto& entry : entries) {
    native_entries.emplace_back(entry.line, entry.icons);
  }
  editor.setBatchLineGutterIcons(std::move(native_entries));
}

void editorSetLineDiagnostics(EditorCore& editor, size_t line, const Vector<DiagnosticSpan>& diagnostics) {
  auto copy = diagnostics;
  editor.setLineDiagnostics(line, std::move(copy));
}

void editorSetBatchLineDiagnostics(EditorCore& editor, const Vector<LineDiagnosticsEntry>& entries) {
  Vector<std::pair<size_t, Vector<DiagnosticSpan>>> native_entries;
  native_entries.reserve(entries.size());
  for (const auto& entry : entries) {
    native_entries.emplace_back(entry.line, entry.diagnostics);
  }
  editor.setBatchLineDiagnostics(std::move(native_entries));
}

void editorSetIndentGuides(EditorCore& editor, const Vector<IndentGuide>& guides) {
  auto copy = guides;
  editor.setIndentGuides(std::move(copy));
}

void editorSetBracketGuides(EditorCore& editor, const Vector<BracketGuide>& guides) {
  auto copy = guides;
  editor.setBracketGuides(std::move(copy));
}

void editorSetFlowGuides(EditorCore& editor, const Vector<FlowGuide>& guides) {
  auto copy = guides;
  editor.setFlowGuides(std::move(copy));
}

void editorSetSeparatorGuides(EditorCore& editor, const Vector<SeparatorGuide>& guides) {
  auto copy = guides;
  editor.setSeparatorGuides(std::move(copy));
}

void editorSetFoldRegions(EditorCore& editor, const Vector<FoldRegion>& regions) {
  auto copy = regions;
  editor.setFoldRegions(std::move(copy));
}

void editorSetBracketPairs(EditorCore& editor, const Vector<BracketPair>& pairs) {
  auto copy = pairs;
  editor.setBracketPairs(std::move(copy));
}

void editorStartLinkedEditing(EditorCore& editor, const LinkedEditingModel& model) {
  auto copy = model;
  editor.startLinkedEditing(std::move(copy));
}

GestureResult editorHandleGestureEventRaw(EditorCore& editor, int32_t type, const Vector<PointF>& points, uint8_t modifiers,
                                          float wheel_delta_x, float wheel_delta_y, float direct_scale) {
  GestureEvent event;
  event.type = static_cast<EventType>(type);
  event.points = points;
  event.modifiers = static_cast<Modifier>(modifiers);
  event.wheel_delta_x = wheel_delta_x;
  event.wheel_delta_y = wheel_delta_y;
  event.direct_scale = direct_scale;
  return editor.handleGestureEvent(event);
}

KeyEventResult editorHandleKeyEventRaw(EditorCore& editor, int32_t key_code, const U8String& text, uint8_t modifiers) {
  KeyEvent event;
  event.key_code = static_cast<KeyCode>(key_code);
  event.text = text;
  event.modifiers = static_cast<Modifier>(modifiers);
  return editor.handleKeyEvent(event);
}

EMSCRIPTEN_BINDINGS(sweeteditor_wasm) {
  enum_<LineEnding>("LineEnding")
    .value("NONE", LineEnding::NONE)
    .value("LF", LineEnding::LF)
    .value("CR", LineEnding::CR)
    .value("CRLF", LineEnding::CRLF);

  enum_<KeyCode>("KeyCode")
    .value("NONE", KeyCode::NONE)
    .value("BACKSPACE", KeyCode::BACKSPACE)
    .value("TAB", KeyCode::TAB)
    .value("ENTER", KeyCode::ENTER)
    .value("ESCAPE", KeyCode::ESCAPE)
    .value("DELETE_KEY", KeyCode::DELETE_KEY)
    .value("LEFT", KeyCode::LEFT)
    .value("UP", KeyCode::UP)
    .value("RIGHT", KeyCode::RIGHT)
    .value("DOWN", KeyCode::DOWN)
    .value("HOME", KeyCode::HOME)
    .value("END", KeyCode::END)
    .value("PAGE_UP", KeyCode::PAGE_UP)
    .value("PAGE_DOWN", KeyCode::PAGE_DOWN)
    .value("A", KeyCode::A)
    .value("C", KeyCode::C)
    .value("V", KeyCode::V)
    .value("X", KeyCode::X)
    .value("Z", KeyCode::Z)
    .value("Y", KeyCode::Y)
    .value("K", KeyCode::K);

  enum_<Modifier>("Modifier")
    .value("NONE", Modifier::NONE)
    .value("SHIFT", Modifier::SHIFT)
    .value("CTRL", Modifier::CTRL)
    .value("ALT", Modifier::ALT)
    .value("META", Modifier::META);

  enum_<ScrollBehavior>("ScrollBehavior")
    .value("GOTO_TOP", ScrollBehavior::GOTO_TOP)
    .value("GOTO_CENTER", ScrollBehavior::GOTO_CENTER)
    .value("GOTO_BOTTOM", ScrollBehavior::GOTO_BOTTOM);

  enum_<AutoIndentMode>("AutoIndentMode")
    .value("NONE", AutoIndentMode::NONE)
    .value("KEEP_INDENT", AutoIndentMode::KEEP_INDENT);

  enum_<EventType>("EventType")
    .value("UNDEFINED", EventType::UNDEFINED)
    .value("TOUCH_DOWN", EventType::TOUCH_DOWN)
    .value("TOUCH_POINTER_DOWN", EventType::TOUCH_POINTER_DOWN)
    .value("TOUCH_MOVE", EventType::TOUCH_MOVE)
    .value("TOUCH_POINTER_UP", EventType::TOUCH_POINTER_UP)
    .value("TOUCH_UP", EventType::TOUCH_UP)
    .value("TOUCH_CANCEL", EventType::TOUCH_CANCEL)
    .value("MOUSE_DOWN", EventType::MOUSE_DOWN)
    .value("MOUSE_MOVE", EventType::MOUSE_MOVE)
    .value("MOUSE_UP", EventType::MOUSE_UP)
    .value("MOUSE_WHEEL", EventType::MOUSE_WHEEL)
    .value("MOUSE_RIGHT_DOWN", EventType::MOUSE_RIGHT_DOWN)
    .value("DIRECT_SCALE", EventType::DIRECT_SCALE)
    .value("DIRECT_SCROLL", EventType::DIRECT_SCROLL);

  enum_<GestureType>("GestureType")
    .value("UNDEFINED", GestureType::UNDEFINED)
    .value("TAP", GestureType::TAP)
    .value("DOUBLE_TAP", GestureType::DOUBLE_TAP)
    .value("LONG_PRESS", GestureType::LONG_PRESS)
    .value("SCALE", GestureType::SCALE)
    .value("SCROLL", GestureType::SCROLL)
    .value("FAST_SCROLL", GestureType::FAST_SCROLL)
    .value("DRAG_SELECT", GestureType::DRAG_SELECT)
    .value("CONTEXT_MENU", GestureType::CONTEXT_MENU);

  enum_<HitTargetType>("HitTargetType")
    .value("NONE", HitTargetType::NONE)
    .value("INLAY_HINT_TEXT", HitTargetType::INLAY_HINT_TEXT)
    .value("INLAY_HINT_ICON", HitTargetType::INLAY_HINT_ICON)
    .value("GUTTER_ICON", HitTargetType::GUTTER_ICON)
    .value("FOLD_PLACEHOLDER", HitTargetType::FOLD_PLACEHOLDER)
    .value("FOLD_GUTTER", HitTargetType::FOLD_GUTTER)
    .value("INLAY_HINT_COLOR", HitTargetType::INLAY_HINT_COLOR);

  enum_<WrapMode>("WrapMode")
    .value("NONE", WrapMode::NONE)
    .value("CHAR_BREAK", WrapMode::CHAR_BREAK)
    .value("WORD_BREAK", WrapMode::WORD_BREAK);

  enum_<SpanLayer>("SpanLayer")
    .value("SYNTAX", SpanLayer::SYNTAX)
    .value("SEMANTIC", SpanLayer::SEMANTIC);

  enum_<InlayType>("InlayType")
    .value("TEXT", InlayType::TEXT)
    .value("ICON", InlayType::ICON)
    .value("COLOR", InlayType::COLOR);

  enum_<DiagnosticSeverity>("DiagnosticSeverity")
    .value("DIAG_ERROR", DiagnosticSeverity::DIAG_ERROR)
    .value("DIAG_WARNING", DiagnosticSeverity::DIAG_WARNING)
    .value("DIAG_INFO", DiagnosticSeverity::DIAG_INFO)
    .value("DIAG_HINT", DiagnosticSeverity::DIAG_HINT);

  enum_<SeparatorStyle>("SeparatorStyle")
    .value("SINGLE", SeparatorStyle::SINGLE)
    .value("DOUBLE", SeparatorStyle::DOUBLE);

  enum_<VisualRunType>("VisualRunType")
    .value("TEXT", VisualRunType::TEXT)
    .value("WHITESPACE", VisualRunType::WHITESPACE)
    .value("NEWLINE", VisualRunType::NEWLINE)
    .value("INLAY_HINT", VisualRunType::INLAY_HINT)
    .value("PHANTOM_TEXT", VisualRunType::PHANTOM_TEXT)
    .value("FOLD_PLACEHOLDER", VisualRunType::FOLD_PLACEHOLDER);

  enum_<FoldArrowMode>("FoldArrowMode")
    .value("AUTO", FoldArrowMode::AUTO)
    .value("ALWAYS", FoldArrowMode::ALWAYS)
    .value("HIDDEN", FoldArrowMode::HIDDEN);

  enum_<FoldState>("FoldState")
    .value("NONE", FoldState::NONE)
    .value("EXPANDED", FoldState::EXPANDED)
    .value("COLLAPSED", FoldState::COLLAPSED);

  enum_<GuideDirection>("GuideDirection")
    .value("HORIZONTAL", GuideDirection::HORIZONTAL)
    .value("VERTICAL", GuideDirection::VERTICAL);

  enum_<GuideType>("GuideType")
    .value("INDENT", GuideType::INDENT)
    .value("BRACKET", GuideType::BRACKET)
    .value("FLOW", GuideType::FLOW)
    .value("SEPARATOR", GuideType::SEPARATOR);

  enum_<GuideStyle>("GuideStyle")
    .value("SOLID", GuideStyle::SOLID)
    .value("DASHED", GuideStyle::DASHED)
    .value("DOUBLE", GuideStyle::DOUBLE);

  enum_<CurrentLineRenderMode>("CurrentLineRenderMode")
    .value("BACKGROUND", CurrentLineRenderMode::BACKGROUND)
    .value("BORDER", CurrentLineRenderMode::BORDER)
    .value("NONE", CurrentLineRenderMode::NONE);

  enum_<ScrollbarMode>("ScrollbarMode")
    .value("ALWAYS", ScrollbarMode::ALWAYS)
    .value("TRANSIENT", ScrollbarMode::TRANSIENT)
    .value("NEVER", ScrollbarMode::NEVER);

  enum_<ScrollbarTrackTapMode>("ScrollbarTrackTapMode")
    .value("JUMP", ScrollbarTrackTapMode::JUMP)
    .value("DISABLED", ScrollbarTrackTapMode::DISABLED);

  value_object<TextPosition>("TextPosition").field("line", &TextPosition::line).field("column", &TextPosition::column);
  value_object<TextRange>("TextRange").field("start", &TextRange::start).field("end", &TextRange::end);
  value_object<PointF>("PointF").field("x", &PointF::x).field("y", &PointF::y);
  value_object<OffsetRect>("OffsetRect")
    .field("left", &OffsetRect::left).field("top", &OffsetRect::top)
    .field("right", &OffsetRect::right).field("bottom", &OffsetRect::bottom);
  value_object<Viewport>("Viewport").field("width", &Viewport::width).field("height", &Viewport::height);
  value_object<ViewState>("ViewState")
    .field("scale", &ViewState::scale).field("scroll_x", &ViewState::scroll_x).field("scroll_y", &ViewState::scroll_y);
  value_object<KeyEvent>("KeyEvent")
    .field("key_code", &KeyEvent::key_code).field("text", &KeyEvent::text).field("modifiers", &KeyEvent::modifiers);

  value_object<TouchConfig>("TouchConfig")
    .field("touch_slop", &TouchConfig::touch_slop)
    .field("double_tap_timeout", &TouchConfig::double_tap_timeout)
    .field("long_press_ms", &TouchConfig::long_press_ms);

  value_object<GestureEvent>("GestureEvent")
    .field("type", &GestureEvent::type).field("points", &GestureEvent::points).field("modifiers", &GestureEvent::modifiers)
    .field("wheel_delta_x", &GestureEvent::wheel_delta_x).field("wheel_delta_y", &GestureEvent::wheel_delta_y)
    .field("direct_scale", &GestureEvent::direct_scale);

  value_object<HitTarget>("HitTarget")
    .field("type", &HitTarget::type).field("line", &HitTarget::line).field("column", &HitTarget::column)
    .field("icon_id", &HitTarget::icon_id).field("color_value", &HitTarget::color_value);

  value_object<GestureResult>("GestureResult")
    .field("type", &GestureResult::type).field("tap_point", &GestureResult::tap_point)
    .field("scale", &GestureResult::scale).field("scroll_x", &GestureResult::scroll_x).field("scroll_y", &GestureResult::scroll_y)
    .field("modifiers", &GestureResult::modifiers).field("cursor_position", &GestureResult::cursor_position)
    .field("has_selection", &GestureResult::has_selection).field("selection", &GestureResult::selection)
    .field("view_scroll_x", &GestureResult::view_scroll_x).field("view_scroll_y", &GestureResult::view_scroll_y)
    .field("view_scale", &GestureResult::view_scale).field("hit_target", &GestureResult::hit_target)
    .field("needs_edge_scroll", &GestureResult::needs_edge_scroll);

  value_object<FontMetrics>("FontMetrics").field("ascent", &FontMetrics::ascent).field("descent", &FontMetrics::descent);

  value_object<TextStyle>("TextStyle")
    .field("color", &TextStyle::color).field("background_color", &TextStyle::background_color).field("font_style", &TextStyle::font_style);
  value_object<StyleSpan>("StyleSpan").field("column", &StyleSpan::column).field("length", &StyleSpan::length).field("style_id", &StyleSpan::style_id);
  value_object<InlayHint>("InlayHint")
    .field("type", &InlayHint::type).field("column", &InlayHint::column).field("text", &InlayHint::text)
    .field("icon_id", &InlayHint::icon_id).field("color", &InlayHint::color);
  value_object<PhantomText>("PhantomText").field("column", &PhantomText::column).field("text", &PhantomText::text);
  value_object<GutterIcon>("GutterIcon").field("icon_id", &GutterIcon::icon_id);
  value_object<DiagnosticSpan>("DiagnosticSpan")
    .field("column", &DiagnosticSpan::column).field("length", &DiagnosticSpan::length)
    .field("severity", &DiagnosticSpan::severity).field("color", &DiagnosticSpan::color);
  value_object<FoldRegion>("FoldRegion").field("start_line", &FoldRegion::start_line).field("end_line", &FoldRegion::end_line).field("collapsed", &FoldRegion::collapsed);
  value_object<IndentGuide>("IndentGuide").field("start", &IndentGuide::start).field("end", &IndentGuide::end);
  value_object<BracketGuide>("BracketGuide").field("parent", &BracketGuide::parent).field("end", &BracketGuide::end).field("children", &BracketGuide::children);
  value_object<FlowGuide>("FlowGuide").field("start", &FlowGuide::start).field("end", &FlowGuide::end);
  value_object<SeparatorGuide>("SeparatorGuide")
    .field("line", &SeparatorGuide::line).field("style", &SeparatorGuide::style)
    .field("count", &SeparatorGuide::count).field("text_end_column", &SeparatorGuide::text_end_column);

  value_object<VisualRun>("VisualRun")
    .field("type", &VisualRun::type).field("column", &VisualRun::column).field("length", &VisualRun::length)
    .field("x", &VisualRun::x).field("y", &VisualRun::y).field("text", &VisualRun::text).field("style", &VisualRun::style)
    .field("icon_id", &VisualRun::icon_id).field("color_value", &VisualRun::color_value)
    .field("width", &VisualRun::width).field("padding", &VisualRun::padding).field("margin", &VisualRun::margin);
  value_object<VisualLine>("VisualLine")
    .field("logical_line", &VisualLine::logical_line).field("wrap_index", &VisualLine::wrap_index)
    .field("line_number_position", &VisualLine::line_number_position).field("runs", &VisualLine::runs)
    .field("is_phantom_line", &VisualLine::is_phantom_line).field("fold_state", &VisualLine::fold_state);

  value_object<Cursor>("Cursor")
    .field("text_position", &Cursor::text_position).field("position", &Cursor::position)
    .field("height", &Cursor::height).field("visible", &Cursor::visible).field("show_dragger", &Cursor::show_dragger);
  value_object<SelectionRect>("SelectionRect").field("origin", &SelectionRect::origin).field("width", &SelectionRect::width).field("height", &SelectionRect::height);
  value_object<SelectionHandle>("SelectionHandle")
    .field("position", &SelectionHandle::position).field("height", &SelectionHandle::height).field("visible", &SelectionHandle::visible);

  value_object<GuideSegment>("GuideSegment")
    .field("direction", &GuideSegment::direction).field("type", &GuideSegment::type).field("style", &GuideSegment::style)
    .field("start", &GuideSegment::start).field("end", &GuideSegment::end).field("arrow_end", &GuideSegment::arrow_end);
  value_object<CompositionDecoration>("CompositionDecoration")
    .field("active", &CompositionDecoration::active).field("origin", &CompositionDecoration::origin)
    .field("width", &CompositionDecoration::width).field("height", &CompositionDecoration::height);
  value_object<DiagnosticDecoration>("DiagnosticDecoration")
    .field("origin", &DiagnosticDecoration::origin).field("width", &DiagnosticDecoration::width)
    .field("height", &DiagnosticDecoration::height).field("severity", &DiagnosticDecoration::severity).field("color", &DiagnosticDecoration::color);
  value_object<BracketHighlightRect>("BracketHighlightRect")
    .field("origin", &BracketHighlightRect::origin).field("width", &BracketHighlightRect::width).field("height", &BracketHighlightRect::height);
  value_object<GutterIconRenderItem>("GutterIconRenderItem")
    .field("logical_line", &GutterIconRenderItem::logical_line).field("icon_id", &GutterIconRenderItem::icon_id)
    .field("origin", &GutterIconRenderItem::origin).field("width", &GutterIconRenderItem::width).field("height", &GutterIconRenderItem::height);
  value_object<FoldMarkerRenderItem>("FoldMarkerRenderItem")
    .field("logical_line", &FoldMarkerRenderItem::logical_line).field("fold_state", &FoldMarkerRenderItem::fold_state)
    .field("origin", &FoldMarkerRenderItem::origin).field("width", &FoldMarkerRenderItem::width).field("height", &FoldMarkerRenderItem::height);
  value_object<LinkedEditingRect>("LinkedEditingRect")
    .field("origin", &LinkedEditingRect::origin).field("width", &LinkedEditingRect::width)
    .field("height", &LinkedEditingRect::height).field("is_active", &LinkedEditingRect::is_active);

  value_object<ScrollbarRect>("ScrollbarRect").field("origin", &ScrollbarRect::origin).field("width", &ScrollbarRect::width).field("height", &ScrollbarRect::height);
  value_object<ScrollbarModel>("ScrollbarModel")
    .field("visible", &ScrollbarModel::visible).field("alpha", &ScrollbarModel::alpha)
    .field("track", &ScrollbarModel::track).field("thumb", &ScrollbarModel::thumb);

  value_object<EditorRenderModel>("EditorRenderModel")
    .field("split_x", &EditorRenderModel::split_x)
    .field("split_line_visible", &EditorRenderModel::split_line_visible)
    .field("scroll_x", &EditorRenderModel::scroll_x)
    .field("scroll_y", &EditorRenderModel::scroll_y)
    .field("viewport_width", &EditorRenderModel::viewport_width)
    .field("viewport_height", &EditorRenderModel::viewport_height)
    .field("current_line", &EditorRenderModel::current_line)
    .field("current_line_render_mode", &EditorRenderModel::current_line_render_mode)
    .field("lines", &EditorRenderModel::lines)
    .field("cursor", &EditorRenderModel::cursor)
    .field("selection_rects", &EditorRenderModel::selection_rects)
    .field("selection_start_handle", &EditorRenderModel::selection_start_handle)
    .field("selection_end_handle", &EditorRenderModel::selection_end_handle)
    .field("composition_decoration", &EditorRenderModel::composition_decoration)
    .field("guide_segments", &EditorRenderModel::guide_segments)
    .field("diagnostic_decorations", &EditorRenderModel::diagnostic_decorations)
    .field("max_gutter_icons", &EditorRenderModel::max_gutter_icons)
    .field("linked_editing_rects", &EditorRenderModel::linked_editing_rects)
    .field("bracket_highlight_rects", &EditorRenderModel::bracket_highlight_rects)
    .field("gutter_icons", &EditorRenderModel::gutter_icons)
    .field("fold_markers", &EditorRenderModel::fold_markers)
    .field("vertical_scrollbar", &EditorRenderModel::vertical_scrollbar)
    .field("horizontal_scrollbar", &EditorRenderModel::horizontal_scrollbar);

  value_object<LayoutMetrics>("LayoutMetrics")
    .field("font_height", &LayoutMetrics::font_height).field("font_ascent", &LayoutMetrics::font_ascent)
    .field("line_spacing_add", &LayoutMetrics::line_spacing_add).field("line_spacing_mult", &LayoutMetrics::line_spacing_mult)
    .field("line_number_margin", &LayoutMetrics::line_number_margin).field("line_number_width", &LayoutMetrics::line_number_width)
    .field("content_start_padding", &LayoutMetrics::content_start_padding).field("max_gutter_icons", &LayoutMetrics::max_gutter_icons)
    .field("inlay_hint_padding", &LayoutMetrics::inlay_hint_padding).field("inlay_hint_margin", &LayoutMetrics::inlay_hint_margin)
    .field("fold_arrow_mode", &LayoutMetrics::fold_arrow_mode).field("has_fold_regions", &LayoutMetrics::has_fold_regions);

  value_object<BracketPair>("BracketPair")
    .field("open", &BracketPair::open).field("close", &BracketPair::close)
    .field("auto_close", &BracketPair::auto_close).field("surround", &BracketPair::surround);

  value_object<EditorOptions>("EditorOptions")
    .field("touch_slop", &EditorOptions::touch_slop).field("double_tap_timeout", &EditorOptions::double_tap_timeout)
    .field("long_press_ms", &EditorOptions::long_press_ms).field("max_undo_stack_size", &EditorOptions::max_undo_stack_size);

  value_object<HandleConfig>("HandleConfig").field("start_hit_offset", &HandleConfig::start_hit_offset).field("end_hit_offset", &HandleConfig::end_hit_offset);
  value_object<ScrollbarConfig>("ScrollbarConfig")
    .field("thickness", &ScrollbarConfig::thickness).field("min_thumb", &ScrollbarConfig::min_thumb)
    .field("thumb_hit_padding", &ScrollbarConfig::thumb_hit_padding).field("mode", &ScrollbarConfig::mode)
    .field("thumb_draggable", &ScrollbarConfig::thumb_draggable).field("track_tap_mode", &ScrollbarConfig::track_tap_mode)
    .field("fade_delay_ms", &ScrollbarConfig::fade_delay_ms).field("fade_duration_ms", &ScrollbarConfig::fade_duration_ms);

  value_object<EditorSettings>("EditorSettings")
    .field("max_scale", &EditorSettings::max_scale).field("read_only", &EditorSettings::read_only)
    .field("auto_indent_mode", &EditorSettings::auto_indent_mode).field("enable_composition", &EditorSettings::enable_composition)
    .field("handle", &EditorSettings::handle).field("scrollbar", &EditorSettings::scrollbar)
    .field("content_start_padding", &EditorSettings::content_start_padding).field("show_split_line", &EditorSettings::show_split_line)
    .field("current_line_render_mode", &EditorSettings::current_line_render_mode);

  value_object<ScrollMetrics>("ScrollMetrics")
    .field("scale", &ScrollMetrics::scale).field("scroll_x", &ScrollMetrics::scroll_x).field("scroll_y", &ScrollMetrics::scroll_y)
    .field("max_scroll_x", &ScrollMetrics::max_scroll_x).field("max_scroll_y", &ScrollMetrics::max_scroll_y)
    .field("content_width", &ScrollMetrics::content_width).field("content_height", &ScrollMetrics::content_height)
    .field("viewport_width", &ScrollMetrics::viewport_width).field("viewport_height", &ScrollMetrics::viewport_height)
    .field("text_area_x", &ScrollMetrics::text_area_x).field("text_area_width", &ScrollMetrics::text_area_width)
    .field("can_scroll_x", &ScrollMetrics::can_scroll_x).field("can_scroll_y", &ScrollMetrics::can_scroll_y);

  value_object<TextChange>("TextChange").field("range", &TextChange::range).field("old_text", &TextChange::old_text).field("new_text", &TextChange::new_text);
  value_object<TextEditResult>("TextEditResult")
    .field("changed", &TextEditResult::changed).field("changes", &TextEditResult::changes)
    .field("cursor_before", &TextEditResult::cursor_before).field("cursor_after", &TextEditResult::cursor_after);
  value_object<KeyEventResult>("KeyEventResult")
    .field("handled", &KeyEventResult::handled).field("content_changed", &KeyEventResult::content_changed)
    .field("cursor_changed", &KeyEventResult::cursor_changed).field("selection_changed", &KeyEventResult::selection_changed)
    .field("edit_result", &KeyEventResult::edit_result);
  value_object<CompositionState>("CompositionState")
    .field("is_composing", &CompositionState::is_composing).field("start_position", &CompositionState::start_position)
    .field("composing_text", &CompositionState::composing_text).field("composing_columns", &CompositionState::composing_columns);
  value_object<CursorRect>("CursorRect").field("x", &CursorRect::x).field("y", &CursorRect::y).field("height", &CursorRect::height);

  value_object<LogicalLine>("LogicalLine")
    .field("start_byte", &LogicalLine::start_byte).field("start_char", &LogicalLine::start_char).field("cached_text", &LogicalLine::cached_text)
    .field("is_char_dirty", &LogicalLine::is_char_dirty).field("line_ending", &LogicalLine::line_ending)
    .field("start_y", &LogicalLine::start_y).field("height", &LogicalLine::height)
    .field("visual_lines", &LogicalLine::visual_lines).field("is_layout_dirty", &LogicalLine::is_layout_dirty).field("is_fold_hidden", &LogicalLine::is_fold_hidden);

  value_object<TabStopGroup>("TabStopGroup")
    .field("index", &TabStopGroup::index).field("ranges", &TabStopGroup::ranges).field("default_text", &TabStopGroup::default_text);
  value_object<LinkedEditingModel>("LinkedEditingModel").field("groups", &LinkedEditingModel::groups);

  value_object<LineStyleSpansEntry>("LineStyleSpansEntry").field("line", &LineStyleSpansEntry::line).field("spans", &LineStyleSpansEntry::spans);
  value_object<LineInlayHintsEntry>("LineInlayHintsEntry").field("line", &LineInlayHintsEntry::line).field("hints", &LineInlayHintsEntry::hints);
  value_object<LinePhantomTextsEntry>("LinePhantomTextsEntry").field("line", &LinePhantomTextsEntry::line).field("phantoms", &LinePhantomTextsEntry::phantoms);
  value_object<LineGutterIconsEntry>("LineGutterIconsEntry").field("line", &LineGutterIconsEntry::line).field("icons", &LineGutterIconsEntry::icons);
  value_object<LineDiagnosticsEntry>("LineDiagnosticsEntry").field("line", &LineDiagnosticsEntry::line).field("diagnostics", &LineDiagnosticsEntry::diagnostics);

  function("editorRenderModelDump", &editorRenderModelDump);
  function("editorRenderModelToJson", &editorRenderModelToJson);
  function("layoutMetricsGutterWidth", &layoutMetricsGutterWidth);
  function("layoutMetricsTextAreaX", &layoutMetricsTextAreaX);
  function("layoutMetricsToJson", &layoutMetricsToJson);
  function("editorOptionsDump", &editorOptionsDump);
  function("editorSettingsDump", &editorSettingsDump);

  register_vector<PointF>("PointFVector");
  register_vector<TextPosition>("TextPositionVector");
  register_vector<TextRange>("TextRangeVector");
  register_vector<StyleSpan>("StyleSpanVector");
  register_vector<InlayHint>("InlayHintVector");
  register_vector<PhantomText>("PhantomTextVector");
  register_vector<GutterIcon>("GutterIconVector");
  register_vector<DiagnosticSpan>("DiagnosticSpanVector");
  register_vector<FoldRegion>("FoldRegionVector");
  register_vector<IndentGuide>("IndentGuideVector");
  register_vector<BracketGuide>("BracketGuideVector");
  register_vector<FlowGuide>("FlowGuideVector");
  register_vector<SeparatorGuide>("SeparatorGuideVector");
  register_vector<VisualRun>("VisualRunVector");
  register_vector<VisualLine>("VisualLineVector");
  register_vector<SelectionRect>("SelectionRectVector");
  register_vector<GuideSegment>("GuideSegmentVector");
  register_vector<DiagnosticDecoration>("DiagnosticDecorationVector");
  register_vector<BracketHighlightRect>("BracketHighlightRectVector");
  register_vector<GutterIconRenderItem>("GutterIconRenderItemVector");
  register_vector<FoldMarkerRenderItem>("FoldMarkerRenderItemVector");
  register_vector<LinkedEditingRect>("LinkedEditingRectVector");
  register_vector<TextChange>("TextChangeVector");
  register_vector<LogicalLine>("LogicalLineVector");
  register_vector<TabStopGroup>("TabStopGroupVector");
  register_vector<BracketPair>("BracketPairVector");
  register_vector<LineStyleSpansEntry>("LineStyleSpansEntryVector");
  register_vector<LineInlayHintsEntry>("LineInlayHintsEntryVector");
  register_vector<LinePhantomTextsEntry>("LinePhantomTextsEntryVector");
  register_vector<LineGutterIconsEntry>("LineGutterIconsEntryVector");
  register_vector<LineDiagnosticsEntry>("LineDiagnosticsEntryVector");

  class_<TextStyleRegistry>("TextStyleRegistry")
    .smart_ptr<Ptr<TextStyleRegistry>>("TextStyleRegistry")
    .function("registerTextStyle", optional_override([](TextStyleRegistry& registry, uint32_t style_id, const TextStyle& style) {
      auto copy = style;
      registry.registerTextStyle(style_id, std::move(copy));
    }))
    .function("getStyle", &registryGetStyle);

  class_<Document>("Document")
    .smart_ptr<Ptr<Document>>("Document")
    .function("getU8Text", optional_override([](Document& document) { return document.getU8Text(); }))
    .function("getU8Text", optional_override([](Document& document, const TextRange& range) { return document.getU8Text(range); }))
    .function("getU16Text", &Document::getU16Text)
    .function("getLineCount", &Document::getLineCount)
    .function("getLineU16Text", &Document::getLineU16Text)
    .function("getLineColumns", &Document::getLineColumns)
    .function("getPositionFromCharIndex", &Document::getPositionFromCharIndex)
    .function("getCharIndexFromPosition", &Document::getCharIndexFromPosition)
    .function("insertU8Text", &Document::insertU8Text)
    .function("deleteU8Text", &Document::deleteU8Text)
    .function("replaceU8Text", &Document::replaceU8Text)
    .function("countChars", &Document::countChars)
    .function("getLogicalLines", &Document::getLogicalLines, return_value_policy::reference())
    .function("updateDirtyLine", &Document::updateDirtyLine);

  class_<LineArrayDocument, base<Document>>("LineArrayDocument")
    .smart_ptr_constructor("LineArrayDocument", &createLineArrayDocument);

  class_<PieceTableDocument, base<Document>>("PieceTableDocument")
    .smart_ptr_constructor("PieceTableDocument", &createPieceTableDocument);

  class_<EditorCore>("EditorCore")
    .smart_ptr_constructor("EditorCore", &createEditorCore)
    .function("setHandleConfig", &EditorCore::setHandleConfig)
    .function("setScrollbarConfig", &EditorCore::setScrollbarConfig)
    .function("loadDocument", &EditorCore::loadDocument)
    .function("setViewport", &EditorCore::setViewport)
    .function("onFontMetricsChanged", &EditorCore::onFontMetricsChanged)
    .function("setWrapMode", &EditorCore::setWrapMode)
    .function("setScale", &EditorCore::setScale)
    .function("setFoldArrowMode", &EditorCore::setFoldArrowMode)
    .function("setLineSpacing", &EditorCore::setLineSpacing)
    .function("setContentStartPadding", &EditorCore::setContentStartPadding)
    .function("setShowSplitLine", &EditorCore::setShowSplitLine)
    .function("setCurrentLineRenderMode", &EditorCore::setCurrentLineRenderMode)
    .function("getTextStyleRegistry", &EditorCore::getTextStyleRegistry)
    .function("buildRenderModel", &editorBuildRenderModel)
    .function("getViewState", &EditorCore::getViewState)
    .function("getScrollMetrics", &EditorCore::getScrollMetrics)
    .function("getLayoutMetrics", &editorGetLayoutMetrics)
    .function("handleGestureEvent", &EditorCore::handleGestureEvent)
    .function("handleGestureEventRaw", &editorHandleGestureEventRaw)
    .function("tickEdgeScroll", &EditorCore::tickEdgeScroll)
    .function("handleKeyEvent", &EditorCore::handleKeyEvent)
    .function("handleKeyEventRaw", &editorHandleKeyEventRaw)
    .function("insertText", &EditorCore::insertText)
    .function("replaceText", &EditorCore::replaceText)
    .function("deleteText", &EditorCore::deleteText)
    .function("backspace", &EditorCore::backspace)
    .function("deleteForward", &EditorCore::deleteForward)
    .function("moveLineUp", &EditorCore::moveLineUp)
    .function("moveLineDown", &EditorCore::moveLineDown)
    .function("copyLineUp", &EditorCore::copyLineUp)
    .function("copyLineDown", &EditorCore::copyLineDown)
    .function("deleteLine", &EditorCore::deleteLine)
    .function("insertLineAbove", &EditorCore::insertLineAbove)
    .function("insertLineBelow", &EditorCore::insertLineBelow)
    .function("undo", &EditorCore::undo)
    .function("redo", &EditorCore::redo)
    .function("canUndo", &EditorCore::canUndo)
    .function("canRedo", &EditorCore::canRedo)
    .function("setCursorPosition", &EditorCore::setCursorPosition)
    .function("getCursorPosition", &EditorCore::getCursorPosition)
    .function("setSelection", &EditorCore::setSelection)
    .function("getSelection", &EditorCore::getSelection)
    .function("hasSelection", &EditorCore::hasSelection)
    .function("clearSelection", &EditorCore::clearSelection)
    .function("selectAll", &EditorCore::selectAll)
    .function("getSelectedText", &EditorCore::getSelectedText)
    .function("getWordRangeAtCursor", &EditorCore::getWordRangeAtCursor)
    .function("getWordAtCursor", &EditorCore::getWordAtCursor)
    .function("moveCursorLeft", &EditorCore::moveCursorLeft)
    .function("moveCursorRight", &EditorCore::moveCursorRight)
    .function("moveCursorUp", &EditorCore::moveCursorUp)
    .function("moveCursorDown", &EditorCore::moveCursorDown)
    .function("moveCursorToLineStart", &EditorCore::moveCursorToLineStart)
    .function("moveCursorToLineEnd", &EditorCore::moveCursorToLineEnd)
    .function("compositionStart", &EditorCore::compositionStart)
    .function("compositionUpdate", &EditorCore::compositionUpdate)
    .function("compositionEnd", &EditorCore::compositionEnd)
    .function("compositionCancel", &EditorCore::compositionCancel)
    .function("getCompositionState", &editorGetCompositionState)
    .function("isComposing", &EditorCore::isComposing)
    .function("setCompositionEnabled", &EditorCore::setCompositionEnabled)
    .function("isCompositionEnabled", &EditorCore::isCompositionEnabled)
    .function("setReadOnly", &EditorCore::setReadOnly)
    .function("isReadOnly", &EditorCore::isReadOnly)
    .function("setAutoIndentMode", &EditorCore::setAutoIndentMode)
    .function("getAutoIndentMode", &EditorCore::getAutoIndentMode)
    .function("getPositionScreenRect", &EditorCore::getPositionScreenRect)
    .function("getCursorScreenRect", &EditorCore::getCursorScreenRect)
    .function("insertSnippet", &EditorCore::insertSnippet)
    .function("startLinkedEditing", &editorStartLinkedEditing)
    .function("isInLinkedEditing", &EditorCore::isInLinkedEditing)
    .function("linkedEditingNextTabStop", &EditorCore::linkedEditingNextTabStop)
    .function("linkedEditingPrevTabStop", &EditorCore::linkedEditingPrevTabStop)
    .function("cancelLinkedEditing", &EditorCore::cancelLinkedEditing)
    .function("finishLinkedEditing", &EditorCore::finishLinkedEditing)
    .function("scrollToLine", &EditorCore::scrollToLine)
    .function("gotoPosition", &EditorCore::gotoPosition)
    .function("setScroll", &EditorCore::setScroll)
    .function("registerTextStyle", &editorRegisterTextStyle)
    .function("setLineSpans", &editorSetLineSpans)
    .function("setBatchLineSpans", &editorSetBatchLineSpans)
    .function("setLineInlayHints", &editorSetLineInlayHints)
    .function("setBatchLineInlayHints", &editorSetBatchLineInlayHints)
    .function("setLinePhantomTexts", &editorSetLinePhantomTexts)
    .function("setBatchLinePhantomTexts", &editorSetBatchLinePhantomTexts)
    .function("setLineGutterIcons", &editorSetLineGutterIcons)
    .function("setBatchLineGutterIcons", &editorSetBatchLineGutterIcons)
    .function("setMaxGutterIcons", &EditorCore::setMaxGutterIcons)
    .function("setLineDiagnostics", &editorSetLineDiagnostics)
    .function("setBatchLineDiagnostics", &editorSetBatchLineDiagnostics)
    .function("clearDiagnostics", &EditorCore::clearDiagnostics)
    .function("setIndentGuides", &editorSetIndentGuides)
    .function("setBracketGuides", &editorSetBracketGuides)
    .function("setFlowGuides", &editorSetFlowGuides)
    .function("setSeparatorGuides", &editorSetSeparatorGuides)
    .function("setFoldRegions", &editorSetFoldRegions)
    .function("foldAt", &EditorCore::foldAt)
    .function("unfoldAt", &EditorCore::unfoldAt)
    .function("toggleFoldAt", &EditorCore::toggleFoldAt)
    .function("foldAll", &EditorCore::foldAll)
    .function("unfoldAll", &EditorCore::unfoldAll)
    .function("isLineVisible", &EditorCore::isLineVisible)
    .function("clearHighlights", optional_override([](EditorCore& editor, SpanLayer layer) { editor.clearHighlights(layer); }))
    .function("clearHighlights", optional_override([](EditorCore& editor) { editor.clearHighlights(); }))
    .function("clearInlayHints", &EditorCore::clearInlayHints)
    .function("clearPhantomTexts", &EditorCore::clearPhantomTexts)
    .function("clearGutterIcons", &EditorCore::clearGutterIcons)
    .function("clearGuides", &EditorCore::clearGuides)
    .function("clearAllDecorations", &EditorCore::clearAllDecorations)
    .function("setBracketPairs", &editorSetBracketPairs)
    .function("setMatchedBrackets", &EditorCore::setMatchedBrackets)
    .function("clearMatchedBrackets", &EditorCore::clearMatchedBrackets);

  constant("FONT_STYLE_NORMAL", FONT_STYLE_NORMAL);
  constant("FONT_STYLE_BOLD", FONT_STYLE_BOLD);
  constant("FONT_STYLE_ITALIC", FONT_STYLE_ITALIC);
  constant("FONT_STYLE_STRIKETHROUGH", FONT_STYLE_STRIKETHROUGH);
}

} // namespace
