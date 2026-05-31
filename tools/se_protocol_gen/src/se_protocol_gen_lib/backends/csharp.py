from ..ir import *


def csharp_namespace(target):
    return target.get("namespace", "SweetEditor")

def csharp_member_name(field):
    return upper_first(snake_to_camel(field["name"]))

def csharp_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"List<{inner}>"
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
        return "bool"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "string"
    if field["cpp_type"] in schema_types:
        return field["cpp_type"]
    raise SystemExit(f"Unsupported C# field type: {field['cpp_type']} ({wire})")

def csharp_default_expr(type_name, schema_enums=None):
    if type_name == "bool":
        return "false"
    if type_name == "float":
        return "0f"
    if type_name == "double":
        return "0d"
    if type_name in ("int", "long"):
        return "0"
    if type_name == "string":
        return "string.Empty"
    if type_name.startswith("List<"):
        return "new()"
    if schema_enums and type_name in schema_enums:
        enum_item = schema_enums[type_name]
        fallback = enum_item.get("fallback") or enum_item["values"][0]["name"]
        return f"{type_name}.{fallback}"
    return f"new {type_name}()"

def csharp_default_for_field(field, type_name, schema_enums):
    default = field.get("default")
    if not default or "," in default:
        return csharp_default_expr(type_name, schema_enums)
    if "::" in default:
        enum_name, enum_value = default.split("::", 1)
        if enum_name in schema_enums and type_name == enum_name:
            return f"{enum_name}.{enum_value}"
        return csharp_default_expr(type_name, schema_enums)
    if default in ("true", "false"):
        return default
    if not is_cpp_number(default):
        return csharp_default_expr(type_name, schema_enums)
    number = sanitize_cpp_number(default)
    if type_name == "float":
        return f"{number}f"
    if type_name == "double":
        return number
    if type_name == "long":
        return f"{number}L"
    if type_name == "int":
        return number
    return csharp_default_expr(type_name, schema_enums)

def csharp_read_expr(field):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"Read{inner}List(ref reader)"
    wire = field["wire"]
    if wire == "enum_i32":
        return f"({field['cpp_type']})reader.ReadInt32()"
    if wire == "u8":
        return "reader.ReadUInt8()"
    if wire == "u16":
        return "reader.ReadUInt16()"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return "reader.ReadInt32()"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return "reader.ReadInt64()"
    if wire == "f32":
        return "reader.ReadFloat32()"
    if wire == "f64":
        return "reader.ReadFloat64()"
    if wire == "bool_i32":
        return "reader.ReadBoolI32()"
    if wire == "bool_u8":
        return "reader.ReadBoolUInt8()"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "ReadUtf8String(ref reader)"
    if wire == "struct":
        return f"Read{field['cpp_type']}(ref reader)"
    raise SystemExit(f"Unsupported C# read wire: {wire}")

def csharp_write_stmt(field, value_expr):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"Write{inner}List(writer, {value_expr});"
    wire = field["wire"]
    if wire == "enum_i32":
        return f"writer.WriteInt32((int){value_expr});"
    if wire == "u8":
        return f"writer.WriteUInt8({value_expr});"
    if wire == "u16":
        return f"writer.WriteUInt16({value_expr});"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return f"writer.WriteInt32({value_expr});"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return f"writer.WriteInt64({value_expr});"
    if wire == "f32":
        return f"writer.WriteFloat32({value_expr});"
    if wire == "f64":
        return f"writer.WriteFloat64({value_expr});"
    if wire == "bool_i32":
        return f"writer.WriteBoolI32({value_expr});"
    if wire == "bool_u8":
        return f"writer.WriteBoolUInt8({value_expr});"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return f"WriteUtf8String(writer, {value_expr});"
    if wire == "struct":
        return f"Write{field['cpp_type']}(writer, {value_expr});"
    raise SystemExit(f"Unsupported C# write wire: {wire}")

