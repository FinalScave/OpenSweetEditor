from pathlib import Path

from ..ir import *


def java_domain_package(target, domain):
    base_package = target["package"]
    domain_package = domain_value(target, domain, domain).replace("/", ".")
    return f"{base_package}.{domain_package}" if domain_package else base_package

def java_domain_path(target, domain):
    return Path(domain_value(target, domain, domain))

def java_type(field, schema_types, schema_enums):
    platform_type = field.get("platform_type")
    if platform_type:
        return platform_type
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"java.util.List<{inner}>"
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

def java_default_for_field(field, java_type_name, schema_enums):
    default = field.get("default")
    if not default or "," in default:
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
    if java_type_name == "float":
        return f"{number}f"
    if java_type_name == "double":
        return f"{number}d"
    if java_type_name == "long":
        return f"{number}L"
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

def java_write_stmt(field, value_expr):
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
        return f"write{field['cpp_type']}(data, {value_expr});"
    raise SystemExit(f"Unsupported Java write wire: {wire}")

def java_size_expr(field, value_expr):
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

def java_size_value_line(field, value_expr):
    return f"        size += {java_size_expr(field, value_expr)};"

def java_write_value_line(field, value_expr):
    return f"        {java_write_stmt(field, value_expr)}"

def java_size_map_field_lines(field, param_name, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    key_type = java_boxed_type(java_type(key_field, schema_types, schema_enums))
    value_type = java_map_value_type(value_field, schema_types, schema_enums)
    lines = [
        "        size += 4;",
        f"        if ({param_name} != null) {{",
        f"            for (java.util.Map.Entry<{key_type}, ? extends {value_type}> entry : {param_name}.entrySet()) {{",
        f"                size += {java_size_expr(key_field, 'entry.getKey()')};",
    ]
    lines.append(f"                size += {java_size_expr(value_field, 'entry.getValue()')};")
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
        f"                size += {java_size_expr(key_field, f'{param_name}.keyAt(i)')};",
        f"                size += {java_size_expr(value_field, f'{param_name}.valueAt(i)')};",
        "            }",
        "        }",
    ]
    return lines

def java_write_map_field_lines(field, param_name, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    key_type = java_boxed_type(java_type(key_field, schema_types, schema_enums))
    value_type = java_map_value_type(value_field, schema_types, schema_enums)
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
        f"            {java_write_stmt(key_field, 'entry.getKey()')}",
        f"            {java_write_stmt(value_field, 'entry.getValue()')}",
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
        f"            {java_write_stmt(key_field, f'{param_name}.keyAt(i)')}",
        f"            {java_write_stmt(value_field, f'{param_name}.valueAt(i)')}",
        "        }",
    ]
    return lines

def java_size_payload_field_lines(field, param_name, schema, target):
    if map_entry_item(field, schema) is not None:
        if java_uses_sparse_line_map(field, schema, target):
            return java_size_sparse_line_map_field_lines(field, param_name, schema)
        return java_size_map_field_lines(field, param_name, schema)
    return [java_size_value_line(field, param_name)]

def java_write_payload_field_lines(field, param_name, schema, target):
    if map_entry_item(field, schema) is not None:
        if java_uses_sparse_line_map(field, schema, target):
            return java_write_sparse_line_map_field_lines(field, param_name, schema)
        return java_write_map_field_lines(field, param_name, schema)
    return [java_write_value_line(field, param_name)]

