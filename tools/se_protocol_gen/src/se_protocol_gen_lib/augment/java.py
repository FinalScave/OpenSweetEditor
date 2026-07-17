from ..backends.java import java_domain_path
from ..ir import visible_schema_types


JAVA_MODEL_HELPERS = {
    "EditorActionResult": {
        "body_blocks": [
            {
                "sentinel": "    public boolean needsAnimation() {",
                "lines": [
                    "",
                    "    public boolean hasAnimationFlag(int flag) {",
                    "        return (animationFlags & flag) != 0;",
                    "    }",
                    "",
                    "    public boolean needsAnimation() {",
                    "        return animationFlags != AnimationFlag.NONE;",
                    "    }",
                    "",
                    "    public boolean needsViewportMotion() {",
                    "        return hasAnimationFlag(AnimationFlag.EDGE_SCROLL)",
                    "                || hasAnimationFlag(AnimationFlag.FLING);",
                    "    }",
                    "",
                    "    public boolean hasInteractionFlag(int flag) {",
                    "        return (interactionFlags & flag) != 0;",
                    "    }",
                    "",
                    "    public boolean hasActiveInteraction() {",
                    "        return interactionFlags != InteractionFlag.NONE;",
                    "    }",
                ],
            },
        ],
    },
    "TextPosition": {
        "static_members": [
            "    public static final TextPosition NONE = new TextPosition();",
        ],
        "body_blocks": [
            {
                "sentinel": "    public String toString() {",
                "lines": [
                    "",
                    "    @Override",
                    "    public String toString() {",
                    '        return "TextPosition{"',
                    '                + "line=" + line',
                    '                + ", column=" + column',
                    '                + "}";',
                    "    }",
                ],
            },
        ],
    },
    "TextRange": {
        "body_blocks": [
            {
                "sentinel": "    public boolean isCollapsed() {",
                "lines": [
                    "",
                    "    public boolean isCollapsed() {",
                    "        return start.line == end.line && start.column == end.column;",
                    "    }",
                ],
            },
            {
                "sentinel": "    public String toString() {",
                "lines": [
                    "",
                    "    @Override",
                    "    public String toString() {",
                    '        return "TextRange{"',
                    '                + "start=" + start',
                    '                + ", end=" + end',
                    '                + "}";',
                    "    }",
                ],
            },
        ],
    },
    "IntRange": {
        "body_blocks": [
            {
                "sentinel": "    public boolean isEmpty() {",
                "lines": [
                    "",
                    "    public boolean isEmpty() {",
                    "        return end < start;",
                    "    }",
                    "",
                    "    public boolean contains(int value) {",
                    "        return !isEmpty() && value >= start && value <= end;",
                    "    }",
                    "",
                    "    public int length() {",
                    "        return isEmpty() ? 0 : (end - start + 1);",
                    "    }",
                ],
            },
            {
                "sentinel": "    public String toString() {",
                "lines": [
                    "",
                    "    @Override",
                    "    public String toString() {",
                    '        return "IntRange{"',
                    '                + "start=" + start',
                    '                + ", end=" + end',
                    '                + "}";',
                    "    }",
                ],
            },
        ],
    },
    "CursorRect": {
        "body_blocks": [
            {
                "sentinel": "    public String toString() {",
                "lines": [
                    "",
                    "    @Override",
                    "    public String toString() {",
                    '        return "CursorRect{"',
                    '                + "x=" + x',
                    '                + ", y=" + y',
                    '                + ", height=" + height',
                    '                + "}";',
                    "    }",
                ],
            },
        ],
    },
    "KeyChord": {
        "imports": ["java.util.Objects"],
        "static_members": [
            "    public static final KeyChord EMPTY = new KeyChord(KeyModifier.NONE, KeyCode.NONE);",
        ],
        "body_blocks": [
            {
                "sentinel": "    public boolean empty() {",
                "lines": [
                    "",
                    "    public boolean empty() {",
                    "        return keyCode == KeyCode.NONE;",
                    "    }",
                ],
            },
            {
                "sentinel": "    public boolean equals(Object obj) {",
                "lines": [
                    "",
                    "    @Override",
                    "    public boolean equals(Object obj) {",
                    "        if (this == obj) return true;",
                    "        if (!(obj instanceof KeyChord)) return false;",
                    "        KeyChord other = (KeyChord) obj;",
                    "        return modifiers == other.modifiers && keyCode == other.keyCode;",
                    "    }",
                    "",
                    "    @Override",
                    "    public int hashCode() {",
                    "        return Objects.hash(modifiers, keyCode);",
                    "    }",
                ],
            },
        ],
    },
    "TextStyle": {
        "static_members": [
            "    public static final int NORMAL = 0;",
            "    public static final int BOLD = 1;",
            "    public static final int ITALIC = 2;",
            "    public static final int STRIKETHROUGH = 4;",
        ],
        "body_blocks": [
            {
                "sentinel": "    public TextStyle(int color, int fontStyle) {",
                "lines": [
                    "",
                    "    public TextStyle(int color, int fontStyle) {",
                    "        this(color, 0, fontStyle);",
                    "    }",
                ],
            },
        ],
    },
    "KeyBinding": {
        "imports": ["java.util.Objects"],
        "body_blocks": [
            {
                "sentinel": "    public KeyBinding(KeyChord first, int command) {",
                "lines": [
                    "",
                    "    public KeyBinding(KeyChord first, int command) {",
                    "        this(first, KeyChord.EMPTY, command);",
                    "    }",
                    "",
                    "    public KeyBinding(int modifiers, int keyCode, int command) {",
                    "        this(new KeyChord(modifiers, keyCode), KeyChord.EMPTY, command);",
                    "    }",
                    "",
                    "    public KeyBinding(int firstModifiers, int firstKeyCode,",
                    "                      int secondModifiers, int secondKeyCode, int command) {",
                    "        this(new KeyChord(firstModifiers, firstKeyCode),",
                    "                new KeyChord(secondModifiers, secondKeyCode), command);",
                    "    }",
                ],
            },
            {
                "sentinel": "    public boolean equals(Object obj) {",
                "lines": [
                    "",
                    "    @Override",
                    "    public boolean equals(Object obj) {",
                    "        if (this == obj) return true;",
                    "        if (!(obj instanceof KeyBinding)) return false;",
                    "        KeyBinding other = (KeyBinding) obj;",
                    "        return command == other.command",
                    "                && Objects.equals(first, other.first)",
                    "                && Objects.equals(second, other.second);",
                    "    }",
                    "",
                    "    @Override",
                    "    public int hashCode() {",
                    "        return Objects.hash(first, second, command);",
                    "    }",
                ],
            },
        ],
    },
    "InlayHint": {
        "body_blocks": [
            {
                "sentinel": "    public static InlayHint text(int column, String text) {",
                "lines": [
                    "",
                    "    public static InlayHint text(int column, String text) {",
                    '        return new InlayHint(InlayType.TEXT, column, 0, text != null ? text : "");',
                    "    }",
                    "",
                    "    public static InlayHint icon(int column, int iconId) {",
                    '        return new InlayHint(InlayType.ICON, column, iconId, "");',
                    "    }",
                    "",
                    "    public static InlayHint color(int column, int color) {",
                    '        return new InlayHint(InlayType.COLOR, column, color, "");',
                    "    }",
                ],
            },
        ],
    },
    "FoldRegion": {
        "body_blocks": [
            {
                "sentinel": "    public FoldRegion(int startLine, int endLine) {",
                "lines": [
                    "",
                    "    public FoldRegion(int startLine, int endLine) {",
                    "        this(startLine, endLine, false);",
                    "    }",
                ],
            },
        ],
    },
    "SeparatorGuide": {
        "body_blocks": [
            {
                "sentinel": "    public SeparatorGuide(int line, int style, int count, int textEndColumn) {",
                "lines": [
                    "",
                    "    public SeparatorGuide(int line, int style, int count, int textEndColumn) {",
                    "        this(line, SeparatorStyle.fromValue(style), count, textEndColumn);",
                    "    }",
                ],
            },
        ],
    },
    "Diagnostic": {
        "body_blocks": [
            {
                "sentinel": "    public Diagnostic(int column, int length, int severity) {",
                "lines": [
                    "",
                    "    public Diagnostic(int column, int length, int severity) {",
                    "        this(column, length, DiagnosticSeverity.fromValue(severity));",
                    "    }",
                ],
            },
        ],
    },
}