def csharp_size_expr(field, value_expr):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"SizeOf{inner}List({value_expr})"
    wire = field["wire"]
    if wire in ("u8", "bool_u8"):
        return "1"
    if wire == "u16":
        return "2"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32", "f32", "bool_i32"):
        return "4"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64", "f64"):
        return "8"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return f"SizeOfUtf8String({value_expr})"
    if wire == "struct":
        return f"SizeOf{field['cpp_type']}({value_expr})"
    raise SystemExit(f"Unsupported C# size wire: {wire}")

def csharp_map_value_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"IReadOnlyList<{inner}>"
    return csharp_type(field, schema_types, schema_enums)

def csharp_pack_param_type(field, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        key_field = entry_item["fields"][0]
        value_field = entry_item["fields"][1]
        key_type = csharp_type(key_field, schema_types, schema_enums)
        value_type = csharp_map_value_type(value_field, schema_types, schema_enums)
        return f"IReadOnlyDictionary<{key_type}, {value_type}>?"
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"IReadOnlyList<{inner}>?"
    type_name = csharp_type(field, schema_types, schema_enums)
    return "string?" if type_name == "string" else type_name

def csharp_pack_params(item, schema):
    return [
        (csharp_pack_param_type(field, schema), payload_param_name(field, "java", schema), field)
        for field in item["fields"]
    ]

def csharp_indent_codec_lines(lines):
    return [line if not line else f"    {line}" for line in lines]

def csharp_size_value_line(field, value_expr):
    return f"        size += {csharp_size_expr(field, value_expr)};"

def csharp_write_value_line(field, value_expr):
    return f"        {csharp_write_stmt(field, value_expr)}"

def csharp_size_map_field_lines(field, param_name, schema):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    return [
        "        size += 4;",
        f"        if ({param_name} != null) {{",
        f"            foreach (var entry in {param_name}) {{",
        f"                size += {csharp_size_expr(key_field, 'entry.Key')};",
        f"                size += {csharp_size_expr(value_field, 'entry.Value')};",
        "            }",
        "        }",
    ]

def csharp_write_map_field_lines(field, param_name, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    key_type = csharp_type(key_field, schema_types, schema_enums)
    value_type = csharp_map_value_type(value_field, schema_types, schema_enums)
    sorted_name = f"sorted{upper_first(param_name)}"
    return [
        f"        var {sorted_name} = new SortedDictionary<{key_type}, {value_type}>();",
        f"        if ({param_name} != null) {{",
        f"            foreach (var entry in {param_name}) {{",
        f"                {sorted_name}[entry.Key] = entry.Value;",
        "            }",
        "        }",
        f"        writer.WriteInt32({sorted_name}.Count);",
        f"        foreach (var entry in {sorted_name}) {{",
        f"            {csharp_write_stmt(key_field, 'entry.Key')}",
        f"            {csharp_write_stmt(value_field, 'entry.Value')}",
        "        }",
    ]

def csharp_size_payload_field_lines(field, param_name, schema):
    if map_entry_item(field, schema) is not None:
        return csharp_size_map_field_lines(field, param_name, schema)
    return [csharp_size_value_line(field, param_name)]

def csharp_write_payload_field_lines(field, param_name, schema):
    if map_entry_item(field, schema) is not None:
        return csharp_write_map_field_lines(field, param_name, schema)
    return [csharp_write_value_line(field, param_name)]

def generate_csharp_pack_methods(item, schema):
    pack_name = upper_first(payload_encode_function_name(item))
    if not is_hidden_input_type(item):
        return csharp_indent_codec_lines([
            "",
            f"    public static byte[] {pack_name}({item['name']} value) {{",
            f"        var writer = new BinaryWriter(SizeOf{item['name']}(value));",
            f"        Write{item['name']}(writer, value);",
            "        return writer.ToArray();",
            "    }",
        ])
    params = csharp_pack_params(item, schema)
    params_sig = ", ".join(f"{type_name} {name}" for type_name, name, _ in params)
    args = ", ".join(name for _, name, _ in params)
    wire_name = pack_name[len("Encode"):]
    lines = [
        "",
        f"    private static void Write{wire_name}Wire(BinaryWriter writer, {params_sig}) {{",
    ]
    for _, name, field in params:
        lines.extend(csharp_write_payload_field_lines(field, name, schema))
    lines.append("    }")
    lines.extend([
        "",
        f"    private static int SizeOf{wire_name}Wire({params_sig}) {{",
        "        var size = 0;",
    ])
    for _, name, field in params:
        lines.extend(csharp_size_payload_field_lines(field, name, schema))
    lines.extend([
        "        return size;",
        "    }",
        "",
        f"    public static byte[] {pack_name}({params_sig}) {{",
        f"        var writer = new BinaryWriter(SizeOf{wire_name}Wire({args}));",
        f"        Write{wire_name}Wire(writer, {args});",
        "        return writer.ToArray();",
        "    }",
    ])
    return csharp_indent_codec_lines(lines)

def generate_csharp_enum(item):
    lines = []
    if item["kind"] == "flags":
        lines.append("    [Flags]")
    lines.append(f"    public enum {item['name']} {{")
    for index, value in enumerate(item["values"]):
        suffix = "," if index + 1 < len(item["values"]) else ""
        lines.append(f"        {value['name']} = {value['value']}{suffix}")
    lines.append("    }")
    return lines

def generate_csharp_class(item, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    lines = [f"    public sealed partial class {item['name']} {{"]
    if not item["fields"]:
        lines.append("    }")
        return lines
    for field in item["fields"]:
        type_name = csharp_type(field, schema_types, schema_enums)
        name = csharp_member_name(field)
        default = csharp_default_for_field(field, type_name, schema_enums)
        lines.append(f"        public {type_name} {name} {{ get; set; }} = {default};")
    lines.append("    }")
    return lines

def generate_csharp_codec(schema, target=None):
    codec_type = protocol_type_name(target, "CoreProtocol.cs")
    lines = [
        f"    public static class {codec_type} {{",
        "        private ref struct BinaryReader {",
        "            private readonly ReadOnlySpan<byte> data;",
        "            private int offset;",
        "",
        "            public BinaryReader(ReadOnlySpan<byte> data) {",
        "                this.data = data;",
        "                offset = 0;",
        "            }",
        "",
        "            public int Remaining => data.Length - offset;",
        "",
        "            public int ReadUInt8() {",
        "                return data[offset++];",
        "            }",
        "",
        "            public int ReadUInt16() {",
        "                var value = BinaryPrimitives.ReadUInt16LittleEndian(data.Slice(offset));",
        "                offset += 2;",
        "                return value;",
        "            }",
        "",
        "            public int ReadInt32() {",
        "                var value = BinaryPrimitives.ReadInt32LittleEndian(data.Slice(offset));",
        "                offset += 4;",
        "                return value;",
        "            }",
        "",
        "            public long ReadInt64() {",
        "                var value = BinaryPrimitives.ReadInt64LittleEndian(data.Slice(offset));",
        "                offset += 8;",
        "                return value;",
        "            }",
        "",
        "            public float ReadFloat32() {",
        "                return BitConverter.Int32BitsToSingle(ReadInt32());",
        "            }",
        "",
        "            public double ReadFloat64() {",
        "                return BitConverter.Int64BitsToDouble(ReadInt64());",
        "            }",
        "",
        "            public bool ReadBoolI32() {",
        "                return ReadInt32() != 0;",
        "            }",
        "",
        "            public bool ReadBoolUInt8() {",
        "                return ReadUInt8() != 0;",
        "            }",
        "",
        "            public ReadOnlySpan<byte> ReadBytes(int length) {",
        "                var value = data.Slice(offset, length);",
        "                offset += length;",
        "                return value;",
        "            }",
        "        }",
        "",
        "        private sealed class BinaryWriter {",
        "            private readonly byte[] data;",
        "            private int offset;",
        "",
        "            public BinaryWriter(int size) {",
        "                data = new byte[size];",
        "                offset = 0;",
        "            }",
        "",
        "            public byte[] ToArray() {",
        "                return data;",
        "            }",
        "",
        "            public void WriteUInt8(int value) {",
        "                data[offset++] = unchecked((byte)value);",
        "            }",
        "",
        "            public void WriteUInt16(int value) {",
        "                BinaryPrimitives.WriteUInt16LittleEndian(data.AsSpan(offset), unchecked((ushort)value));",
        "                offset += 2;",
        "            }",
        "",
        "            public void WriteInt32(int value) {",
        "                BinaryPrimitives.WriteInt32LittleEndian(data.AsSpan(offset), value);",
        "                offset += 4;",
        "            }",
        "",
        "            public void WriteInt64(long value) {",
        "                BinaryPrimitives.WriteInt64LittleEndian(data.AsSpan(offset), value);",
        "                offset += 8;",
        "            }",
        "",
        "            public void WriteFloat32(float value) {",
        "                WriteInt32(BitConverter.SingleToInt32Bits(value));",
        "            }",
        "",
        "            public void WriteFloat64(double value) {",
        "                WriteInt64(BitConverter.DoubleToInt64Bits(value));",
        "            }",
        "",
        "            public void WriteBoolI32(bool value) {",
        "                WriteInt32(value ? 1 : 0);",
        "            }",
        "",
        "            public void WriteBoolUInt8(bool value) {",
        "                WriteUInt8(value ? 1 : 0);",
        "            }",
        "",
        "            public void WriteBytes(ReadOnlySpan<byte> bytes) {",
        "                bytes.CopyTo(data.AsSpan(offset));",
        "                offset += bytes.Length;",
        "            }",
        "        }",
        "",
        "        private static string ReadUtf8String(ref BinaryReader reader) {",
        "            var length = reader.ReadInt32();",
        "            if (length < 0 || length > reader.Remaining) throw new InvalidOperationException(\"Invalid protocol length.\");",
        "            if (length == 0) return string.Empty;",
        "            return Encoding.UTF8.GetString(reader.ReadBytes(length));",
        "        }",
        "",
        "        private static void WriteUtf8String(BinaryWriter writer, string? value) {",
        "            var bytes = value == null ? Array.Empty<byte>() : Encoding.UTF8.GetBytes(value);",
        "            writer.WriteInt32(bytes.Length);",
        "            writer.WriteBytes(bytes);",
        "        }",
        "",
        "        private static int SizeOfUtf8String(string? value) {",
        "            return 4 + (value == null ? 0 : Encoding.UTF8.GetByteCount(value));",
        "        }",
    ]
    for inner in list_inner_names(schema):
        if inner_needs_reader(schema, inner):
            lines.extend([
                "",
                f"        private static List<{inner}> Read{inner}List(ref BinaryReader reader) {{",
                "            var count = reader.ReadInt32();",
                "            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException(\"Invalid protocol length.\");",
                f"            var values = new List<{inner}>(count);",
                "            for (var i = 0; i < count; i++) {",
                f"                values.Add(Read{inner}(ref reader));",
                "            }",
                "            return values;",
                "        }",
            ])
        if inner_needs_writer(schema, inner):
            lines.extend([
                "",
                f"        private static void Write{inner}List(BinaryWriter writer, IReadOnlyList<{inner}>? values) {{",
                "            var count = values == null ? 0 : values.Count;",
                "            writer.WriteInt32(count);",
                "            for (var i = 0; i < count; i++) {",
                f"                Write{inner}(writer, values![i]);",
                "            }",
                "        }",
                "",
                f"        private static int SizeOf{inner}List(IReadOnlyList<{inner}>? values) {{",
                "            var size = 4;",
                "            if (values != null) {",
                "                for (var i = 0; i < values.Count; i++) {",
                f"                    size += SizeOf{inner}(values[i]);",
                "                }",
                "            }",
                "            return size;",
                "        }",
            ])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            lines.extend(["", f"        private static {item['name']} Read{item['name']}(ref BinaryReader reader) {{"])
            if not item["fields"]:
                lines.append(f"            return new {item['name']}();")
            else:
                lines.append(f"            return new {item['name']} {{")
                for field in item["fields"]:
                    name = csharp_member_name(field)
                    lines.append(f"                {name} = {csharp_read_expr(field)},")
                lines.append("            };")
            lines.append("        }")
            lines.extend([
                "",
                f"        public static {item['name']} Decode{item['name']}(ReadOnlySpan<byte> data) {{",
                "            var reader = new BinaryReader(data);",
                f"            return Read{item['name']}(ref reader);",
                "        }",
            ])
        if needs_writer(item):
            lines.extend(["", f"        private static void Write{item['name']}(BinaryWriter writer, {item['name']} value) {{"])
            for field in item["fields"]:
                name = csharp_member_name(field)
                lines.append(f"            {csharp_write_stmt(field, f'value.{name}')}")
            lines.append("        }")
            lines.extend(["", f"        private static int SizeOf{item['name']}({item['name']} value) {{"])
            if not item["fields"]:
                lines.append("            return 0;")
            else:
                lines.append("            var size = 0;")
                for field in item["fields"]:
                    name = csharp_member_name(field)
                    lines.append(f"            size += {csharp_size_expr(field, f'value.{name}')};")
                lines.append("            return size;")
            lines.append("        }")
            if item["kind"] == "payload":
                lines.extend([
                    "",
                    f"        public static byte[] Encode{item['name']}({item['name']} value) {{",
                    f"            var writer = new BinaryWriter(SizeOf{item['name']}(value));",
                    f"            Write{item['name']}(writer, value);",
                    "            return writer.ToArray();",
                    "        }",
                ])
    for item in input_pack_items(schema):
        lines.extend(generate_csharp_pack_methods(item, schema))
    lines.append("    }")
    return lines

def generate_csharp_domain_file(domain, items, enums, schema, target):
    lines = [
        "#nullable enable",
        "using System;",
        "using System.Collections.Generic;",
        "",
        f"namespace {csharp_namespace(target)} {{",
    ]
    for item in enums:
        lines.append("")
        lines.extend(generate_csharp_enum(item))
    for item in items:
        lines.append("")
        lines.extend(generate_csharp_class(item, schema))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_csharp_codec_file(schema, target):
    lines = [
        "#nullable enable",
        "using System;",
        "using System.Buffers.Binary;",
        "using System.Collections.Generic;",
        "using System.Text;",
        "",
        f"namespace {csharp_namespace(target)} {{",
        "",
    ]
    lines.extend(generate_csharp_codec(schema, target))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_csharp_file(schema, target):
    lines = [
        "#nullable enable",
        "using System;",
        "using System.Buffers.Binary;",
        "using System.Collections.Generic;",
        "using System.Text;",
        "",
        f"namespace {csharp_namespace(target)} {{",
    ]
    for item in schema["enums"]:
        lines.append("")
        lines.extend(generate_csharp_enum(item))
    for item in visible_schema_types(schema):
        lines.append("")
        lines.extend(generate_csharp_class(item, schema))
    lines.append("")
    lines.extend(generate_csharp_codec(schema, target))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def csharp_domain_file(target, domain):
    return domain_value(target, domain, f"{upper_first(domain)}.cs")

def generate_csharp(schema, target_name, target, out_root):
    written = []
    if target.get("layout") == "split_by_domain":
        items_by_domain = {}
        enums_by_domain = {}
        for item in visible_schema_types(schema):
            items_by_domain.setdefault(item["domain"], []).append(item)
        for item in schema["enums"]:
            enums_by_domain.setdefault(item["domain"], []).append(item)
        domains = list(target_domains(target).keys())
        for domain in sorted(set(items_by_domain) | set(enums_by_domain)):
            if domain not in domains:
                domains.append(domain)
        for domain in domains:
            path = out_root / csharp_domain_file(target, domain)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(
                generate_csharp_domain_file(
                    domain,
                    items_by_domain.get(domain, []),
                    enums_by_domain.get(domain, []),
                    schema,
                    target,
                ),
                encoding="utf-8",
            )
            written.append(str(path))
        codec_path = out_root / target.get("codec_file", "CoreProtocol.cs")
        codec_path.parent.mkdir(parents=True, exist_ok=True)
        codec_path.write_text(generate_csharp_codec_file(schema, target), encoding="utf-8")
        written.append(str(codec_path))
        return written
    path = out_root / target.get("file", "CoreProtocol.cs")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(generate_csharp_file(schema, target), encoding="utf-8")
    return [str(path)]
