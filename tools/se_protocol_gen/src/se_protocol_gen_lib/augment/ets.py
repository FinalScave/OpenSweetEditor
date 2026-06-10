from ..backends.ets import ets_default_expr, ets_default_for_field, ets_domain_file, ets_type
from ..ir import enum_map, field_name, type_map, visible_schema_types


ETS_MODEL_HELPERS = {
    "TextStyle": {
        "class": True,
        "static_members": [
            "  static readonly NORMAL: number = 0;",
            "  static readonly BOLD: number = 1;",
            "  static readonly ITALIC: number = 2;",
            "  static readonly STRIKETHROUGH: number = 4;",
        ],
    },
}


EMPTY_SEARCH_STATE_HELPER = """
export function createEmptySearchState(): SearchState {
  return {
    status: SearchStatus.INACTIVE,
    pattern: '',
    options: {
      caseSensitive: false,
      wholeWord: false,
      useRegex: false,
      wrapAround: true,
      maxMatches: 10000
    },
    generation: 0,
    matchCount: 0,
    currentIndex: -1,
    hasCurrentMatch: false,
    currentRange: {
      start: { line: 0, column: 0 },
      end: { line: 0, column: 0 }
    },
    errorMessage: ''
  };
}
""".strip()


def config_bool(value):
    return str(value).strip().lower() in ("1", "true", "yes", "on")


def ets_model_helpers_enabled(target):
    return config_bool(target.get("augment", {}).get("ets_model_helpers", "false"))


def class_source(item, schema, spec):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    lines = [f"export class {item['name']} {{"]
    static_members = spec.get("static_members", [])
    if static_members:
        lines.extend(static_members)
        lines.append("")
    for field in item["fields"]:
        type_name = ets_type(field, schema_types, schema_enums)
        default_expr = ets_default_for_field(field, type_name, schema_types, schema_enums)
        if default_expr is None:
            default_expr = ets_default_expr(type_name, schema_types, schema_enums)
        lines.append(f"  {field_name(field, 'ets')}: {type_name} = {default_expr};")
    lines.append("}")
    return lines


def replace_interface_with_class(text, item, schema, spec):
    class_name = item["name"]
    lines = text.split("\n")
    marker = f"export interface {class_name} {{"
    start_index = next((index for index, line in enumerate(lines) if line == marker), None)
    if start_index is None:
        return insert_static_members(text, class_name, spec.get("static_members", []))
    end_index = next(
        (index for index in range(start_index + 1, len(lines)) if lines[index] == "}"),
        None,
    )
    if end_index is None:
        raise SystemExit(f"Cannot augment ETS interface {class_name}: missing interface close")
    lines[start_index:end_index + 1] = class_source(item, schema, spec)
    return "\n".join(lines)


def insert_static_members(text, class_name, member_lines):
    if not member_lines or member_lines[0] in text:
        return text
    lines = text.split("\n")
    marker = f"export class {class_name} {{"
    class_index = next((index for index, line in enumerate(lines) if line == marker), None)
    if class_index is None:
        raise SystemExit(f"Cannot augment ETS class {class_name}: missing class declaration")
    lines[class_index + 1:class_index + 1] = member_lines + [""]
    return "\n".join(lines)


def augment_ets_model_file(path, item, schema, spec):
    text = path.read_text(encoding="utf-8")
    if spec.get("class", False):
        text = replace_interface_with_class(text, item, schema, spec)
    else:
        text = insert_static_members(text, item["name"], spec.get("static_members", []))
    path.write_text(text, encoding="utf-8")


def augment_ets_search_file(out_root, target):
    path = out_root / "CoreSearch.ets"
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    if "export function createEmptySearchState" in text:
        return None
    text = text.rstrip() + "\n\n" + EMPTY_SEARCH_STATE_HELPER + "\n"
    path.write_text(text, encoding="utf-8")
    return str(path)


def augment_ets(schema, target_name, target, out_root):
    if not ets_model_helpers_enabled(target):
        return []
    items = {item["name"]: item for item in visible_schema_types(schema)}
    written = []
    for class_name, spec in ETS_MODEL_HELPERS.items():
        item = items.get(class_name)
        if item is None:
            raise SystemExit(f"ETS model helper target is missing from schema: {class_name}")
        path = out_root / ets_domain_file(target, item["domain"])
        if not path.exists():
            raise SystemExit(f"ETS model helper target was not generated: {path}")
        augment_ets_model_file(path, item, schema, spec)
        written.append(str(path))
    search_path = augment_ets_search_file(out_root, target)
    if search_path is not None:
        written.append(search_path)
    return written
