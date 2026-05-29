from pathlib import Path

from ..ir import *


def swift_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"[{inner}]"
    wire = field["wire"]
    if wire == "enum_i32" and field["cpp_type"] in schema_enums:
        return field["cpp_type"]
    if wire in ("u8", "u16", "i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return "Int32"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return "Int64"
    if wire == "f32":
        return "Float"
    if wire == "f64":
        return "Double"
    if wire in ("bool_i32", "bool_u8"):
        return "Bool"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "String"
    if field["cpp_type"] in schema_types:
        return field["cpp_type"]
    raise SystemExit(f"Unsupported Swift field type: {field['cpp_type']} ({wire})")

def swift_default(swift_type_name, schema_enums=None):
    if schema_enums and swift_type_name in schema_enums:
        return f".{schema_enums[swift_type_name]['fallback']}"
    if swift_type_name == "Bool":
        return "false"
    if swift_type_name == "String":
        return "\"\""
    if swift_type_name.startswith("["):
        return "[]"
    if swift_type_name in ("Int32", "Int64", "Float", "Double"):
        return "0"
    return f"{swift_type_name}()"

def swift_default_for_field(field, swift_type_name, schema_enums):
    default = field.get("default")
    if not default or "," in default:
        return swift_default(swift_type_name, schema_enums)
    if "::" in default:
        enum_name, enum_value = default.split("::", 1)
        if enum_name in schema_enums:
            if swift_type_name == enum_name:
                return f".{enum_value}"
            return f"{enum_name}.{enum_value}"
        return swift_default(swift_type_name, schema_enums)
    if default in ("true", "false"):
        return default
    if swift_type_name in ("Int32", "Int64", "Float", "Double") and is_cpp_number(default):
        return sanitize_cpp_number(default)
    return swift_default(swift_type_name, schema_enums)

def generate_swift_domain(domain, items, enums, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    lines = ["import Foundation", ""]
    for item in enums:
        if item["kind"] == "flags":
            lines.append(f"public enum {item['name']} {{")
            for value in item["values"]:
                lines.append(f"    public static let {value['name']}: Int32 = {value['value']}")
            lines.append("}")
            lines.append("")
            continue
        lines.append(f"public enum {item['name']}: Int32 {{")
        for value in item["values"]:
            lines.append(f"    case {value['name']} = {value['value']}")
        lines.append("")
        lines.append(f"    public static func fromValue(_ value: Int32) -> {item['name']} {{")
        lines.append("        switch value {")
        for value in item["values"]:
            lines.append(f"        case {value['value']}: return .{value['name']}")
        lines.append(f"        default: return .{item['fallback']}")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
    for item in items:
        lines.append(f"public struct {item['name']} {{")
        if not item["fields"]:
            lines.append("    public init() {}")
            lines.append("}")
            lines.append("")
            continue
        init_params = []
        for field in item["fields"]:
            type_name = swift_type(field, schema_types, schema_enums)
            name = field_name(field, 'swift')
            default_value = swift_default_for_field(field, type_name, schema_enums)
            lines.append(f"    public var {name}: {type_name} = {default_value}")
            init_params.append((name, type_name, default_value))
        lines.append("")
        params = ", ".join(f"{name}: {type_name} = {default_value}" for name, type_name, default_value in init_params)
        lines.append(f"    public init({params}) {{")
        for name, _, _ in init_params:
            lines.append(f"        self.{name} = {name}")
        lines.append("    }")
        lines.append("}")
        lines.append("")
    return "\n".join(lines)

def swift_read_expr(field):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"read{inner}List(&reader)"
    if wire == "enum_i32":
        return f"read{field['cpp_type']}(&reader)"
    if wire == "u8":
        return "reader.readUInt8().map(Int32.init)"
    if wire == "u16":
        return "reader.readUInt16().map(Int32.init)"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return "reader.readInt32()"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return "reader.readInt64()"
    if wire == "f32":
        return "reader.readFloat32()"
    if wire == "f64":
        return "reader.readFloat64()"
    if wire == "bool_i32":
        return "reader.readBoolI32()"
    if wire == "bool_u8":
        return "reader.readBoolU8()"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "reader.readUtf8String()"
    if wire == "struct":
        return f"read{field['cpp_type']}(&reader)"
    raise SystemExit(f"Unsupported Swift read wire: {wire}")

def swift_write_stmt(field, value_expr):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"write{inner}List(&writer, {value_expr})"
    if wire == "enum_i32":
        return f"writer.writeInt32({value_expr}.rawValue)"
    if wire == "u8":
        return f"writer.writeUInt8(UInt8({value_expr}))"
    if wire == "u16":
        return f"writer.writeUInt16(UInt16({value_expr}))"
    if wire in ("i32", "u32", "size_as_i32", "size_as_u32", "enum_i32"):
        return f"writer.writeInt32({value_expr})"
    if wire in ("i64", "u64", "size_as_i64", "size_as_u64"):
        return f"writer.writeInt64({value_expr})"
    if wire == "f32":
        return f"writer.writeFloat32({value_expr})"
    if wire == "f64":
        return f"writer.writeFloat64({value_expr})"
    if wire == "bool_i32":
        return f"writer.writeBoolI32({value_expr})"
    if wire == "bool_u8":
        return f"writer.writeBoolU8({value_expr})"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return f"writer.writeUtf8String({value_expr})"
    if wire == "struct":
        return f"write{field['cpp_type']}(&writer, {value_expr})"
    raise SystemExit(f"Unsupported Swift write wire: {wire}")

def swift_size_expr(field, value_expr):
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
    raise SystemExit(f"Unsupported Swift size wire: {wire}")

def swift_dictionary_key_type(field, schema_types, schema_enums):
    type_name = swift_type(field, schema_types, schema_enums)
    if type_name == "Float":
        return "Float"
    if type_name == "Double":
        return "Double"
    if type_name == "Int64":
        return "Int64"
    return "Int32"

def swift_map_value_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"[{inner}]"
    return swift_type(field, schema_types, schema_enums)

def swift_pack_param_type(field, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        key_field = entry_item["fields"][0]
        value_field = entry_item["fields"][1]
        key_type = swift_dictionary_key_type(key_field, schema_types, schema_enums)
        value_type = swift_map_value_type(value_field, schema_types, schema_enums)
        return f"[{key_type}: {value_type}]"
    return swift_type(field, schema_types, schema_enums)

def swift_pack_params(item, schema):
    return [
        (swift_pack_param_type(field, schema), payload_param_name(field, "swift", schema), field)
        for field in item["fields"]
    ]

def swift_size_map_field_lines(field, param_name, schema):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    lines = [
        "        size += 4",
        f"        for key in {param_name}.keys.sorted() {{",
        f"            size += {swift_size_expr(key_field, 'key')}",
        f"            let value = {param_name}[key]!",
        f"            size += {swift_size_expr(value_field, 'value')}",
        "        }",
    ]
    return lines

def swift_write_map_field_lines(field, param_name, schema):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    lines = [
        f"        writer.writeInt32(Int32({param_name}.count))",
        f"        for key in {param_name}.keys.sorted() {{",
        f"            {swift_write_stmt(key_field, 'key')}",
        f"            let value = {param_name}[key]!",
        f"            {swift_write_stmt(value_field, 'value')}",
        "        }",
    ]
    return lines

def swift_size_payload_field_lines(field, param_name, schema):
    if map_entry_item(field, schema) is not None:
        return swift_size_map_field_lines(field, param_name, schema)
    return [f"        size += {swift_size_expr(field, param_name)}"]

def swift_write_payload_field_lines(field, param_name, schema):
    if map_entry_item(field, schema) is not None:
        return swift_write_map_field_lines(field, param_name, schema)
    return [f"        {swift_write_stmt(field, param_name)}"]

def generate_swift_pack_methods(item, schema):
    pack_name = payload_encode_function_name(item)
    if not is_hidden_input_type(item):
        return [
            "",
            f"    static func {pack_name}(_ value: {item['name']}) -> Data {{",
            "        var writer = BinaryWriter()",
            f"        write{item['name']}(&writer, value)",
            "        return writer.data()",
            "    }",
        ]
    params = swift_pack_params(item, schema)
    params_sig = ", ".join(f"{name}: {type_name}" for type_name, name, _ in params)
    args = ", ".join(f"{name}: {name}" for _, name, _ in params)
    wire_name = pack_name[len("encode"):]
    lines = [
        "",
        f"    static func write{wire_name}Wire(_ writer: inout BinaryWriter, {params_sig}) {{",
    ]
    for _, name, field in params:
        lines.extend(swift_write_payload_field_lines(field, name, schema))
    lines.append("    }")
    lines.extend([
        "",
        f"    static func sizeOf{wire_name}Wire({params_sig}) -> Int {{",
        "        var size = 0",
    ])
    for _, name, field in params:
        lines.extend(swift_size_payload_field_lines(field, name, schema))
    lines.extend([
        "        return size",
        "    }",
        "",
        f"    static func {pack_name}({params_sig}) -> Data {{",
        "        var writer = BinaryWriter()",
        f"        write{wire_name}Wire(&writer, {args})",
        "        return writer.data()",
        "    }",
    ])
    return lines

def generate_swift_codec(schema, target=None):
    codec_type = protocol_type_name(target, "CoreProtocol.swift")
    lines = [
        "import Foundation",
        "",
        f"enum {codec_type} {{",
        "    struct BinaryReader {",
        "        let data: UnsafeRawBufferPointer",
        "        var offset: Int = 0",
        "",
        "        init(_ data: UnsafeRawBufferPointer) {",
        "            self.data = data",
        "        }",
        "",
        "        var remaining: Int {",
        "            data.count - offset",
        "        }",
        "",
        "        mutating func readUInt8() -> UInt8? {",
        "            guard offset + 1 <= data.count else { return nil }",
        "            defer { offset += 1 }",
        "            return data[offset]",
        "        }",
        "",
        "        mutating func readUInt16() -> UInt16? {",
        "            guard offset + 2 <= data.count else { return nil }",
        "            let b0 = UInt16(data[offset])",
        "            let b1 = UInt16(data[offset + 1]) << 8",
        "            offset += 2",
        "            return b0 | b1",
        "        }",
        "",
        "        mutating func readUInt32() -> UInt32? {",
        "            guard offset + 4 <= data.count else { return nil }",
        "            let b0 = UInt32(data[offset])",
        "            let b1 = UInt32(data[offset + 1]) << 8",
        "            let b2 = UInt32(data[offset + 2]) << 16",
        "            let b3 = UInt32(data[offset + 3]) << 24",
        "            offset += 4",
        "            return b0 | b1 | b2 | b3",
        "        }",
        "",
        "        mutating func readInt32() -> Int32? {",
        "            guard let raw = readUInt32() else { return nil }",
        "            return Int32(bitPattern: raw)",
        "        }",
        "",
        "        mutating func readInt64() -> Int64? {",
        "            guard let low = readUInt32(), let high = readUInt32() else { return nil }",
        "            return Int64(bitPattern: UInt64(low) | (UInt64(high) << 32))",
        "        }",
        "",
        "        mutating func readFloat32() -> Float? {",
        "            guard let raw = readUInt32() else { return nil }",
        "            return Float(bitPattern: raw)",
        "        }",
        "",
        "        mutating func readFloat64() -> Double? {",
        "            guard let low = readUInt32(), let high = readUInt32() else { return nil }",
        "            return Double(bitPattern: UInt64(low) | (UInt64(high) << 32))",
        "        }",
        "",
        "        mutating func readBoolI32() -> Bool? {",
        "            guard let value = readInt32() else { return nil }",
        "            return value != 0",
        "        }",
        "",
        "        mutating func readBoolU8() -> Bool? {",
        "            guard let value = readUInt8() else { return nil }",
        "            return value != 0",
        "        }",
        "",
        "        mutating func readUtf8String() -> String? {",
        "            guard let lengthValue = readInt32(), lengthValue >= 0 else { return nil }",
        "            let length = Int(lengthValue)",
        "            guard offset + length <= data.count else { return nil }",
        "            defer { offset += length }",
        "            if length == 0 { return \"\" }",
        "            let bytes = data.bindMemory(to: UInt8.self)",
        "            return String(decoding: bytes[offset..<(offset + length)], as: UTF8.self)",
        "        }",
        "    }",
        "",
        "    struct BinaryWriter {",
        "        var bytes: [UInt8] = []",
        "",
        "        mutating func writeUInt8(_ value: UInt8) {",
        "            bytes.append(value)",
        "        }",
        "",
        "        mutating func writeUInt16(_ value: UInt16) {",
        "            var little = value.littleEndian",
        "            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }",
        "        }",
        "",
        "        mutating func writeInt32(_ value: Int32) {",
        "            var little = value.littleEndian",
        "            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }",
        "        }",
        "",
        "        mutating func writeInt64(_ value: Int64) {",
        "            var little = value.littleEndian",
        "            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }",
        "        }",
        "",
        "        mutating func writeFloat32(_ value: Float) {",
        "            writeInt32(Int32(bitPattern: value.bitPattern))",
        "        }",
        "",
        "        mutating func writeFloat64(_ value: Double) {",
        "            writeInt64(Int64(bitPattern: value.bitPattern))",
        "        }",
        "",
        "        mutating func writeBoolI32(_ value: Bool) {",
        "            writeInt32(value ? 1 : 0)",
        "        }",
        "",
        "        mutating func writeBoolU8(_ value: Bool) {",
        "            writeUInt8(value ? 1 : 0)",
        "        }",
        "",
        "        mutating func writeUtf8String(_ value: String) {",
        "            let encoded = value.data(using: .utf8) ?? Data()",
        "            writeInt32(Int32(encoded.count))",
        "            bytes.append(contentsOf: encoded)",
        "        }",
        "",
        "        func data() -> Data {",
        "            Data(bytes)",
        "        }",
        "    }",
        "",
        "    static func sizeOfUtf8String(_ value: String) -> Int {",
        "        4 + (value.data(using: .utf8)?.count ?? 0)",
        "    }",
    ]
    for item in schema["enums"]:
        if item["kind"] != "enum":
            continue
        lines.extend([
            "",
            f"    static func read{item['name']}(_ reader: inout BinaryReader) -> {item['name']}? {{",
            "        guard let value = reader.readInt32() else { return nil }",
            f"        return {item['name']}.fromValue(value)",
            "    }",
        ])
    list_inners = list_inner_names(schema)
    for inner in list_inners:
        if inner_needs_reader(schema, inner):
            lines.extend([
                "",
                f"    static func read{inner}List(_ reader: inout BinaryReader) -> [{inner}]? {{",
                "        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }",
                f"        var values: [{inner}] = []",
                "        values.reserveCapacity(Int(countValue))",
                "        for _ in 0..<Int(countValue) {",
                f"            guard let value = read{inner}(&reader) else {{ return nil }}",
                "            values.append(value)",
                "        }",
                "        return values",
                "    }",
            ])
        if inner_needs_writer(schema, inner):
            lines.extend([
                "",
                f"    static func write{inner}List(_ writer: inout BinaryWriter, _ values: [{inner}]) {{",
                "        writer.writeInt32(Int32(values.count))",
                "        for value in values {",
                f"            write{inner}(&writer, value)",
                "        }",
                "    }",
                "",
                f"    static func sizeOf{inner}List(_ values: [{inner}]) -> Int {{",
                "        var size = 4",
                "        for value in values {",
                f"            size += sizeOf{inner}(value)",
                "        }",
                "        return size",
                "    }",
            ])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            lines.extend(["", f"    static func read{item['name']}(_ reader: inout BinaryReader) -> {item['name']}? {{"])
            if not item["fields"]:
                lines.append(f"        return {item['name']}()")
            else:
                for field in item["fields"]:
                    name = field_name(field, "swift")
                    lines.append(f"        guard let {name} = {swift_read_expr(field)} else {{ return nil }}")
                args = ", ".join(f"{field_name(field, 'swift')}: {field_name(field, 'swift')}" for field in item["fields"])
                lines.append(f"        return {item['name']}({args})")
            lines.append("    }")
            lines.extend([
                "",
                f"    static func decode{item['name']}(_ data: Data) -> {item['name']}? {{",
                "        return data.withUnsafeBytes { raw in",
                f"            decode{item['name']}(raw)",
                "        }",
                "    }",
                "",
                f"    static func decode{item['name']}(_ data: UnsafeRawBufferPointer) -> {item['name']}? {{",
                "        var reader = BinaryReader(data)",
                f"        return read{item['name']}(&reader)",
                "    }",
            ])
        if needs_writer(item):
            lines.extend(["", f"    static func write{item['name']}(_ writer: inout BinaryWriter, _ value: {item['name']}) {{"])
            for field in item["fields"]:
                name = field_name(field, "swift")
                lines.append(f"        {swift_write_stmt(field, f'value.{name}')}")
            lines.append("    }")
            lines.extend(["", f"    static func sizeOf{item['name']}(_ value: {item['name']}) -> Int {{"])
            if not item["fields"]:
                lines.append("        0")
            else:
                parts = []
                for field in item["fields"]:
                    name = field_name(field, "swift")
                    parts.append(swift_size_expr(field, f"value.{name}"))
                lines.append(f"        {' + '.join(parts)}")
            lines.append("    }")
            if item["kind"] == "payload":
                lines.extend([
                    "",
                    f"    static func encode{item['name']}(_ value: {item['name']}) -> Data {{",
                    "        var writer = BinaryWriter()",
                    f"        write{item['name']}(&writer, value)",
                    "        return writer.data()",
                    "    }",
                ])
    for item in input_pack_items(schema):
        lines.extend(generate_swift_pack_methods(item, schema))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_swift(schema, target_name, target, out_root):
    by_domain = {}
    for item in visible_schema_types(schema):
        by_domain.setdefault(item["domain"], []).append(item)
    enums_by_domain = {}
    for item in schema["enums"]:
        enums_by_domain.setdefault(item["domain"], []).append(item)
        by_domain.setdefault(item["domain"], [])
    for domain, items in by_domain.items():
        path = out_root / Path(domain_value(target, domain, f"{domain}.swift"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(generate_swift_domain(domain, items, enums_by_domain.get(domain, []), schema), encoding="utf-8")
    codec_path = out_root / target["codec_file"]
    codec_path.parent.mkdir(parents=True, exist_ok=True)
    codec_path.write_text(generate_swift_codec(schema, target), encoding="utf-8")
    return [str(out_root)]