def config_bool(value):
    return str(value).strip().lower() in ("1", "true", "yes", "on")


def java_model_helpers_enabled(target):
    return config_bool(target.get("augment", {}).get("java_model_helpers", "false"))


def ensure_import(text, import_name):
    import_line = f"import {import_name};"
    if import_line in text:
        return text
    lines = text.split("\n")
    package_index = next((index for index, line in enumerate(lines) if line.startswith("package ")), None)
    if package_index is None:
        raise SystemExit(f"Cannot augment Java file without package line for import {import_name}")
    import_indexes = [index for index, line in enumerate(lines) if line.startswith("import ")]
    if import_indexes:
        start = min(import_indexes)
        end = max(import_indexes)
        imports = sorted(set(lines[start:end + 1] + [import_line]))
        lines[start:end + 1] = imports
        return "\n".join(lines)
    insert_index = package_index + 1
    if insert_index < len(lines) and lines[insert_index] == "":
        insert_index += 1
    lines[insert_index:insert_index] = [import_line, ""]
    return "\n".join(lines)


def insert_static_members(text, class_name, member_lines):
    if not member_lines or member_lines[0] in text:
        return text
    lines = text.split("\n")
    marker = f"public final class {class_name} {{"
    class_index = next((index for index, line in enumerate(lines) if line == marker), None)
    if class_index is None:
        raise SystemExit(f"Cannot augment Java class {class_name}: missing class declaration")
    lines[class_index + 1:class_index + 1] = member_lines + [""]
    return "\n".join(lines)


