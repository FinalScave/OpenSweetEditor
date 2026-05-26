import re

from .ir import infer_wire_type, map_entry_item, normalize_cpp_type, vector_inner


TYPE_MACRO_RE = re.compile(
    r"\b(?:struct|class)\s+SE_PROTOCOL_(VALUE|OUT|IN|BOTH)\(([^)]+)\)\s+([A-Za-z_]\w*)\s*\{"
)
ENUM_MACRO_RE = re.compile(
    r"\benum(?:\s+(?:class|struct))?\s+SE_PROTOCOL_(ENUM|FLAGS)\(([^)]*)\)\s+([A-Za-z_]\w*)\s*(?::\s*([^{]+))?\s*\{"
)
MACRO_RE = re.compile(
    r"\b(SE_PROTOCOL_(?:SKIP|TAIL)|SE_PROTOCOL_(?:WIRE|KEY_WIRE|VALUE_WIRE|MAP_ENTRY|NAME|AS)\([^)]*\))"
)
FIELD_RE = re.compile(r"^\s*(.+?)\s+([A-Za-z_]\w*)\s*(?:\{([^;]*)\}|=\s*([^;]*))?;\s*$")


def strip_line_comment(line):
    return line.split("//", 1)[0].rstrip()

def macro_names(line):
    found = []
    for match in MACRO_RE.finditer(line):
        text = match.group(1)
        arg = text[text.find("(") + 1:-1].strip() if "(" in text else None
        if text == "SE_PROTOCOL_SKIP":
            found.append(("skip", None))
        elif text == "SE_PROTOCOL_TAIL":
            found.append(("tail", None))
        elif text.startswith("SE_PROTOCOL_WIRE"):
            found.append(("wire", arg))
        elif text.startswith("SE_PROTOCOL_KEY_WIRE"):
            found.append(("key_wire", arg))
        elif text.startswith("SE_PROTOCOL_VALUE_WIRE"):
            found.append(("value_wire", arg))
        elif text.startswith("SE_PROTOCOL_MAP_ENTRY"):
            args = split_macro_args(arg)
            if len(args) != 2:
                raise ValueError(f"SE_PROTOCOL_MAP_ENTRY requires key and value names: {line}")
            found.append(("map_entry", {"key": args[0], "value": args[1]}))
        elif text.startswith("SE_PROTOCOL_NAME"):
            found.append(("name", arg))
        elif text.startswith("SE_PROTOCOL_AS"):
            found.append(("as", arg))
    return found

def remove_protocol_macros(line):
    return MACRO_RE.sub("", line).strip()

def parse_field(line, pending_attrs, source, line_no):
    attrs = list(pending_attrs)
    attrs.extend(macro_names(line))
    field_line = remove_protocol_macros(strip_line_comment(line))
    if not field_line or "(" in field_line:
        return None, []
    match = FIELD_RE.match(field_line)
    if not match:
        return None, attrs
    cpp_type = normalize_cpp_type(match.group(1))
    name = match.group(2)
    if any(kind == "skip" for kind, _ in attrs):
        return None, []
    wire = next((value for kind, value in attrs if kind == "wire"), None)
    key_wire = next((value for kind, value in attrs if kind == "key_wire"), None)
    value_wire = next((value for kind, value in attrs if kind == "value_wire"), None)
    map_entry = next((value for kind, value in attrs if kind == "map_entry"), None)
    platform_name = next((value for kind, value in attrs if kind == "name"), None)
    platform_type = next((value for kind, value in attrs if kind == "as"), None)
    field = {
        "name": name,
        "cpp_type": cpp_type,
        "wire": wire or infer_wire_type(cpp_type),
        "source": source,
        "line": line_no,
    }
    default_expr = match.group(3) if match.group(3) is not None else match.group(4)
    if default_expr is not None:
        field["default"] = default_expr.strip()
    if platform_name:
        field["platform_name"] = platform_name
    if platform_type:
        field["platform_type"] = platform_type
    if key_wire:
        field["key_wire"] = key_wire
    if value_wire:
        field["value_wire"] = value_wire
    if map_entry:
        field["map_entry"] = map_entry
    return field, []

def parse_struct_body(lines, start_index):
    brace_depth = lines[start_index].count("{") - lines[start_index].count("}")
    body = []
    index = start_index + 1
    while index < len(lines):
        line = lines[index]
        brace_depth += line.count("{") - line.count("}")
        if brace_depth <= 0:
            return body, index
        body.append((index + 1, line))
        index += 1
    raise ValueError(f"Unclosed protocol struct near line {start_index + 1}")

def split_macro_args(args):
    return [part.strip() for part in args.split(",") if part.strip()]

def enum_value(expr):
    normalized = expr.strip()
    normalized = re.sub(r"\b([0-9]+)[uUlL]*\b", r"\1", normalized)
    if re.fullmatch(r"[-+]?\d+", normalized):
        return int(normalized, 10)
    if re.fullmatch(r"0[xX][0-9a-fA-F]+", normalized):
        return int(normalized, 16)
    shift = re.fullmatch(r"(\d+)\s*<<\s*(\d+)", normalized)
    if shift:
        return int(shift.group(1), 10) << int(shift.group(2), 10)
    raise ValueError(f"Unsupported enum value expression: {expr}")

