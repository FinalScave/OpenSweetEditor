from ..backends.dart import dart_domain_file
from ..ir import visible_schema_types


DART_MODEL_HELPERS = {
    "EditorActionResult": [
        "extension EditorActionResultAnimationHelpers on EditorActionResult {",
        "  bool hasAnimationFlag(int flag) => (animationFlags & flag) != 0;",
        "",
        "  bool get needsAnimation => animationFlags != AnimationFlag.none;",
        "",
        "  bool get needsViewportMotion =>",
        "      hasAnimationFlag(AnimationFlag.edgeScroll) ||",
        "      hasAnimationFlag(AnimationFlag.fling);",
        "}",
    ],
    "TextRange": [
        "extension TextRangeCoreHelpers on TextRange {",
        "  bool get isCollapsed => start.line == end.line && start.column == end.column;",
        "}",
    ],
    "IntRange": [
        "extension IntRangeCoreHelpers on IntRange {",
        "  bool get isEmpty => end < start;",
        "",
        "  bool contains(int value) => !isEmpty && value >= start && value <= end;",
        "",
        "  int get length => isEmpty ? 0 : (end - start + 1);",
        "}",
    ],
    "FoldMarkerRenderItem": [
        "extension FoldMarkerRenderItemRectAccess on FoldMarkerRenderItem {",
        "  PointF get origin => rect.origin;",
        "",
        "  double get width => rect.width;",
        "",
        "  double get height => rect.height;",
        "}",
    ],
    "GutterIconRenderItem": [
        "extension GutterIconRenderItemRectAccess on GutterIconRenderItem {",
        "  PointF get origin => rect.origin;",
        "",
        "  double get width => rect.width;",
        "",
        "  double get height => rect.height;",
        "}",
    ],
}


def append_extension_block(text, block):
    sentinel = next((line for line in block if line.strip().startswith("extension ")), None)
    if sentinel and sentinel in text:
        return text
    separator = "" if text.endswith("\n\n") else "\n"
    if not text.endswith("\n"):
        separator = "\n\n"
    return text + separator + "\n".join(block) + "\n"


def augment_dart_model_file(path, block):
    text = path.read_text(encoding="utf-8")
    text = append_extension_block(text, block)
    path.write_text(text, encoding="utf-8")


def augment_dart(schema, target_name, target, out_root):
    items = {item["name"]: item for item in visible_schema_types(schema)}
    written = []
    for class_name, block in DART_MODEL_HELPERS.items():
        item = items.get(class_name)
        if item is None:
            raise SystemExit(f"Dart model helper target is missing from schema: {class_name}")
        path = out_root / dart_domain_file(target, item["domain"])
        if not path.exists():
            raise SystemExit(f"Dart model helper target was not generated: {path}")
        augment_dart_model_file(path, block)
        written.append(str(path))
    return written
