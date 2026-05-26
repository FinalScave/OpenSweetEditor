import json
import struct

from .ir import enum_map, map_entry_item, type_map, vector_inner


def normalize_hex(value):
    return "".join(value.split()).lower()

def format_hex(value):
    return value.hex(" ")

def enum_number(schema, enum_name, value):
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        enum_value = value.rsplit("::", 1)[-1]
        for entry in enum_map(schema)[enum_name]["values"]:
            if entry["name"] == enum_value:
                return entry["value"]
    raise SystemExit(f"Unknown enum value {value!r} for {enum_name}")

def fixture_value_for_field(item, field, value):
    if field["name"] not in value:
        raise SystemExit(f"Fixture for {item['name']} is missing field {field['name']}")
    return value[field["name"]]

def ensure_no_extra_fixture_fields(item, value):
    expected = {field["name"] for field in item["fields"]}
    actual = set(value)
    extra = sorted(actual - expected)
    if extra:
        raise SystemExit(f"Fixture for {item['name']} contains unknown fields: {', '.join(extra)}")

def pack_i32(value):
    return struct.pack("<i", int(value))

def pack_u32(value):
    return struct.pack("<I", int(value))

def pack_u8(value):
    return struct.pack("<B", int(value))

def pack_u16(value):
    return struct.pack("<H", int(value))

def pack_i64(value):
    return struct.pack("<q", int(value))

def pack_u64(value):
    return struct.pack("<Q", int(value))

def pack_f32(value):
    return struct.pack("<f", float(value))

def pack_f64(value):
    return struct.pack("<d", float(value))

def serialize_list(schema, inner, values):
    if not isinstance(values, list):
        raise SystemExit(f"Expected list for Vector<{inner}> fixture value")
    result = [pack_i32(len(values))]
    for value in values:
        result.append(serialize_type(schema, inner, value))
    return b"".join(result)

def serialize_map_entries(schema, entry_item, values):
    if not isinstance(values, list):
        raise SystemExit(f"Expected list for {entry_item['name']} fixture value")
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    result = [pack_i32(len(values))]
    for value in values:
        if not isinstance(value, dict):
            raise SystemExit(f"Fixture value for {entry_item['name']} must be an object")
        ensure_no_extra_fixture_fields(entry_item, value)
        result.append(serialize_field(schema, key_field, fixture_value_for_field(entry_item, key_field, value)))
        result.append(serialize_field(schema, value_field, fixture_value_for_field(entry_item, value_field, value)))
    return b"".join(result)

def serialize_field(schema, field, value):
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        return serialize_map_entries(schema, entry_item, value)
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return serialize_list(schema, inner, value)
    wire = field["wire"]
    if wire == "u8":
        return pack_u8(value)
    if wire == "u16":
        return pack_u16(value)
    if wire == "enum_i32":
        return pack_i32(enum_number(schema, field["cpp_type"], value))
    if wire in ("i32", "size_as_i32"):
        return pack_i32(value)
    if wire in ("u32", "size_as_u32"):
        return pack_u32(value)
    if wire in ("i64", "size_as_i64"):
        return pack_i64(value)
    if wire in ("u64", "size_as_u64"):
        return pack_u64(value)
    if wire == "f32":
        return pack_f32(value)
    if wire == "f64":
        return pack_f64(value)
    if wire == "bool_i32":
        return pack_i32(1 if value else 0)
    if wire == "bool_u8":
        return struct.pack("<B", 1 if value else 0)
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        encoded = str(value).encode("utf-8")
        return pack_i32(len(encoded)) + encoded
    if wire == "struct":
        return serialize_type(schema, field["cpp_type"], value)
    raise SystemExit(f"Unsupported golden wire type: {wire}")

def serialize_type(schema, type_name, value):
    if type_name not in type_map(schema):
        raise SystemExit(f"Unknown golden fixture type: {type_name}")
    item = type_map(schema)[type_name]
    if not isinstance(value, dict):
        raise SystemExit(f"Fixture value for {type_name} must be an object")
    ensure_no_extra_fixture_fields(item, value)
    parts = []
    for field in item["fields"]:
        parts.append(serialize_field(schema, field, fixture_value_for_field(item, field, value)))
    return b"".join(parts)

def fixture_bytes(schema, fixture):
    type_name = fixture.get("type")
    if not type_name:
        raise SystemExit(f"Golden fixture {fixture.get('name', '<unnamed>')} is missing type")
    if "value" not in fixture:
        raise SystemExit(f"Golden fixture {fixture.get('name', type_name)} is missing value")
    return serialize_type(schema, type_name, fixture["value"])

def read_golden_file(path):
    if not path.exists():
        raise SystemExit(f"Missing golden fixture file: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    fixtures = data.get("fixtures")
    if not isinstance(fixtures, list):
        raise SystemExit(f"Golden fixture file must contain a fixtures array: {path}")
    return data

