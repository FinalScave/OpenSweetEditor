from pathlib import Path

from ..ir import *


def java_domain_package(target, domain):
    base_package = target["package"]
    domain_package = domain_value(target, domain, domain).replace("/", ".")
    return f"{base_package}.{domain_package}" if domain_package else base_package

def java_domain_path(target, domain):
    return Path(domain_value(target, domain, domain))

def java_codec_mode(target):
    mode = target.get("java_api", {}).get("codec", "byte_buffer")
    if mode not in ("byte_buffer", "memory_segment"):
        raise SystemExit(f"Unsupported Java codec: {mode}")
    return mode

def java_uses_memory_segment_codec(target):
    return java_codec_mode(target) == "memory_segment"

def java_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        inner_type = "String" if infer_wire_type(inner) == "utf8_string" else inner
        return f"java.util.List<{inner_type}>"
    wire = field["wire"]
    if wire == "enum_i32" and field["cpp_type"] in schema_enums:
        return field["cpp_type"]
    if wire in ("u8", "u16", "i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return "int"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return "long"
    if wire == "f32":
        return "float"
    if wire == "f64":
        return "double"
    if wire in ("bool_i32", "bool_u8"):
        return "boolean"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "String"
    if field["cpp_type"] in schema_types:
        return field["cpp_type"]
    raise SystemExit(f"Unsupported Java field type: {field['cpp_type']} ({wire})")

def java_default_expr(java_type_name):
    if java_type_name == "boolean":
        return "false"
    if java_type_name == "float":
        return "0f"
    if java_type_name == "double":
        return "0d"
    if java_type_name in ("int", "long"):
        return "0"
    return "null"

def java_number_literal_for_type(number, java_type_name):
    if java_type_name == "float":
        return f"{number}f"
    if java_type_name == "double":
        return f"{number}d"
    if java_type_name == "long":
        return f"{number}L"
    return number

def java_default_for_field(field, java_type_name, schema_types, schema_enums):
    default = field.get("default")
    inner = vector_inner(field["cpp_type"])
    if not default:
        if inner is not None:
            return "new java.util.ArrayList<>()"
        if field["wire"] in ("utf8_string", "u16_string", "u16_as_utf8"):
            return "\"\""
        if field["wire"] == "struct" and field["cpp_type"] in schema_types:
            return f"new {field['cpp_type']}()"
        return None
    if "," in default:
        if field["wire"] == "struct" and field["cpp_type"] in schema_types:
            parts = [sanitize_cpp_number(part) for part in default.split(",")]
            struct_fields = schema_types[field["cpp_type"]].get("fields", [])
            if all(is_cpp_number(part) for part in parts) and len(parts) == len(struct_fields):
                typed_parts = []
                for part, struct_field in zip(parts, struct_fields):
                    struct_java_type = java_type(struct_field, schema_types, schema_enums)
                    typed_parts.append(java_number_literal_for_type(part, struct_java_type))
                return f"new {field['cpp_type']}({', '.join(typed_parts)})"
        return None
    if "::" in default:
        enum_name, enum_value = default.split("::", 1)
        if enum_name in schema_enums:
            return f"{enum_name}.{enum_value}"
        return None
    if default in ("true", "false"):
        return default
    if not is_cpp_number(default):
        return None
    number = sanitize_cpp_number(default)
    if java_type_name in ("float", "double", "long"):
        return java_number_literal_for_type(number, java_type_name)
    if java_type_name == "int":
        return number
    return None

def java_read_expr(field):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"read{inner}List(data)"
    if wire == "enum_i32":
        return f"{field['cpp_type']}.fromValue(data.getInt())"
    if wire == "u8":
        return "data.get() & 0xFF"
    if wire == "u16":
        return "data.getShort() & 0xFFFF"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return "data.getInt()"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return "data.getLong()"
    if wire == "f32":
        return "data.getFloat()"
    if wire == "f64":
        return "data.getDouble()"
    if wire == "bool_i32":
        return "data.getInt() != 0"
    if wire == "bool_u8":
        return "(data.get() & 0xFF) != 0"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "readUtf8String(data)"
    if wire == "struct":
        return f"read{field['cpp_type']}(data)"
    raise SystemExit(f"Unsupported Java read wire: {wire}")

JAVA_STRING_WIRES = ("utf8_string", "u16_string", "u16_as_utf8")


def java_is_string_wire(wire):
    return wire in JAVA_STRING_WIRES


def java_type_has_utf8(type_name, schema, seen=None):
    if seen is None:
        seen = set()
    if type_name in seen:
        return False
    seen.add(type_name)
    item = type_map(schema).get(type_name)
    if item is None:
        return False
    return any(java_field_has_utf8(field, schema, seen) for field in item["fields"])


def java_field_has_utf8(field, schema, seen=None):
    if java_is_string_wire(field["wire"]):
        return True
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        return any(java_field_has_utf8(entry_field, schema, seen) for entry_field in entry_item["fields"])
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return java_type_has_utf8(inner, schema, seen)
    if field["wire"] == "struct":
        return java_type_has_utf8(field["cpp_type"], schema, seen)
    return False


def java_item_has_utf8(item, schema):
    return any(java_field_has_utf8(field, schema) for field in item["fields"])


def java_cache_prefix(prefix, name):
    return f"{prefix}{upper_first(name)}" if prefix else name


def java_write_stmt(field, value_expr, schema=None, internal=False):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"write{inner}List(data, {value_expr});"
    if wire == "enum_i32":
        return f"data.putInt({value_expr}.value);"
    if wire == "u8":
        return f"data.put((byte) {value_expr});"
    if wire == "u16":
        return f"data.putShort((short) {value_expr});"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return f"data.putInt({value_expr});"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return f"data.putLong({value_expr});"
    if wire == "f32":
        return f"data.putFloat({value_expr});"
    if wire == "f64":
        return f"data.putDouble({value_expr});"
    if wire == "bool_i32":
        return f"data.putInt({value_expr} ? 1 : 0);"
    if wire == "bool_u8":
        return f"data.put((byte) ({value_expr} ? 1 : 0));"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return f"writeUtf8String(data, {value_expr});"
    if wire == "struct":
        if internal:
            return f"write{field['cpp_type']}Fields(data, {value_expr});"
        return f"write{field['cpp_type']}(data, {value_expr});"
    raise SystemExit(f"Unsupported Java write wire: {wire}")

def java_size_expr(field, value_expr, schema=None):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"sizeOf{inner}List({value_expr})"
    if wire == "u8":
        return "1"
    if wire == "u16":
        return "2"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32", "f32", "bool_i32"):
        return "4"
    if wire == "bool_u8":
        return "1"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64", "f64"):
        return "8"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return f"sizeOfUtf8String({value_expr})"
    if wire == "struct":
        return f"sizeOf{field['cpp_type']}({value_expr})"
    raise SystemExit(f"Unsupported Java size wire: {wire}")

def java_boxed_type(java_type_name):
    return {
        "int": "Integer",
        "long": "Long",
        "float": "Float",
        "double": "Double",
        "boolean": "Boolean",
    }.get(java_type_name, java_type_name)

def java_map_value_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"java.util.List<? extends {inner}>"
    return java_type(field, schema_types, schema_enums)

def java_uses_sparse_line_map(field, schema, target):
    entry_item = map_entry_item(field, schema)
    if entry_item is None:
        return False
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    java_api = target.get("java_api", {})
    return (
        java_api.get("line_map") == "sparse_array"
        and key_field["name"] == "line"
        and vector_inner(value_field["cpp_type"]) is not None
    )

def java_pack_param_type(field, schema, target):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        if java_uses_sparse_line_map(field, schema, target):
            value_field = entry_item["fields"][1]
            value_type = java_map_value_type(value_field, schema_types, schema_enums)
            return f"android.util.SparseArray<? extends {value_type}>"
        key_field = entry_item["fields"][0]
        value_field = entry_item["fields"][1]
        key_type = java_boxed_type(java_type(key_field, schema_types, schema_enums))
        value_type = java_map_value_type(value_field, schema_types, schema_enums)
        return f"java.util.Map<{key_type}, ? extends {value_type}>"
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"java.util.List<? extends {inner}>"
    return java_type(field, schema_types, schema_enums)

def java_pack_params(item, schema, target):
    return [
        (java_pack_param_type(field, schema, target), payload_param_name(field, "java", schema), field)
        for field in item["fields"]
    ]

def java_size_value_line(field, value_expr, schema=None):
    return f"        size += {java_size_expr(field, value_expr, schema)};"

def java_write_value_line(field, value_expr, schema=None, internal=False):
    return f"        {java_write_stmt(field, value_expr, schema, internal)}"

def java_tree_map_type(field, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    key_type = java_boxed_type(java_type(key_field, schema_types, schema_enums))
    value_type = java_map_value_type(value_field, schema_types, schema_enums)
    return f"java.util.TreeMap<{key_type}, {value_type}>"


def java_map_entry_types(field, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    key_type = java_boxed_type(java_type(key_field, schema_types, schema_enums))
    value_type = java_map_value_type(value_field, schema_types, schema_enums)
    return key_field, value_field, key_type, value_type


def java_size_map_field_lines(field, param_name, schema, target=None):
    key_field, value_field, key_type, value_type = java_map_entry_types(field, schema)
    lines = [
        "        size += 4;",
        f"        if ({param_name} != null) {{",
        f"            for (java.util.Map.Entry<{key_type}, ? extends {value_type}> entry : {param_name}.entrySet()) {{",
        f"                size += {java_size_expr(key_field, 'entry.getKey()', schema)};",
    ]
    lines.append(f"                size += {java_size_expr(value_field, 'entry.getValue()', schema)};")
    lines.extend([
        "            }",
        "        }",
    ])
    return lines

def java_size_sparse_line_map_field_lines(field, param_name, schema):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    lines = [
        "        size += 4;",
        f"        if ({param_name} != null) {{",
        f"            for (int i = 0; i < {param_name}.size(); i++) {{",
        f"                size += {java_size_expr(key_field, f'{param_name}.keyAt(i)', schema)};",
        f"                size += {java_size_expr(value_field, f'{param_name}.valueAt(i)', schema)};",
        "            }",
        "        }",
    ]
    return lines

def java_write_map_field_lines(field, param_name, schema, target=None):
    key_field, value_field, key_type, value_type = java_map_entry_types(field, schema)
    sorted_name = f"sorted{upper_first(param_name)}"
    lines = [
        f"        java.util.TreeMap<{key_type}, {value_type}> {sorted_name} = new java.util.TreeMap<>();",
        f"        if ({param_name} != null) {{",
        f"            for (java.util.Map.Entry<{key_type}, ? extends {value_type}> entry : {param_name}.entrySet()) {{",
        f"                {sorted_name}.put(entry.getKey(), entry.getValue());",
        "            }",
        "        }",
        f"        data.putInt({sorted_name}.size());",
        f"        for (java.util.Map.Entry<{key_type}, {value_type}> entry : {sorted_name}.entrySet()) {{",
        f"            {java_write_stmt(key_field, 'entry.getKey()', schema, internal=True)}",
        f"            {java_write_stmt(value_field, 'entry.getValue()', schema, internal=True)}",
        "        }",
    ]
    return lines

def java_write_sparse_line_map_field_lines(field, param_name, schema):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    lines = [
        f"        int count = {param_name} == null ? 0 : {param_name}.size();",
        "        data.putInt(count);",
        "        for (int i = 0; i < count; i++) {",
        f"            {java_write_stmt(key_field, f'{param_name}.keyAt(i)', schema, internal=True)}",
        f"            {java_write_stmt(value_field, f'{param_name}.valueAt(i)', schema, internal=True)}",
        "        }",
    ]
    return lines

def java_size_payload_field_lines(field, param_name, schema, target):
    if map_entry_item(field, schema) is not None:
        if java_uses_sparse_line_map(field, schema, target):
            return java_size_sparse_line_map_field_lines(field, param_name, schema)
        return java_size_map_field_lines(field, param_name, schema, target)
    return [java_size_value_line(field, param_name, schema)]

def java_write_payload_field_lines(field, param_name, schema, target):
    if map_entry_item(field, schema) is not None:
        if java_uses_sparse_line_map(field, schema, target):
            return java_write_sparse_line_map_field_lines(field, param_name, schema)
        return java_write_map_field_lines(field, param_name, schema, target)
    return [java_write_value_line(field, param_name, schema, True)]


def java_cached_utf8_array_decls_for_type(type_name, schema, prefix, count_name, indent, seen=None):
    if seen is None:
        seen = set()
    if type_name in seen:
        return []
    seen.add(type_name)
    item = type_map(schema).get(type_name)
    if item is None:
        return []
    lines = []
    for field in item["fields"]:
        name = field_name(field, "java")
        field_prefix = java_cache_prefix(prefix, name)
        lines.extend(java_cached_utf8_array_decls_for_field(field, schema, field_prefix, count_name, indent, seen.copy()))
    return lines


def java_cached_utf8_array_decls_for_field(field, schema, prefix, count_name, indent, seen=None):
    if java_is_string_wire(field["wire"]):
        return [f"{indent}byte[][] {prefix}Utf8 = new byte[{count_name}][];"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        if java_type_has_utf8(inner, schema, seen):
            raise SystemExit(f"Nested UTF-8 list caches are not supported yet: {field['cpp_type']}")
        return []
    if field["wire"] == "struct" and java_type_has_utf8(field["cpp_type"], schema, seen):
        return java_cached_utf8_array_decls_for_type(field["cpp_type"], schema, prefix, count_name, indent, seen)
    return []


def java_write_cached_utf8_line(mode, bytes_expr, indent):
    if mode == "memory_segment":
        return f"{indent}writer.writeUtf8Bytes({bytes_expr});"
    return f"{indent}writeUtf8Bytes(data, {bytes_expr});"


def java_write_int32_line(mode, value_expr, indent):
    if mode == "memory_segment":
        return f"{indent}writer.writeInt32({value_expr});"
    return f"{indent}data.putInt({value_expr});"


def java_cached_write_stmt(field, value_expr, schema, mode):
    if mode == "memory_segment":
        return java_segment_write_stmt(field, value_expr, schema)
    return java_write_stmt(field, value_expr, schema, internal=True)


def java_cached_size_string_lines(value_expr, prefix, indent, cache_index=None):
    cache_name = f"{prefix}Utf8"
    if cache_index is None:
        return [
            f"{indent}byte[] {cache_name} = utf8Bytes({value_expr});",
            f"{indent}size += 4 + {cache_name}.length;",
        ]
    local_name = f"{prefix}Bytes"
    return [
        f"{indent}byte[] {local_name} = utf8Bytes({value_expr});",
        f"{indent}{cache_name}[{cache_index}] = {local_name};",
        f"{indent}size += 4 + {local_name}.length;",
    ]


def java_cached_write_string_lines(prefix, indent, mode, cache_index=None):
    cache_name = f"{prefix}Utf8"
    bytes_expr = cache_name if cache_index is None else f"{cache_name}[{cache_index}]"
    return [java_write_cached_utf8_line(mode, bytes_expr, indent)]


def java_cached_size_type_lines(type_name, value_expr, schema, prefix, indent, target, cache_index=None):
    item = type_map(schema).get(type_name)
    if item is None:
        return [f"{indent}size += sizeOf{type_name}({value_expr});"]
    lines = []
    for field in item["fields"]:
        name = field_name(field, "java")
        field_prefix = java_cache_prefix(prefix, name)
        lines.extend(java_cached_size_field_lines(field, f"{value_expr}.{name}", schema, field_prefix, indent, target, cache_index))
    return lines


def java_cached_write_type_lines(type_name, value_expr, schema, prefix, indent, mode, target, cache_index=None):
    item = type_map(schema).get(type_name)
    if item is None:
        return [f"{indent}{java_cached_write_stmt({'wire': 'struct', 'cpp_type': type_name}, value_expr, schema, mode)}"]
    lines = []
    for field in item["fields"]:
        name = field_name(field, "java")
        field_prefix = java_cache_prefix(prefix, name)
        lines.extend(java_cached_write_field_lines(field, f"{value_expr}.{name}", schema, field_prefix, indent, mode, target, cache_index))
    return lines


def java_cached_size_list_lines(field, value_expr, inner, schema, prefix, indent, target):
    count_name = f"{prefix}Count"
    index_name = f"{prefix}Index"
    item_name = f"{prefix}Item"
    lines = [
        f"{indent}int {count_name} = {value_expr} == null ? 0 : {value_expr}.size();",
    ]
    lines.extend(java_cached_utf8_array_decls_for_type(inner, schema, prefix, count_name, indent))
    lines.extend([
        f"{indent}size += 4;",
        f"{indent}for (int {index_name} = 0; {index_name} < {count_name}; {index_name}++) {{",
        f"{indent}    {inner} {item_name} = {value_expr}.get({index_name});",
    ])
    lines.extend(java_cached_size_type_lines(inner, item_name, schema, prefix, f"{indent}    ", target, index_name))
    lines.append(f"{indent}}}")
    return lines


def java_cached_write_list_lines(field, value_expr, inner, schema, prefix, indent, mode, target):
    count_name = f"{prefix}Count"
    index_name = f"{prefix}Index"
    item_name = f"{prefix}Item"
    lines = [
        java_write_int32_line(mode, count_name, indent),
        f"{indent}for (int {index_name} = 0; {index_name} < {count_name}; {index_name}++) {{",
        f"{indent}    {inner} {item_name} = {value_expr}.get({index_name});",
    ]
    lines.extend(java_cached_write_type_lines(inner, item_name, schema, prefix, f"{indent}    ", mode, target, index_name))
    lines.append(f"{indent}}}")
    return lines


def java_cached_map_source_lines(field, param_name, schema, prefix, indent, target):
    key_field, value_field, key_type, value_type = java_map_entry_types(field, schema)
    count_name = f"{prefix}Count"
    if java_uses_sparse_line_map(field, schema, target):
        return [], count_name
    sorted_name = f"sorted{upper_first(prefix)}"
    lines = [
        f"{indent}{java_tree_map_type(field, schema)} {sorted_name} = new java.util.TreeMap<>();",
        f"{indent}if ({param_name} != null) {{",
        f"{indent}    for (java.util.Map.Entry<{key_type}, ? extends {value_type}> entry : {param_name}.entrySet()) {{",
        f"{indent}        {sorted_name}.put(entry.getKey(), entry.getValue());",
        f"{indent}    }}",
        f"{indent}}}",
    ]
    return lines, count_name


def java_cached_size_map_field_lines(field, param_name, schema, target, prefix, indent):
    key_field, value_field, key_type, value_type = java_map_entry_types(field, schema)
    value_inner = vector_inner(value_field["cpp_type"])
    count_name = f"{prefix}Count"
    entry_index_name = f"{prefix}Index"
    item_count_name = f"{prefix}ItemCount"
    item_index_name = f"{prefix}ItemIndex"
    value_name = java_cache_prefix(prefix, field_name(value_field, "java"))
    value_count_name = f"{value_name}Count"
    value_index_name = f"{value_name}Index"
    source_lines, _ = java_cached_map_source_lines(field, param_name, schema, prefix, indent, target)
    lines = source_lines
    if java_uses_sparse_line_map(field, schema, target):
        source_expr = param_name
        key_expr = f"{param_name}.keyAt({entry_index_name})"
        value_expr = f"{param_name}.valueAt({entry_index_name})"
        entry_loop = f"for (int {entry_index_name} = 0; {entry_index_name} < {count_name}; {entry_index_name}++) {{"
        lines.append(f"{indent}int {count_name} = {param_name} == null ? 0 : {param_name}.size();")
    else:
        source_expr = f"sorted{upper_first(prefix)}"
        key_expr = "entry.getKey()"
        value_expr = "entry.getValue()"
        entry_loop = f"for (java.util.Map.Entry<{key_type}, {value_type}> entry : {source_expr}.entrySet()) {{"
        lines.append(f"{indent}int {count_name} = {source_expr}.size();")
    lines.extend(java_cached_utf8_array_decls_for_field(key_field, schema, java_cache_prefix(prefix, field_name(key_field, "java")), count_name, indent))
    lines.extend([
        f"{indent}int {item_count_name} = 0;",
        f"{indent}size += 4;",
        f"{indent}{entry_loop}",
    ])
    lines.extend(java_cached_size_field_lines(key_field, key_expr, schema, java_cache_prefix(prefix, field_name(key_field, "java")), f"{indent}    ", target, entry_index_name))
    if value_inner is not None and java_type_has_utf8(value_inner, schema):
        lines.extend([
            f"{indent}    {value_type} {value_name} = {value_expr};",
            f"{indent}    int {value_count_name} = {value_name} == null ? 0 : {value_name}.size();",
            f"{indent}    {item_count_name} += {value_count_name};",
            f"{indent}    size += 4;",
            f"{indent}}}",
        ])
        lines.extend(java_cached_utf8_array_decls_for_type(value_inner, schema, prefix, item_count_name, indent))
        lines.extend([
            f"{indent}int {item_index_name} = 0;",
            f"{indent}{entry_loop}",
            f"{indent}    {value_type} {value_name} = {value_expr};",
            f"{indent}    int {value_count_name} = {value_name} == null ? 0 : {value_name}.size();",
            f"{indent}    for (int {value_index_name} = 0; {value_index_name} < {value_count_name}; {value_index_name}++) {{",
            f"{indent}        {value_inner} {prefix}Item = {value_name}.get({value_index_name});",
        ])
        lines.extend(java_cached_size_type_lines(value_inner, f"{prefix}Item", schema, prefix, f"{indent}        ", target, item_index_name))
        lines.extend([
            f"{indent}        {item_index_name}++;",
            f"{indent}    }}",
            f"{indent}}}",
        ])
        return lines
    lines.extend(java_cached_utf8_array_decls_for_field(value_field, schema, java_cache_prefix(prefix, field_name(value_field, "java")), count_name, indent))
    lines.extend(java_cached_size_field_lines(value_field, value_expr, schema, java_cache_prefix(prefix, field_name(value_field, "java")), f"{indent}    ", target, entry_index_name))
    lines.append(f"{indent}}}")
    return lines


def java_cached_write_map_field_lines(field, param_name, schema, target, prefix, indent, mode):
    key_field, value_field, key_type, value_type = java_map_entry_types(field, schema)
    value_inner = vector_inner(value_field["cpp_type"])
    count_name = f"{prefix}Count"
    entry_index_name = f"{prefix}Index"
    item_index_name = f"{prefix}ItemIndex"
    value_name = java_cache_prefix(prefix, field_name(value_field, "java"))
    value_count_name = f"{value_name}Count"
    value_index_name = f"{value_name}Index"
    if java_uses_sparse_line_map(field, schema, target):
        key_expr = f"{param_name}.keyAt({entry_index_name})"
        value_expr = f"{param_name}.valueAt({entry_index_name})"
        entry_loop = f"for (int {entry_index_name} = 0; {entry_index_name} < {count_name}; {entry_index_name}++) {{"
    else:
        source_expr = f"sorted{upper_first(prefix)}"
        key_expr = "entry.getKey()"
        value_expr = "entry.getValue()"
        entry_loop = f"for (java.util.Map.Entry<{key_type}, {value_type}> entry : {source_expr}.entrySet()) {{"
    lines = [
        java_write_int32_line(mode, count_name, indent),
        f"{indent}{item_index_name} = 0;",
        f"{indent}{entry_loop}",
    ]
    lines.extend(java_cached_write_field_lines(key_field, key_expr, schema, java_cache_prefix(prefix, field_name(key_field, "java")), f"{indent}    ", mode, target, entry_index_name))
    if value_inner is not None and java_type_has_utf8(value_inner, schema):
        lines.extend([
            f"{indent}    {value_type} {value_name} = {value_expr};",
            f"{indent}    int {value_count_name} = {value_name} == null ? 0 : {value_name}.size();",
            java_write_int32_line(mode, value_count_name, f"{indent}    "),
            f"{indent}    for (int {value_index_name} = 0; {value_index_name} < {value_count_name}; {value_index_name}++) {{",
            f"{indent}        {value_inner} {prefix}Item = {value_name}.get({value_index_name});",
        ])
        lines.extend(java_cached_write_type_lines(value_inner, f"{prefix}Item", schema, prefix, f"{indent}        ", mode, target, item_index_name))
        lines.extend([
            f"{indent}        {item_index_name}++;",
            f"{indent}    }}",
            f"{indent}}}",
        ])
        return lines
    lines.extend(java_cached_write_field_lines(value_field, value_expr, schema, java_cache_prefix(prefix, field_name(value_field, "java")), f"{indent}    ", mode, target, entry_index_name))
    lines.append(f"{indent}}}")
    return lines


def java_cached_size_field_lines(field, value_expr, schema, prefix, indent, target, cache_index=None):
    if java_is_string_wire(field["wire"]):
        return java_cached_size_string_lines(value_expr, prefix, indent, cache_index)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        if java_field_has_utf8(field, schema):
            return java_cached_size_map_field_lines(field, value_expr, schema, target, prefix, indent)
        return java_size_sparse_line_map_field_lines(field, value_expr, schema) if java_uses_sparse_line_map(field, schema, target) else java_size_map_field_lines(field, value_expr, schema, target)
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        if java_type_has_utf8(inner, schema):
            return java_cached_size_list_lines(field, value_expr, inner, schema, prefix, indent, target)
        return [f"{indent}size += {java_size_expr(field, value_expr, schema)};"]
    if field["wire"] == "struct" and java_type_has_utf8(field["cpp_type"], schema):
        return java_cached_size_type_lines(field["cpp_type"], value_expr, schema, prefix, indent, target, cache_index)
    return [f"{indent}size += {java_size_expr(field, value_expr, schema)};"]


def java_cached_write_field_lines(field, value_expr, schema, prefix, indent, mode, target, cache_index=None):
    if java_is_string_wire(field["wire"]):
        return java_cached_write_string_lines(prefix, indent, mode, cache_index)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        if java_field_has_utf8(field, schema):
            return java_cached_write_map_field_lines(field, value_expr, schema, target, prefix, indent, mode)
        if mode == "memory_segment":
            return java_segment_write_payload_field_lines(field, value_expr, schema)
        return java_write_sparse_line_map_field_lines(field, value_expr, schema) if java_uses_sparse_line_map(field, schema, target) else java_write_map_field_lines(field, value_expr, schema, target)
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        if java_type_has_utf8(inner, schema):
            return java_cached_write_list_lines(field, value_expr, inner, schema, prefix, indent, mode, target)
        return [f"{indent}{java_cached_write_stmt(field, value_expr, schema, mode)}"]
    if field["wire"] == "struct" and java_type_has_utf8(field["cpp_type"], schema):
        return java_cached_write_type_lines(field["cpp_type"], value_expr, schema, prefix, indent, mode, target, cache_index)
    return [f"{indent}{java_cached_write_stmt(field, value_expr, schema, mode)}"]


def java_cached_byte_buffer_encode_lines(params, schema, target):
    lines = ["        int size = 0;"]
    for _, name, field in params:
        lines.extend(java_cached_size_field_lines(field, name, schema, name, "        ", target))
    lines.append("        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);")
    for _, name, field in params:
        lines.extend(java_cached_write_field_lines(field, name, schema, name, "        ", "byte_buffer", target))
    lines.extend([
        "        data.flip();",
        "        return data;",
    ])
    return lines


def java_cached_byte_buffer_encode_value_lines(type_name, schema, target):
    lines = ["        int size = 0;"]
    lines.extend(java_cached_size_type_lines(type_name, "value", schema, "", "        ", target))
    lines.append("        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);")
    lines.extend(java_cached_write_type_lines(type_name, "value", schema, "", "        ", "byte_buffer", target))
    lines.extend([
        "        data.flip();",
        "        return data;",
    ])
    return lines

def generate_java_pack_methods(item, schema, target):
    pack_name = payload_encode_function_name(item)
    if not is_hidden_input_type(item):
        lines = [
            "",
            f"    public static ByteBuffer {pack_name}({item['name']} value) {{",
        ]
        if java_item_has_utf8(item, schema):
            lines.extend(java_cached_byte_buffer_encode_value_lines(item["name"], schema, target))
        else:
            lines.extend([
                f"        ByteBuffer data = ByteBuffer.allocateDirect(sizeOf{item['name']}(value)).order(ByteOrder.LITTLE_ENDIAN);",
                f"        write{item['name']}Fields(data, value);",
                "        data.flip();",
                "        return data;",
            ])
        lines.append("    }")
        return lines
    params = java_pack_params(item, schema, target)
    params_sig = ", ".join(f"{type_name} {name}" for type_name, name, _ in params)
    args = ", ".join(name for _, name, _ in params)
    wire_name = pack_name[len("encode"):]
    has_utf8 = any(java_field_has_utf8(field, schema) for _, _, field in params)
    if has_utf8:
        lines = [
            "",
            f"    public static ByteBuffer {pack_name}({params_sig}) {{",
        ]
        lines.extend(java_cached_byte_buffer_encode_lines(params, schema, target))
        lines.append("    }")
        return lines
    lines = [
        "",
        f"    private static void write{wire_name}Wire(ByteBuffer data, {params_sig}) {{",
    ]
    for _, name, field in params:
        lines.extend(java_write_payload_field_lines(field, name, schema, target))
    lines.append("    }")
    lines.extend([
        "",
        f"    private static int sizeOf{wire_name}Wire({params_sig}) {{",
        "        int size = 0;",
    ])
    for _, name, field in params:
        lines.extend(java_size_payload_field_lines(field, name, schema, target))
    lines.extend([
        "        return size;",
        "    }",
    ])
    lines.extend([
        "",
        f"    public static ByteBuffer {pack_name}({params_sig}) {{",
    ])
    lines.extend([
        f"        ByteBuffer data = ByteBuffer.allocateDirect(sizeOf{wire_name}Wire({args})).order(ByteOrder.LITTLE_ENDIAN);",
        f"        write{wire_name}Wire(data, {args});",
        "        data.flip();",
        "        return data;",
        "    }",
    ])
    return lines

def java_segment_read_expr(field):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"read{inner}List(reader)"
    if wire == "enum_i32":
        return f"{field['cpp_type']}.fromValue(reader.readInt32())"
    if wire == "u8":
        return "reader.readUint8()"
    if wire == "u16":
        return "reader.readUint16()"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return "reader.readInt32()"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return "reader.readInt64()"
    if wire == "f32":
        return "reader.readFloat32()"
    if wire == "f64":
        return "reader.readFloat64()"
    if wire == "bool_i32":
        return "reader.readInt32() != 0"
    if wire == "bool_u8":
        return "reader.readUint8() != 0"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "reader.readUtf8String()"
    if wire == "struct":
        return f"read{field['cpp_type']}(reader)"
    raise SystemExit(f"Unsupported Java MemorySegment read wire: {wire}")

def java_segment_write_stmt(field, value_expr, schema=None):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"write{inner}List(writer, {value_expr});"
    if wire == "enum_i32":
        return f"writer.writeInt32({value_expr}.value);"
    if wire == "u8":
        return f"writer.writeUint8({value_expr});"
    if wire == "u16":
        return f"writer.writeUint16({value_expr});"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return f"writer.writeInt32({value_expr});"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return f"writer.writeInt64({value_expr});"
    if wire == "f32":
        return f"writer.writeFloat32({value_expr});"
    if wire == "f64":
        return f"writer.writeFloat64({value_expr});"
    if wire == "bool_i32":
        return f"writer.writeInt32({value_expr} ? 1 : 0);"
    if wire == "bool_u8":
        return f"writer.writeUint8({value_expr} ? 1 : 0);"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return f"writer.writeUtf8String({value_expr});"
    if wire == "struct":
        return f"write{field['cpp_type']}(writer, {value_expr});"
    raise SystemExit(f"Unsupported Java MemorySegment write wire: {wire}")

def java_segment_write_value_line(field, value_expr, schema=None):
    return f"        {java_segment_write_stmt(field, value_expr, schema)}"

def java_segment_write_map_field_lines(field, param_name, schema):
    key_field, value_field, key_type, value_type = java_map_entry_types(field, schema)
    sorted_name = f"sorted{upper_first(param_name)}"
    lines = [
        f"        java.util.TreeMap<{key_type}, {value_type}> {sorted_name} = new java.util.TreeMap<>();",
        f"        if ({param_name} != null) {{",
        f"            for (java.util.Map.Entry<{key_type}, ? extends {value_type}> entry : {param_name}.entrySet()) {{",
        f"                {sorted_name}.put(entry.getKey(), entry.getValue());",
        "            }",
        "        }",
        f"        writer.writeInt32({sorted_name}.size());",
        f"        for (java.util.Map.Entry<{key_type}, {value_type}> entry : {sorted_name}.entrySet()) {{",
        f"            {java_segment_write_stmt(key_field, 'entry.getKey()', schema)}",
        f"            {java_segment_write_stmt(value_field, 'entry.getValue()', schema)}",
        "        }",
    ]
    return lines

def java_segment_write_payload_field_lines(field, param_name, schema):
    if map_entry_item(field, schema) is not None:
        return java_segment_write_map_field_lines(field, param_name, schema)
    return [java_segment_write_value_line(field, param_name, schema)]


def java_cached_segment_encode_lines(params, schema, target):
    lines = ["        int size = 0;"]
    for _, name, field in params:
        lines.extend(java_cached_size_field_lines(field, name, schema, name, "        ", target))
    lines.append("        BinaryWriter writer = new BinaryWriter(arena, size);")
    for _, name, field in params:
        lines.extend(java_cached_write_field_lines(field, name, schema, name, "        ", "memory_segment", target))
    lines.append("        return writer.segment();")
    return lines


def java_cached_segment_encode_value_lines(type_name, schema, target):
    lines = ["        int size = 0;"]
    lines.extend(java_cached_size_type_lines(type_name, "value", schema, "", "        ", target))
    lines.append("        BinaryWriter writer = new BinaryWriter(arena, size);")
    lines.extend(java_cached_write_type_lines(type_name, "value", schema, "", "        ", "memory_segment", target))
    lines.append("        return writer.segment();")
    return lines

def generate_java_segment_pack_methods(item, schema, target):
    pack_name = payload_encode_function_name(item)
    if not is_hidden_input_type(item):
        lines = [
            "",
            f"    public static MemorySegment {pack_name}(Arena arena, {item['name']} value) {{",
        ]
        if java_item_has_utf8(item, schema):
            lines.extend(java_cached_segment_encode_value_lines(item["name"], schema, target))
        else:
            lines.extend([
                f"        BinaryWriter writer = new BinaryWriter(arena, sizeOf{item['name']}(value));",
                f"        write{item['name']}(writer, value);",
                "        return writer.segment();",
            ])
        lines.append("    }")
        return lines
    params = java_pack_params(item, schema, target)
    params_sig = ", ".join(f"{type_name} {name}" for type_name, name, _ in params)
    args = ", ".join(name for _, name, _ in params)
    wire_name = pack_name[len("encode"):]
    has_utf8 = any(java_field_has_utf8(field, schema) for _, _, field in params)
    if has_utf8:
        lines = [
            "",
            f"    public static MemorySegment {pack_name}(Arena arena, {params_sig}) {{",
        ]
        lines.extend(java_cached_segment_encode_lines(params, schema, target))
        lines.append("    }")
        return lines
    lines = [
        "",
        f"    private static void write{wire_name}Wire(BinaryWriter writer, {params_sig}) {{",
    ]
    for _, name, field in params:
        lines.extend(java_segment_write_payload_field_lines(field, name, schema))
    lines.append("    }")
    lines.extend([
        "",
        f"    private static int sizeOf{wire_name}Wire({params_sig}) {{",
        "        int size = 0;",
    ])
    for _, name, field in params:
        lines.extend(java_size_payload_field_lines(field, name, schema, target))
    lines.extend([
        "        return size;",
        "    }",
    ])
    lines.extend([
        "",
        f"    public static MemorySegment {pack_name}(Arena arena, {params_sig}) {{",
    ])
    lines.extend([
        f"        BinaryWriter writer = new BinaryWriter(arena, sizeOf{wire_name}Wire({args}));",
        f"        write{wire_name}Wire(writer, {args});",
        "        return writer.segment();",
        "    }",
    ])
    return lines

def generate_java_class(item, schema, target):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    package = java_domain_package(target, item["domain"])
    imports = set()
    fields = []
    ctor_args = []
    ctor_assigns = []
    for field in item["fields"]:
        java_type_name = java_type(field, schema_types, schema_enums)
        name = field_name(field, "java")
        fields.append((java_type_name, name))
        ctor_args.append(f"{java_type_name} {name}")
        ctor_assigns.append(f"        this.{name} = {name};")
        inner = vector_inner(field["cpp_type"])
        if inner is not None:
            imports.add("java.util.List")
        custom = field_type_name(field)
        if custom in schema_types and schema_types[custom]["domain"] != item["domain"]:
            imports.add(f"{java_domain_package(target, schema_types[custom]['domain'])}.{custom}")
        if custom in schema_enums and schema_enums[custom]["domain"] != item["domain"]:
            imports.add(f"{java_domain_package(target, schema_enums[custom]['domain'])}.{custom}")
    lines = [f"package {package};", ""]
    for import_name in sorted(imports):
        lines.append(f"import {import_name};")
    if imports:
        lines.append("")
    lines.append(f"public final class {item['name']} {{")
    for java_type_name, name in fields:
        default_expr = java_default_for_field(next(field for field in item["fields"] if field_name(field, "java") == name), java_type_name, schema_types, schema_enums)
        suffix = f" = {default_expr}" if default_expr is not None else ""
        lines.append(f"    public {java_type_name} {name}{suffix};")
    if fields:
        lines.append("")
    lines.append(f"    public {item['name']}() {{")
    lines.append("    }")
    if fields:
        lines.append("")
        lines.append(f"    public {item['name']}({', '.join(ctor_args)}) {{")
        lines.extend(ctor_assigns)
        lines.append("    }")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_java_codec(schema, target):
    codec_type = protocol_type_name(target, "CoreProtocol.java")
    imports = {
        "java.nio.ByteBuffer",
        "java.nio.ByteOrder",
        "java.nio.charset.StandardCharsets",
        "java.util.ArrayList",
    }
    for item in visible_schema_types(schema):
        imports.add(f"{java_domain_package(target, item['domain'])}.{item['name']}")
    for item in schema["enums"]:
        imports.add(f"{java_domain_package(target, item['domain'])}.{item['name']}")
    lines = [f"package {target['package']};", ""]
    for import_name in sorted(imports):
        lines.append(f"import {import_name};")
    lines.extend([
        "",
        f"public final class {codec_type} {{",
        f"    private {codec_type}() {{",
        "    }",
        "",
        "    private static void prepare(ByteBuffer data) {",
        "        data.order(ByteOrder.LITTLE_ENDIAN);",
        "    }",
    ])
    lines.extend([
        "",
        "    private static final byte[] EMPTY_BYTES = new byte[0];",
        "",
        "    private static byte[] utf8Bytes(String value) {",
        "        return value == null || value.isEmpty() ? EMPTY_BYTES : value.getBytes(StandardCharsets.UTF_8);",
        "    }",
        "",
        "    private static String readUtf8String(ByteBuffer data) {",
        "        int length = data.getInt();",
        "        if (length < 0 || length > data.remaining()) {",
        "            throw new IllegalArgumentException(\"Invalid protocol length.\");",
        "        }",
        "        if (length == 0) return \"\";",
        "        byte[] bytes = new byte[length];",
        "        data.get(bytes);",
        "        return new String(bytes, StandardCharsets.UTF_8);",
        "    }",
        "",
        "    private static void writeUtf8String(ByteBuffer data, String value) {",
        "        writeUtf8Bytes(data, utf8Bytes(value));",
        "    }",
        "",
        "    private static void writeUtf8Bytes(ByteBuffer data, byte[] bytes) {",
        "        data.putInt(bytes.length);",
        "        data.put(bytes);",
        "    }",
        "",
        "    private static int sizeOfUtf8String(String value) {",
        "        return 4 + utf8Bytes(value).length;",
        "    }",
        "",
        "    public static ByteBuffer encodeUtf8String(String value) {",
        "        byte[] bytes = utf8Bytes(value);",
        "        ByteBuffer data = ByteBuffer.allocateDirect(4 + bytes.length).order(ByteOrder.LITTLE_ENDIAN);",
        "        writeUtf8Bytes(data, bytes);",
        "        data.flip();",
        "        return data;",
        "    }",
    ])
    list_inners = list_inner_names(schema)
    for inner in list_inners:
        inner_type = "String" if infer_wire_type(inner) == "utf8_string" else inner
        read_value = "readUtf8String(data)" if inner_type == "String" else f"read{inner}(data)"
        write_value = ("writeUtf8String(data, values.get(i));"
                       if inner_type == "String"
                       else f"write{inner}Fields(data, values.get(i));")
        size_value = ("sizeOfUtf8String(values.get(i))"
                      if inner_type == "String"
                      else f"sizeOf{inner}(values.get(i))")
        if inner_needs_reader(schema, inner):
            lines.extend([
                "",
                f"    private static ArrayList<{inner_type}> read{inner}List(ByteBuffer data) {{",
                "        int count = data.getInt();",
                "        if (count < 0 || count > data.remaining()) {",
                "            throw new IllegalArgumentException(\"Invalid protocol length.\");",
                "        }",
                f"        ArrayList<{inner_type}> values = new ArrayList<>(count);",
                "        for (int i = 0; i < count; i++) {",
                f"            values.add({read_value});",
                "        }",
                "        return values;",
                "    }",
            ])
        if inner_needs_writer(schema, inner):
            lines.extend([
                "",
                f"    private static void write{inner}List(ByteBuffer data, java.util.List<? extends {inner_type}> values) {{",
                "        int count = values == null ? 0 : values.size();",
                "        data.putInt(count);",
                "        for (int i = 0; i < count; i++) {",
                f"            {write_value}",
                "        }",
                "    }",
                "",
                f"    private static int sizeOf{inner}List(java.util.List<? extends {inner_type}> values) {{",
                "        int size = 4;",
                "        if (values != null) {",
                "            for (int i = 0; i < values.size(); i++) {",
                f"                size += {size_value};",
                "            }",
                "        }",
                "        return size;",
                "    }",
            ])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            lines.extend(["", f"    private static {item['name']} read{item['name']}(ByteBuffer data) {{"])
            if not item["fields"]:
                lines.append(f"        return new {item['name']}();")
            else:
                lines.append(f"        {item['name']} value = new {item['name']}();")
                for field in item["fields"]:
                    name = field_name(field, "java")
                    lines.append(f"        value.{name} = {java_read_expr(field)};")
                lines.append("        return value;")
            lines.append("    }")
            lines.extend([
                "",
                f"    public static {item['name']} decode{item['name']}(ByteBuffer data) {{",
                "        prepare(data);",
                f"        return read{item['name']}(data);",
                "    }",
            ])
        if needs_writer(item):
            lines.extend(["", f"    private static void write{item['name']}Fields(ByteBuffer data, {item['name']} value) {{"])
            for field in item["fields"]:
                name = field_name(field, "java")
                lines.append(f"        {java_write_stmt(field, f'value.{name}', schema, internal=True)}")
            lines.append("    }")
            lines.extend([
                "",
                f"    public static void write{item['name']}(ByteBuffer data, {item['name']} value) {{",
                "        prepare(data);",
                f"        write{item['name']}Fields(data, value);",
                "    }",
            ])
            lines.extend(["", f"    public static int sizeOf{item['name']}({item['name']} value) {{"])
            if not item["fields"]:
                lines.append("        return 0;")
            else:
                lines.append("        int size = 0;")
                for field in item["fields"]:
                    name = field_name(field, "java")
                    lines.append(f"        size += {java_size_expr(field, f'value.{name}', schema)};")
                lines.append("        return size;")
            lines.append("    }")
            if item["kind"] == "payload":
                lines.extend([
                    "",
                    f"    public static ByteBuffer encode{item['name']}({item['name']} value) {{",
                ])
                if java_item_has_utf8(item, schema):
                    lines.extend(java_cached_byte_buffer_encode_value_lines(item["name"], schema, target))
                else:
                    lines.extend([
                        f"        ByteBuffer data = ByteBuffer.allocateDirect(sizeOf{item['name']}(value)).order(ByteOrder.LITTLE_ENDIAN);",
                        f"        write{item['name']}Fields(data, value);",
                        "        data.flip();",
                        "        return data;",
                    ])
                lines.append("    }")
    for item in input_pack_items(schema):
        lines.extend(generate_java_pack_methods(item, schema, target))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_java_segment_codec(schema, target):
    codec_type = protocol_type_name(target, "CoreProtocol.java")
    imports = {
        "java.lang.foreign.Arena",
        "java.lang.foreign.MemorySegment",
        "java.lang.foreign.ValueLayout",
        "java.nio.ByteOrder",
        "java.nio.charset.StandardCharsets",
        "java.util.ArrayList",
    }
    for item in visible_schema_types(schema):
        imports.add(f"{java_domain_package(target, item['domain'])}.{item['name']}")
    for item in schema["enums"]:
        imports.add(f"{java_domain_package(target, item['domain'])}.{item['name']}")
    lines = [f"package {target['package']};", ""]
    for import_name in sorted(imports):
        lines.append(f"import {import_name};")
    lines.extend([
        "",
        f"public final class {codec_type} {{",
        f"    private {codec_type}() {{",
        "    }",
        "",
        "    private static final ValueLayout.OfByte I8 = ValueLayout.JAVA_BYTE;",
        "    private static final ValueLayout.OfShort I16 = ValueLayout.JAVA_SHORT_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);",
        "    private static final ValueLayout.OfInt I32 = ValueLayout.JAVA_INT_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);",
        "    private static final ValueLayout.OfLong I64 = ValueLayout.JAVA_LONG_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);",
        "    private static final ValueLayout.OfFloat F32 = ValueLayout.JAVA_FLOAT_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);",
        "    private static final ValueLayout.OfDouble F64 = ValueLayout.JAVA_DOUBLE_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);",
        "",
        "    private static final byte[] EMPTY_BYTES = new byte[0];",
        "",
        "    private static byte[] utf8Bytes(String value) {",
        "        return value == null || value.isEmpty() ? EMPTY_BYTES : value.getBytes(StandardCharsets.UTF_8);",
        "    }",
        "",
        "    private static final class BinaryReader {",
        "        private final MemorySegment data;",
        "        private long offset;",
        "",
        "        BinaryReader(MemorySegment data, long size) {",
        "            this.data = data.asSlice(0, size);",
        "        }",
        "",
        "        int readUint8() {",
        "            int value = data.get(I8, offset) & 0xFF;",
        "            offset += 1;",
        "            return value;",
        "        }",
        "",
        "        int readUint16() {",
        "            int value = data.get(I16, offset) & 0xFFFF;",
        "            offset += 2;",
        "            return value;",
        "        }",
        "",
        "        int readInt32() {",
        "            int value = data.get(I32, offset);",
        "            offset += 4;",
        "            return value;",
        "        }",
        "",
        "        long readInt64() {",
        "            long value = data.get(I64, offset);",
        "            offset += 8;",
        "            return value;",
        "        }",
        "",
        "        float readFloat32() {",
        "            float value = data.get(F32, offset);",
        "            offset += 4;",
        "            return value;",
        "        }",
        "",
        "        double readFloat64() {",
        "            double value = data.get(F64, offset);",
        "            offset += 8;",
        "            return value;",
        "        }",
        "",
        "        String readUtf8String() {",
        "            int length = readInt32();",
        "            if (length < 0 || length > remaining()) {",
        "                throw new IllegalArgumentException(\"Invalid protocol length.\");",
        "            }",
        "            if (length == 0) return \"\";",
        "            byte[] bytes = data.asSlice(offset, length).toArray(ValueLayout.JAVA_BYTE);",
        "            offset += length;",
        "            return new String(bytes, StandardCharsets.UTF_8);",
        "        }",
        "",
        "        long remaining() {",
        "            return data.byteSize() - offset;",
        "        }",
        "    }",
        "",
        "    private static final class BinaryWriter {",
        "        private final MemorySegment data;",
        "        private long offset;",
        "",
        "        BinaryWriter(Arena arena, int size) {",
        "            this.data = arena.allocate(size);",
        "        }",
        "",
        "        MemorySegment segment() {",
        "            return data;",
        "        }",
        "",
        "        void writeUint8(int value) {",
        "            data.set(I8, offset, (byte) value);",
        "            offset += 1;",
        "        }",
        "",
        "        void writeUint16(int value) {",
        "            data.set(I16, offset, (short) value);",
        "            offset += 2;",
        "        }",
        "",
        "        void writeInt32(int value) {",
        "            data.set(I32, offset, value);",
        "            offset += 4;",
        "        }",
        "",
        "        void writeInt64(long value) {",
        "            data.set(I64, offset, value);",
        "            offset += 8;",
        "        }",
        "",
        "        void writeFloat32(float value) {",
        "            data.set(F32, offset, value);",
        "            offset += 4;",
        "        }",
        "",
        "        void writeFloat64(double value) {",
        "            data.set(F64, offset, value);",
        "            offset += 8;",
        "        }",
        "",
        "        void writeUtf8String(String value) {",
        "            writeUtf8Bytes(utf8Bytes(value));",
        "        }",
        "",
        "        void writeUtf8Bytes(byte[] bytes) {",
        "            writeInt32(bytes.length);",
        "            MemorySegment.copy(MemorySegment.ofArray(bytes), 0, data, offset, bytes.length);",
        "            offset += bytes.length;",
        "        }",
        "    }",
        "",
        "    private static int sizeOfUtf8String(String value) {",
        "        return 4 + utf8Bytes(value).length;",
        "    }",
        "",
        "    public static MemorySegment encodeUtf8String(Arena arena, String value) {",
        "        byte[] bytes = utf8Bytes(value);",
        "        BinaryWriter writer = new BinaryWriter(arena, 4 + bytes.length);",
        "        writer.writeUtf8Bytes(bytes);",
        "        return writer.segment();",
        "    }",
    ])
    list_inners = list_inner_names(schema)
    for inner in list_inners:
        inner_type = "String" if infer_wire_type(inner) == "utf8_string" else inner
        read_value = "reader.readUtf8String()" if inner_type == "String" else f"read{inner}(reader)"
        write_value = ("writer.writeUtf8String(values.get(i));"
                       if inner_type == "String"
                       else f"write{inner}(writer, values.get(i));")
        size_value = ("sizeOfUtf8String(values.get(i))"
                      if inner_type == "String"
                      else f"sizeOf{inner}(values.get(i))")
        if inner_needs_reader(schema, inner):
            lines.extend([
                "",
                f"    private static ArrayList<{inner_type}> read{inner}List(BinaryReader reader) {{",
                "        int count = reader.readInt32();",
                "        if (count < 0 || count > reader.remaining()) {",
                "            throw new IllegalArgumentException(\"Invalid protocol length.\");",
                "        }",
                f"        ArrayList<{inner_type}> values = new ArrayList<>(count);",
                "        for (int i = 0; i < count; i++) {",
                f"            values.add({read_value});",
                "        }",
                "        return values;",
                "    }",
            ])
        if inner_needs_writer(schema, inner):
            lines.extend([
                "",
                f"    private static void write{inner}List(BinaryWriter writer, java.util.List<? extends {inner_type}> values) {{",
                "        int count = values == null ? 0 : values.size();",
                "        writer.writeInt32(count);",
                "        for (int i = 0; i < count; i++) {",
                f"            {write_value}",
                "        }",
                "    }",
                "",
                f"    private static int sizeOf{inner}List(java.util.List<? extends {inner_type}> values) {{",
                "        int size = 4;",
                "        if (values != null) {",
                "            for (int i = 0; i < values.size(); i++) {",
                f"                size += {size_value};",
                "            }",
                "        }",
                "        return size;",
                "    }",
            ])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            lines.extend(["", f"    private static {item['name']} read{item['name']}(BinaryReader reader) {{"])
            if not item["fields"]:
                lines.append(f"        return new {item['name']}();")
            else:
                lines.append(f"        {item['name']} value = new {item['name']}();")
                for field in item["fields"]:
                    name = field_name(field, "java")
                    lines.append(f"        value.{name} = {java_segment_read_expr(field)};")
                lines.append("        return value;")
            lines.append("    }")
            lines.extend([
                "",
                f"    public static {item['name']} decode{item['name']}(MemorySegment data, long size) {{",
                f"        return read{item['name']}(new BinaryReader(data, size));",
                "    }",
            ])
        if needs_writer(item):
            lines.extend(["", f"    private static void write{item['name']}(BinaryWriter writer, {item['name']} value) {{"])
            for field in item["fields"]:
                name = field_name(field, "java")
                lines.append(f"        {java_segment_write_stmt(field, f'value.{name}', schema)}")
            lines.append("    }")
            lines.extend(["", f"    public static int sizeOf{item['name']}({item['name']} value) {{"])
            if not item["fields"]:
                lines.append("        return 0;")
            else:
                lines.append("        int size = 0;")
                for field in item["fields"]:
                    name = field_name(field, "java")
                    lines.append(f"        size += {java_size_expr(field, f'value.{name}', schema)};")
                lines.append("        return size;")
            lines.append("    }")
            if item["kind"] == "payload":
                lines.extend([
                    "",
                    f"    public static MemorySegment encode{item['name']}(Arena arena, {item['name']} value) {{",
                ])
                if java_item_has_utf8(item, schema):
                    lines.extend(java_cached_segment_encode_value_lines(item["name"], schema, target))
                else:
                    lines.extend([
                        f"        BinaryWriter writer = new BinaryWriter(arena, sizeOf{item['name']}(value));",
                        f"        write{item['name']}(writer, value);",
                        "        return writer.segment();",
                    ])
                lines.append("    }")
    for item in input_pack_items(schema):
        lines.extend(generate_java_segment_pack_methods(item, schema, target))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_java_enum(item, target):
    package = java_domain_package(target, item["domain"])
    if item["kind"] in ("flags", "consts"):
        lines = [f"package {package};", "", f"public final class {item['name']} {{"]
        lines.append(f"    private {item['name']}() {{")
        lines.append("    }")
        for value in item["values"]:
            lines.append(f"    public static final int {value['name']} = {value['value']};")
        lines.append("}")
        lines.append("")
        return "\n".join(lines)
    lines = [f"package {package};", "", f"public enum {item['name']} {{"]
    for index, value in enumerate(item["values"]):
        suffix = "," if index + 1 < len(item["values"]) else ";"
        lines.append(f"    {value['name']}({value['value']}){suffix}")
    lines.extend([
        "",
        "    public final int value;",
    ])
    lines.extend([
        "",
        f"    {item['name']}(int value) {{",
        "        this.value = value;",
        "    }",
        "",
        f"    public static {item['name']} fromValue(int value) {{",
        "        switch (value) {",
    ])
    for value in item["values"]:
        lines.append(f"            case {value['value']}: return {value['name']};")
    lines.extend([
        f"            default: throw new IllegalArgumentException(\"Unknown {item['name']} value: \" + value);",
        "        }",
        "    }",
        "}",
        "",
    ])
    return "\n".join(lines)

def generate_java(schema, target_name, target, out_root):
    for item in schema["enums"]:
        path = out_root / java_domain_path(target, item["domain"]) / f"{item['name']}.java"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(generate_java_enum(item, target), encoding="utf-8")
    for item in visible_schema_types(schema):
        path = out_root / java_domain_path(target, item["domain"]) / f"{item['name']}.java"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(generate_java_class(item, schema, target), encoding="utf-8")
    codec_path = out_root / target["codec_file"]
    codec_path.parent.mkdir(parents=True, exist_ok=True)
    if java_uses_memory_segment_codec(target):
        codec_path.write_text(generate_java_segment_codec(schema, target), encoding="utf-8")
    else:
        codec_path.write_text(generate_java_codec(schema, target), encoding="utf-8")
    return [str(out_root)]