def generate_java_pack_methods(item, schema, target):
    pack_name = payload_pack_function_name(item)
    if not is_hidden_input_type(item):
        return [
            "",
            f"    public static ByteBuffer {pack_name}({item['name']} value) {{",
            f"        ByteBuffer data = ByteBuffer.allocateDirect(sizeOf{item['name']}(value)).order(ByteOrder.LITTLE_ENDIAN);",
            f"        write{item['name']}(data, value);",
            "        data.flip();",
            "        return data;",
            "    }",
        ]
    params = java_pack_params(item, schema, target)
    params_sig = ", ".join(f"{type_name} {name}" for type_name, name, _ in params)
    args = ", ".join(name for _, name, _ in params)
    wire_name = pack_name[len("pack"):]
    lines = [
        "",
        f"    private static void write{wire_name}Wire(ByteBuffer data, {params_sig}) {{",
        "        prepare(data);",
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
        "",
        f"    public static ByteBuffer {pack_name}({params_sig}) {{",
        f"        ByteBuffer data = ByteBuffer.allocateDirect(sizeOf{wire_name}Wire({args})).order(ByteOrder.LITTLE_ENDIAN);",
        f"        write{wire_name}Wire(data, {args});",
        "        data.flip();",
        "        return data;",
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
        default_expr = java_default_for_field(next(field for field in item["fields"] if field_name(field, "java") == name), java_type_name, schema_enums)
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
        "public final class EditorProtocol {",
        "    private EditorProtocol() {",
        "    }",
        "",
        "    private static void prepare(ByteBuffer data) {",
        "        data.order(ByteOrder.LITTLE_ENDIAN);",
        "    }",
        "",
        "    private static String readUtf8String(ByteBuffer data) {",
        "        int length = data.getInt();",
        "        if (length <= 0) return \"\";",
        "        byte[] bytes = new byte[length];",
        "        data.get(bytes);",
        "        return new String(bytes, StandardCharsets.UTF_8);",
        "    }",
        "",
        "    private static void writeUtf8String(ByteBuffer data, String value) {",
        "        byte[] bytes = value == null ? new byte[0] : value.getBytes(StandardCharsets.UTF_8);",
        "        data.putInt(bytes.length);",
        "        data.put(bytes);",
        "    }",
        "",
        "    private static int sizeOfUtf8String(String value) {",
        "        return 4 + (value == null ? 0 : value.getBytes(StandardCharsets.UTF_8).length);",
        "    }",
    ])
    list_inners = list_inner_names(schema)
    for inner in list_inners:
        if inner_needs_reader(schema, inner):
            lines.extend([
                "",
                f"    private static ArrayList<{inner}> read{inner}List(ByteBuffer data) {{",
                "        int count = data.getInt();",
                f"        ArrayList<{inner}> values = new ArrayList<>(Math.max(count, 0));",
                "        for (int i = 0; i < count; i++) {",
                f"            values.add(read{inner}(data));",
                "        }",
                "        return values;",
                "    }",
            ])
        if inner_needs_writer(schema, inner):
            lines.extend([
                "",
                f"    private static void write{inner}List(ByteBuffer data, java.util.List<? extends {inner}> values) {{",
                "        int count = values == null ? 0 : values.size();",
                "        data.putInt(count);",
                "        for (int i = 0; i < count; i++) {",
                f"            write{inner}(data, values.get(i));",
                "        }",
                "    }",
                "",
                f"    private static int sizeOf{inner}List(java.util.List<? extends {inner}> values) {{",
                "        int size = 4;",
                "        if (values != null) {",
                "            for (int i = 0; i < values.size(); i++) {",
                f"                size += sizeOf{inner}(values.get(i));",
                "            }",
                "        }",
                "        return size;",
                "    }",
            ])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            lines.extend(["", f"    public static {item['name']} read{item['name']}(ByteBuffer data) {{", "        prepare(data);"])
            if not item["fields"]:
                lines.append(f"        return new {item['name']}();")
            else:
                lines.append(f"        {item['name']} value = new {item['name']}();")
                for field in item["fields"]:
                    name = field_name(field, "java")
                    lines.append(f"        value.{name} = {java_read_expr(field)};")
                lines.append("        return value;")
            lines.append("    }")
        if needs_writer(item):
            lines.extend(["", f"    public static void write{item['name']}(ByteBuffer data, {item['name']} value) {{", "        prepare(data);"])
            for field in item["fields"]:
                name = field_name(field, "java")
                lines.append(f"        {java_write_stmt(field, f'value.{name}')}")
            lines.append("    }")
            lines.extend(["", f"    public static int sizeOf{item['name']}({item['name']} value) {{"])
            if not item["fields"]:
                lines.append("        return 0;")
            else:
                lines.append("        int size = 0;")
                for field in item["fields"]:
                    name = field_name(field, "java")
                    lines.append(f"        size += {java_size_expr(field, f'value.{name}')};")
                lines.append("        return size;")
            lines.append("    }")
            if item["kind"] == "payload":
                lines.extend([
                    "",
                    f"    public static ByteBuffer encode{item['name']}({item['name']} value) {{",
                    f"        ByteBuffer data = ByteBuffer.allocateDirect(sizeOf{item['name']}(value)).order(ByteOrder.LITTLE_ENDIAN);",
                    f"        write{item['name']}(data, value);",
                    "        data.flip();",
                    "        return data;",
                    "    }",
                ])
    for item in input_pack_items(schema):
        lines.extend(generate_java_pack_methods(item, schema, target))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_java_enum(item, target):
    package = java_domain_package(target, item["domain"])
    if item["kind"] == "flags":
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
        f"            default: return {item['fallback']};",
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
    codec_path.write_text(generate_java_codec(schema, target), encoding="utf-8")
    return [str(out_root)]