def parse_enum_values(body, source):
    entries = []
    current_value = -1
    text = "\n".join(strip_line_comment(line).strip() for _, line in body)
    for raw_entry in text.split(","):
        entry = raw_entry.strip()
        if not entry:
            continue
        match = re.match(r"^([A-Za-z_]\w*)\s*(?:=\s*(.+))?$", entry)
        if not match:
            continue
        name = match.group(1)
        expr = match.group(2)
        current_value = enum_value(expr) if expr is not None else current_value + 1
        entries.append({"name": name, "value": current_value})
    return entries

def parse_protocol_file(path, root):
    source = str(path.relative_to(root))
    lines = path.read_text(encoding="utf-8").splitlines()
    types = []
    enums = []
    index = 0
    while index < len(lines):
        line = lines[index]
        enum_match = ENUM_MACRO_RE.search(line)
        if enum_match:
            macro_kind = enum_match.group(1).lower()
            args = split_macro_args(enum_match.group(2))
            if macro_kind == "enum" and len(args) != 2:
                raise ValueError(f"{source}:{index + 1}: SE_PROTOCOL_ENUM requires domain and fallback")
            if macro_kind == "flags" and len(args) != 1:
                raise ValueError(f"{source}:{index + 1}: SE_PROTOCOL_FLAGS requires domain")
            domain = args[0]
            fallback = args[1] if macro_kind == "enum" else None
            name = enum_match.group(3)
            underlying_type = normalize_cpp_type(enum_match.group(4) or "")
            body, end_index = parse_struct_body(lines, index)
            values = parse_enum_values(body, source)
            enums.append({
                "name": name,
                "kind": macro_kind,
                "domain": domain,
                "fallback": fallback,
                "underlying_type": underlying_type or None,
                "source": source,
                "line": index + 1,
                "values": values,
            })
            index = end_index + 1
            continue
        type_match = TYPE_MACRO_RE.search(line)
        if not type_match:
            index += 1
            continue
        direction = type_match.group(1).lower()
        domain = type_match.group(2).strip()
        name = type_match.group(3)
        body, end_index = parse_struct_body(lines, index)
        fields = []
        pending_attrs = []
        nested_body_depth = 0
        for line_no, body_line in body:
            cleaned = strip_line_comment(body_line).strip()
            if not cleaned:
                continue
            if nested_body_depth > 0:
                nested_body_depth += cleaned.count("{") - cleaned.count("}")
                continue
            if "(" in cleaned and "{" in cleaned and not cleaned.endswith(";"):
                nested_body_depth = cleaned.count("{") - cleaned.count("}")
                continue
            attrs = macro_names(cleaned)
            if attrs and not cleaned.rstrip().endswith(";"):
                pending_attrs.extend(attrs)
                continue
            field, pending_attrs = parse_field(cleaned, pending_attrs, source, line_no)
            if field is not None:
                fields.append(field)
        types.append({
            "name": name,
            "kind": "payload" if name.endswith("Payload") else "value",
            "direction": direction,
            "domain": domain,
            "source": source,
            "line": index + 1,
            "fields": fields,
        })
        index = end_index + 1
    return types, enums

def validate_schema(schema):
    errors = []
    names = {item["name"] for item in schema["types"]}
    enum_names = {item["name"] for item in schema["enums"]}

    def validate_field(owner, field):
        if field["wire"] == "unsupported_size_t":
            errors.append(
                f"{field['source']}:{field['line']}: field {owner}.{field['name']} uses size_t without SE_PROTOCOL_WIRE"
            )
        inner = vector_inner(field["cpp_type"])
        if field["wire"] == "list" and inner is None:
            errors.append(
                f"{field['source']}:{field['line']}: field {owner}.{field['name']} uses list wire without Vector<T>"
            )
        if field["wire"] == "struct" and field["cpp_type"] not in names:
            errors.append(
                f"{field['source']}:{field['line']}: field {owner}.{field['name']} references unknown protocol type {field['cpp_type']}"
            )
        if field["wire"] == "enum_i32" and field["cpp_type"] not in enum_names:
            errors.append(
                f"{field['source']}:{field['line']}: field {owner}.{field['name']} references unannotated enum {field['cpp_type']}"
            )

    for item in schema["enums"]:
        if item["kind"] == "enum" and item["fallback"] not in {value["name"] for value in item["values"]}:
            errors.append(
                f"{item['source']}:{item['line']}: enum {item['name']} fallback {item['fallback']} is not an enum value"
            )
    for item in schema["types"]:
        for field in item["fields"]:
            validate_field(item["name"], field)
            entry_item = map_entry_item(field, schema)
            if entry_item is not None:
                for entry_field in entry_item["fields"]:
                    validate_field(f"{item['name']}.{field['name']}", entry_field)
    if errors:
        raise SystemExit("\n".join(errors))

def build_schema(root, config):
    types = []
    enums = []
    schema_config = config["schema"]
    for input_path in schema_config["inputs"]:
        file_types, file_enums = parse_protocol_file(root / input_path, root)
        types.extend(file_types)
        enums.extend(file_enums)
    schema = {
        "format": "sweeteditor.protocol.schema",
        "version": 1,
        "enums": sorted(enums, key=lambda item: (item["domain"], item["name"])),
        "types": sorted(types, key=lambda item: (item["domain"], item["name"])),
    }
    validate_schema(schema)
    return schema

