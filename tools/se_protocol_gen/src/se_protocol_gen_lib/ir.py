import re
from pathlib import Path


VECTOR_RE = re.compile(r"^(?:Vector|std::vector)<(.+)>")
PAIR_RE = re.compile(r"^(?:std::pair|Pair)<(.+)>")


def normalize_cpp_type(cpp_type):
    return " ".join(cpp_type.replace("const ", "").split())

def infer_wire_type(cpp_type):
    normalized = normalize_cpp_type(cpp_type)
    scalar = {
        "uint8_t": "u8",
        "uint16_t": "u16",
        "float": "f32",
        "double": "f64",
        "int32_t": "i32",
        "uint32_t": "u32",
        "int64_t": "i64",
        "uint64_t": "u64",
        "bool": "bool_i32",
        "U8String": "utf8_string",
        "U16String": "u16_string",
    }
    if normalized in scalar:
        return scalar[normalized]
    if normalized == "size_t":
        return "unsupported_size_t"
    if vector_inner(normalized) is not None:
        return "list"
    return "struct"

def split_template_args(args):
    parts = []
    current = []
    depth = 0
    for char in args:
        if char == "<":
            depth += 1
        elif char == ">":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(normalize_cpp_type("".join(current)))
            current = []
            continue
        current.append(char)
    if current:
        parts.append(normalize_cpp_type("".join(current)))
    return parts

def vector_inner(cpp_type):
    match = VECTOR_RE.match(normalize_cpp_type(cpp_type))
    return normalize_cpp_type(match.group(1)) if match else None

def pair_inner(cpp_type):
    match = PAIR_RE.match(normalize_cpp_type(cpp_type))
    if not match:
        return None
    parts = split_template_args(match.group(1))
    if len(parts) != 2:
        return None
    return parts[0], parts[1]

def snake_to_camel(name):
    parts = name.split("_")
    return parts[0] + "".join(part[:1].upper() + part[1:] for part in parts[1:])

def lower_first(name):
    return name[:1].lower() + name[1:]

def upper_first(name):
    return name[:1].upper() + name[1:]


def protocol_type_name(target, default_file):
    file_name = default_file
    if target is not None:
        file_name = target.get("codec_file", target.get("file", default_file))
    stem = Path(file_name).stem
    parts = [part for part in re.split(r"[_\-\s]+", stem) if part]
    return "".join(upper_first(part) for part in parts)


def sanitize_cpp_number(value):
    return re.sub(r"([0-9.]+)[fFuUlL]*", r"\1", value.strip())


def is_cpp_number(value):
    return re.fullmatch(r"-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)[fFuUlL]*", value.strip()) is not None


def field_name(field, style):
    if style in ("java", "ets"):
        return snake_to_camel(field["name"])
    return field["name"]

def type_map(schema):
    return {item["name"]: item for item in schema["types"]}

def enum_map(schema):
    return {item["name"]: item for item in schema["enums"]}

def field_type_name(field):
    inner = vector_inner(field["cpp_type"])
    return inner if inner is not None else field["cpp_type"]

def synthetic_pair_entry_item(field):
    entry = field.get("map_entry")
    if not entry:
        return None
    inner = vector_inner(field["cpp_type"])
    pair = pair_inner(inner) if inner is not None else None
    if pair is None:
        raise SystemExit(
            f"{field['source']}:{field['line']}: SE_PROTOCOL_MAP_ENTRY requires Vector<std::pair<K, V>>"
        )
    key_type, value_type = pair
    key_field = {
        "name": entry["key"],
        "cpp_type": key_type,
        "wire": field.get("key_wire") or infer_wire_type(key_type),
        "source": field["source"],
        "line": field["line"],
    }
    value_field = {
        "name": entry["value"],
        "cpp_type": value_type,
        "wire": field.get("value_wire") or infer_wire_type(value_type),
        "source": field["source"],
        "line": field["line"],
    }
    return {
        "name": f"{entry['key']}_{entry['value']}_entry",
        "kind": "value",
        "direction": "in",
        "domain": None,
        "source": field["source"],
        "line": field["line"],
        "synthetic": True,
        "fields": [key_field, value_field],
    }

def needs_reader(item):
    return item["direction"] in ("out", "both", "value")

def needs_writer(item):
    return item["direction"] in ("in", "both", "value")

def is_hidden_input_type(item):
    return item["direction"] == "in" and (item["kind"] == "payload" or item["name"].endswith("Entry"))

def visible_schema_types(schema):
    return [item for item in schema["types"] if not is_hidden_input_type(item)]

def input_pack_items(schema):
    return [item for item in schema["types"] if item["direction"] == "in" and not item["name"].endswith("Entry")]

def hidden_input_type_names(schema):
    return {item["name"] for item in schema["types"] if is_hidden_input_type(item)}

def list_inner_names(schema):
    hidden = hidden_input_type_names(schema)
    return sorted({
        vector_inner(field["cpp_type"])
        for item in schema["types"]
        for field in item["fields"]
        if (
            vector_inner(field["cpp_type"]) is not None
            and vector_inner(field["cpp_type"]) not in hidden
            and map_entry_item(field, schema) is None
        )
    })

def inner_needs_reader(schema, name):
    item = type_map(schema).get(name)
    return item is None or needs_reader(item)

def inner_needs_writer(schema, name):
    item = type_map(schema).get(name)
    return item is None or needs_writer(item)

def map_entry_item(field, schema):
    synthetic = synthetic_pair_entry_item(field)
    if synthetic is not None:
        return synthetic
    inner = vector_inner(field["cpp_type"])
    if inner is None:
        return None
    item = type_map(schema).get(inner)
    if item is None or not is_hidden_input_type(item) or len(item["fields"]) != 2:
        return None
    return item

def payload_encode_function_name(item):
    return f"encode{item['name']}"

def map_payload_param_name(entry_item):
    key_name = entry_item["fields"][0]["name"]
    value_name = entry_item["fields"][1]["name"]
    return snake_to_camel(f"{value_name}_by_{key_name}")

def payload_param_name(field, style, schema):
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        return map_payload_param_name(entry_item)
    return field_name(field, style)

def target_domains(target):
    return target.get("domains", {})

def domain_value(target, domain, fallback):
    return target_domains(target).get(domain, fallback)