def insert_body_block(text, class_name, block):
    block_lines = block.get("lines", [])
    sentinel = block.get("sentinel")
    if not sentinel:
        sentinel = next((line for line in block_lines if line.strip()), None)
    if not block_lines or (sentinel and sentinel in text):
        return text
    lines = text.split("\n")
    close_index = next(
        (index for index in range(len(lines) - 1, -1, -1) if lines[index] == "}"),
        None,
    )
    if close_index is None:
        raise SystemExit(f"Cannot augment Java class {class_name}: missing class close")
    lines[close_index:close_index] = block_lines
    return "\n".join(lines)


def augment_java_model_file(path, class_name, spec):
    text = path.read_text(encoding="utf-8")
    for import_name in spec.get("imports", []):
        text = ensure_import(text, import_name)
    text = insert_static_members(text, class_name, spec.get("static_members", []))
    for block in spec.get("body_blocks", []):
        text = insert_body_block(text, class_name, block)
    path.write_text(text, encoding="utf-8")


def augment_java(schema, target_name, target, out_root):
    if not java_model_helpers_enabled(target):
        return []
    items = {item["name"]: item for item in visible_schema_types(schema)}
    written = []
    for class_name, spec in JAVA_MODEL_HELPERS.items():
        item = items.get(class_name)
        if item is None:
            raise SystemExit(f"Java model helper target is missing from schema: {class_name}")
        path = out_root / java_domain_path(target, item["domain"]) / f"{class_name}.java"
        if not path.exists():
            raise SystemExit(f"Java model helper target was not generated: {path}")
        augment_java_model_file(path, class_name, spec)
        written.append(str(path))
    return written
