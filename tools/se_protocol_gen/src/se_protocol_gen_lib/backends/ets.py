from pathlib import Path

from ..ir import *


def ets_domain_file(target, domain):
    return Path(domain_value(target, domain, f"Core{domain[:1].upper()}{domain[1:]}.ets"))

def ets_enum_helper(enum_name):
    return f"{lower_first(enum_name)}FromValue"

def ets_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        inner_type = "string" if infer_wire_type(inner) == "utf8_string" else inner
        return f"{inner_type}[]"
    wire = field["wire"]
    if wire == "enum_i32" and field["cpp_type"] in schema_enums:
        return field["cpp_type"]
    if wire in ("u8", "u16", "i32", "u32", "size_as_i32", "size_as_u32", "enum_i32", "i64", "u64", "size_as_i64", "size_as_u64", "f32", "f64"):
        return "number"
    if wire in ("bool_i32", "bool_u8"):
        return "boolean"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "string"
    if field["cpp_type"] in schema_types:
        return field["cpp_type"]
    raise SystemExit(f"Unsupported ETS field type: {field['cpp_type']} ({wire})")

def ets_default_expr(type_name, schema_types, schema_enums, visited=None):
    if type_name == "number":
        return "0"
    if type_name == "boolean":
        return "false"
    if type_name == "string":
        return "''"
    if type_name.endswith("[]"):
        return "[]"
    if type_name in schema_enums:
        enum_item = schema_enums[type_name]
        fallback = enum_item.get("fallback") or enum_item["values"][0]["name"]
        return f"{type_name}.{fallback}"
    if type_name not in schema_types:
        return "{}"
    if visited is None:
        visited = set()
    if type_name in visited:
        return f"new {type_name}()"
    item = schema_types[type_name]
    if item["direction"] == "in":
        return f"new {type_name}()"
    nested_visited = set(visited)
    nested_visited.add(type_name)
    values = []
    for field in item["fields"]:
        field_type = ets_type(field, schema_types, schema_enums)
        default_expr = ets_default_for_field(field, field_type, schema_types, schema_enums)
        if default_expr is None:
            default_expr = ets_default_expr(field_type, schema_types, schema_enums, nested_visited)
        values.append(f"{field_name(field, 'ets')}: {default_expr}")
    return "{ " + ", ".join(values) + " }"

def ets_read_expr(field, codec_type):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"{codec_type}.read{inner}List(reader)"
    if wire == "enum_i32":
        return f"{ets_enum_helper(field['cpp_type'])}(reader.readInt32())"
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
        return "reader.readInt32() !== 0"
    if wire == "bool_u8":
        return "reader.readUint8() !== 0"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "reader.readUtf8String()"
    if wire == "struct":
        return f"{codec_type}.read{field['cpp_type']}(reader)"
    raise SystemExit(f"Unsupported ETS read wire: {wire}")

def ets_write_stmt(field, value_expr, codec_type):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"{codec_type}.write{inner}List(writer, {value_expr});"
    if wire == "enum_i32":
        return f"writer.writeInt32({value_expr} as number);"
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
        return f"{codec_type}.write{field['cpp_type']}(writer, {value_expr});"
    raise SystemExit(f"Unsupported ETS write wire: {wire}")

def ets_size_expr(field, value_expr, codec_type):
    wire = field["wire"]
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"{codec_type}.sizeOf{inner}List({value_expr})"
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
        return f"{codec_type}.sizeOfUtf8String({value_expr})"
    if wire == "struct":
        return f"{codec_type}.sizeOf{field['cpp_type']}({value_expr})"
    raise SystemExit(f"Unsupported ETS size wire: {wire}")

def ets_default_for_field(field, ets_type_name, schema_types, schema_enums):
    default = field.get("default")
    if not default:
        return None
    if "," in default:
        if field["wire"] == "struct" and field["cpp_type"] in schema_types:
            parts = [sanitize_cpp_number(part) for part in default.split(",")]
            struct_fields = schema_types[field["cpp_type"]].get("fields", [])
            if all(is_cpp_number(part) for part in parts) and len(parts) == len(struct_fields):
                values = [
                    f"{field_name(struct_field, 'ets')}: {part}"
                    for part, struct_field in zip(parts, struct_fields)
                ]
                return "{ " + ", ".join(values) + " }"
        return None
    if "::" in default:
        enum_name, enum_value = default.split("::", 1)
        if enum_name in schema_enums:
            return f"{enum_name}.{enum_value}"
        return None
    if default in ("true", "false"):
        return default
    if ets_type_name == "number" and is_cpp_number(default):
        return sanitize_cpp_number(default)
    return None

def ets_map_value_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"{inner}[]"
    return ets_type(field, schema_types, schema_enums)

def ets_pack_param_type(field, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        key_field = entry_item["fields"][0]
        value_field = entry_item["fields"][1]
        key_type = ets_type(key_field, schema_types, schema_enums)
        value_type = ets_map_value_type(value_field, schema_types, schema_enums)
        return f"Map<{key_type}, {value_type}>"
    return ets_type(field, schema_types, schema_enums)

def ets_pack_params(item, schema):
    return [
        (ets_pack_param_type(field, schema), payload_param_name(field, "ets", schema), field)
        for field in item["fields"]
    ]

def ets_size_map_field_lines(field, param_name, schema, codec_type):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    keys_name = f"{param_name}Keys"
    lines = [
        "    size += 4;",
        f"    const {keys_name} = {param_name} ? Array.from({param_name}.keys()).sort((a, b) => a - b) : [];",
        f"    for (const key of {keys_name}) {{",
        f"      size += {ets_size_expr(key_field, 'key', codec_type)};",
        f"      const value = {param_name}.get(key)!;",
    ]
    if vector_inner(value_field["cpp_type"]) is not None:
        lines.append(f"      size += {ets_size_expr(value_field, 'value', codec_type)};")
    else:
        lines.append(f"      size += {ets_size_expr(value_field, 'value', codec_type)};")
    lines.append("    }")
    return lines

def ets_write_map_field_lines(field, param_name, schema, codec_type):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    keys_name = f"{param_name}Keys"
    lines = [
        f"    const {keys_name} = {param_name} ? Array.from({param_name}.keys()).sort((a, b) => a - b) : [];",
        f"    writer.writeInt32({keys_name}.length);",
        f"    for (const key of {keys_name}) {{",
        f"      {ets_write_stmt(key_field, 'key', codec_type)}",
        f"      const value = {param_name}.get(key)!;",
    ]
    if vector_inner(value_field["cpp_type"]) is not None:
        lines.append(f"      {ets_write_stmt(value_field, 'value', codec_type)}")
    else:
        lines.append(f"      {ets_write_stmt(value_field, 'value', codec_type)}")
    lines.append("    }")
    return lines

def ets_size_payload_field_lines(field, param_name, schema, codec_type):
    if map_entry_item(field, schema) is not None:
        return ets_size_map_field_lines(field, param_name, schema, codec_type)
    return [f"    size += {ets_size_expr(field, param_name, codec_type)};"]

def ets_write_payload_field_lines(field, param_name, schema, codec_type):
    if map_entry_item(field, schema) is not None:
        return ets_write_map_field_lines(field, param_name, schema, codec_type)
    return [f"    {ets_write_stmt(field, param_name, codec_type)}"]

def generate_ets_pack_methods(item, schema, codec_type):
    pack_name = payload_encode_function_name(item)
    if not is_hidden_input_type(item):
        return [
            "",
            f"  static {pack_name}(value: {item['name']}): ArrayBuffer {{",
            f"    const writer = new BinaryWriter({codec_type}.sizeOf{item['name']}(value));",
            f"    {codec_type}.write{item['name']}(writer, value);",
            "    return writer.getBuffer();",
            "  }",
        ]
    params = ets_pack_params(item, schema)
    params_sig = ", ".join(f"{name}: {type_name}" for type_name, name, _ in params)
    args = ", ".join(name for _, name, _ in params)
    wire_name = pack_name[len("encode"):]
    lines = [
        "",
        f"  private static write{wire_name}Wire(writer: BinaryWriter, {params_sig}): void {{",
    ]
    for _, name, field in params:
        lines.extend(ets_write_payload_field_lines(field, name, schema, codec_type))
    lines.append("  }")
    lines.extend([
        "",
        f"  private static sizeOf{wire_name}Wire({params_sig}): number {{",
        "    let size = 0;",
    ])
    for _, name, field in params:
        lines.extend(ets_size_payload_field_lines(field, name, schema, codec_type))
    lines.extend([
        "    return size;",
        "  }",
        "",
        f"  static {pack_name}({params_sig}): ArrayBuffer {{",
        f"    const writer = new BinaryWriter({codec_type}.sizeOf{wire_name}Wire({args}));",
        f"    {codec_type}.write{wire_name}Wire(writer, {args});",
        "    return writer.getBuffer();",
        "  }",
    ])
    return lines

def generate_ets_domain(domain, items, enums, schema, target):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    imports = {}
    for item in items:
        for field in item["fields"]:
            custom = field_type_name(field)
            if custom in schema_types and schema_types[custom]["domain"] != domain:
                imports.setdefault(schema_types[custom]["domain"], set()).add(custom)
            if custom in schema_enums and schema_enums[custom]["domain"] != domain:
                imports.setdefault(schema_enums[custom]["domain"], set()).add(custom)
    lines = []
    for other_domain, names in sorted(imports.items()):
        import_file = ets_domain_file(target, other_domain).stem
        lines.append(f"import {{ {', '.join(sorted(names))} }} from './{import_file}';")
    if imports:
        lines.append("")
    for item in enums:
        if item["kind"] in ("flags", "consts"):
            lines.append(f"export class {item['name']} {{")
            for value in item["values"]:
                lines.append(f"  static readonly {value['name']}: number = {value['value']};")
            lines.append("}")
            lines.append("")
            continue
        lines.append(f"export enum {item['name']} {{")
        for value in item["values"]:
            lines.append(f"  {value['name']} = {value['value']},")
        lines.append("}")
        lines.append("")
        lines.append(f"export function {ets_enum_helper(item['name'])}(value: number): {item['name']} {{")
        lines.append("  switch (value) {")
        for value in item["values"]:
            lines.append(f"    case {value['value']}: return {item['name']}.{value['name']};")
        lines.append(f"    default: throw new Error('Unknown {item['name']} value: ' + value);")
        lines.append("  }")
        lines.append("}")
        lines.append("")
    for item in items:
        if item["direction"] == "in":
            lines.append(f"export class {item['name']} {{")
            for field in item["fields"]:
                type_name = ets_type(field, schema_types, schema_enums)
                default_expr = ets_default_for_field(field, type_name, schema_types, schema_enums)
                if default_expr is None:
                    default_expr = ets_default_expr(type_name, schema_types, schema_enums)
                lines.append(f"  {field_name(field, 'ets')}: {type_name} = {default_expr};")
            lines.append("}")
            lines.append("")
            continue
        lines.append(f"export interface {item['name']} {{")
        for field in item["fields"]:
            lines.append(f"  {field_name(field, 'ets')}: {ets_type(field, schema_types, schema_enums)};")
        lines.append("}")
        lines.append("")
    return "\n".join(lines)

def generate_ets_codec(schema, target):
    codec_type = protocol_type_name(target, "CoreProtocol.ets")
    imports = {}
    for item in visible_schema_types(schema):
        imports.setdefault(item["domain"], set()).add(item["name"])
    for item in schema["enums"]:
        imports.setdefault(item["domain"], set()).add(item["name"])
        if item["kind"] == "enum":
            imports.setdefault(item["domain"], set()).add(ets_enum_helper(item["name"]))
    lines = ["import util from '@ohos.util';"]
    for domain, names in sorted(imports.items()):
        import_file = ets_domain_file(target, domain).stem
        lines.append(f"import {{ {', '.join(sorted(names))} }} from './{import_file}';")
    lines.extend([
        "",
        "const UTF8_DECODER = new util.TextDecoder('utf-8');",
        "const UTF8_ENCODER = new util.TextEncoder();",
        "",
        "function encodeUtf8(value: string): Uint8Array {",
        "  const text = value ? value : '';",
        "  if (text.length === 0) {",
        "    return new Uint8Array(0);",
        "  }",
        "  return UTF8_ENCODER.encodeInto(text);",
        "}",
        "",
        "export class BinaryReader {",
        "  private view: DataView;",
        "  private offset: number = 0;",
        "",
        "  constructor(buffer: ArrayBuffer) {",
        "    this.view = new DataView(buffer);",
        "  }",
        "",
        "  get remaining(): number {",
        "    return this.view.byteLength - this.offset;",
        "  }",
        "",
        "  readUint8(): number {",
        "    const value = this.view.getUint8(this.offset);",
        "    this.offset += 1;",
        "    return value;",
        "  }",
        "",
        "  readUint16(): number {",
        "    const value = this.view.getUint16(this.offset, true);",
        "    this.offset += 2;",
        "    return value;",
        "  }",
        "",
        "  readInt32(): number {",
        "    const value = this.view.getInt32(this.offset, true);",
        "    this.offset += 4;",
        "    return value;",
        "  }",
        "",
        "  readInt64(): number {",
        "    const lo = this.view.getUint32(this.offset, true);",
        "    const hi = this.view.getInt32(this.offset + 4, true);",
        "    this.offset += 8;",
        "    return hi * 0x100000000 + lo;",
        "  }",
        "",
        "  readFloat32(): number {",
        "    const value = this.view.getFloat32(this.offset, true);",
        "    this.offset += 4;",
        "    return value;",
        "  }",
        "",
        "  readFloat64(): number {",
        "    const value = this.view.getFloat64(this.offset, true);",
        "    this.offset += 8;",
        "    return value;",
        "  }",
        "",
        "  readUtf8String(): string {",
        "    const length = this.readInt32();",
        "    if (length < 0 || length > this.remaining) {",
        "      throw new Error('Invalid protocol length.');",
        "    }",
        "    if (length === 0) {",
        "      return '';",
        "    }",
        "    const bytes = new Uint8Array(this.view.buffer, this.offset, length);",
        "    this.offset += length;",
        "    return UTF8_DECODER.decodeToString(bytes);",
        "  }",
        "}",
        "",
        "export class BinaryWriter {",
        "  private buffer: ArrayBuffer;",
        "  private view: DataView;",
        "  private offset: number = 0;",
        "",
        "  constructor(size: number) {",
        "    this.buffer = new ArrayBuffer(size);",
        "    this.view = new DataView(this.buffer);",
        "  }",
        "",
        "  writeUint8(value: number): void {",
        "    this.view.setUint8(this.offset, value);",
        "    this.offset += 1;",
        "  }",
        "",
        "  writeUint16(value: number): void {",
        "    this.view.setUint16(this.offset, value, true);",
        "    this.offset += 2;",
        "  }",
        "",
        "  writeInt32(value: number): void {",
        "    this.view.setInt32(this.offset, value, true);",
        "    this.offset += 4;",
        "  }",
        "",
        "  writeInt64(value: number): void {",
        "    const lo = value & 0xFFFFFFFF;",
        "    const hi = Math.floor(value / 0x100000000);",
        "    this.view.setInt32(this.offset, lo, true);",
        "    this.view.setInt32(this.offset + 4, hi, true);",
        "    this.offset += 8;",
        "  }",
        "",
        "  writeFloat32(value: number): void {",
        "    this.view.setFloat32(this.offset, value, true);",
        "    this.offset += 4;",
        "  }",
        "",
        "  writeFloat64(value: number): void {",
        "    this.view.setFloat64(this.offset, value, true);",
        "    this.offset += 8;",
        "  }",
        "",
        "  writeUtf8String(value: string): void {",
        "    const bytes = encodeUtf8(value);",
        "    this.writeInt32(bytes.length);",
        "    new Uint8Array(this.buffer, this.offset, bytes.length).set(bytes);",
        "    this.offset += bytes.length;",
        "  }",
        "",
        "  getBuffer(): ArrayBuffer {",
        "    return this.buffer;",
        "  }",
        "}",
        "",
        f"export class {codec_type} {{",
        "  private static readerFor(buffer: ArrayBuffer | undefined): BinaryReader {",
        "    if (!buffer) {",
        "      throw new Error('Missing protocol payload.');",
        "    }",
        "    return new BinaryReader(buffer);",
        "  }",
        "",
        "  private static sizeOfUtf8String(value: string): number {",
        "    return 4 + encodeUtf8(value).length;",
        "  }",
        "",
        "  static encodeUtf8String(value: string): ArrayBuffer {",
        f"    const writer = new BinaryWriter({codec_type}.sizeOfUtf8String(value));",
        "    writer.writeUtf8String(value);",
        "    return writer.getBuffer();",
        "  }",
    ])
    list_inners = list_inner_names(schema)
    for inner in list_inners:
        inner_type = "string" if infer_wire_type(inner) == "utf8_string" else inner
        read_value = "reader.readUtf8String()" if inner_type == "string" else f"{codec_type}.read{inner}(reader)"
        write_value = "writer.writeUtf8String(values[i]);" if inner_type == "string" else f"{codec_type}.write{inner}(writer, values[i]);"
        size_value = f"{codec_type}.sizeOfUtf8String(value)" if inner_type == "string" else f"{codec_type}.sizeOf{inner}(value)"
        if inner_needs_reader(schema, inner):
            lines.extend([
                "",
                f"  private static read{inner}List(reader: BinaryReader): {inner_type}[] {{",
                "    const count = reader.readInt32();",
                "    if (count < 0 || count > reader.remaining) {",
                "      throw new Error('Invalid protocol length.');",
                "    }",
                f"    const values: {inner_type}[] = [];",
                "    for (let i = 0; i < count; i++) {",
                f"      values.push({read_value});",
                "    }",
                "    return values;",
                "  }",
            ])
        if inner_needs_writer(schema, inner):
            lines.extend([
                "",
                f"  private static write{inner}List(writer: BinaryWriter, values: {inner_type}[]): void {{",
                "    const count = values ? values.length : 0;",
                "    writer.writeInt32(count);",
                "    for (let i = 0; i < count; i++) {",
                f"      {write_value}",
                "    }",
                "  }",
                "",
                f"  private static sizeOf{inner}List(values: {inner_type}[]): number {{",
                "    let size = 4;",
                "    if (values) {",
                "      for (const value of values) {",
                f"        size += {size_value};",
                "      }",
                "    }",
                "    return size;",
                "  }",
            ])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            lines.extend(["", f"  private static read{item['name']}(reader: BinaryReader): {item['name']} {{", "    return {"])
            for index, field in enumerate(item["fields"]):
                suffix = "," if index + 1 < len(item["fields"]) else ""
                lines.append(f"      {field_name(field, 'ets')}: {ets_read_expr(field, codec_type)}{suffix}")
            lines.extend(["    };", "  }"])
            lines.extend([
                "",
                f"  static decode{item['name']}(buffer: ArrayBuffer | undefined): {item['name']} {{",
                f"    return {codec_type}.read{item['name']}({codec_type}.readerFor(buffer));",
                "  }",
            ])
        if needs_writer(item):
            lines.extend(["", f"  static write{item['name']}(writer: BinaryWriter, value: {item['name']}): void {{"])
            for field in item["fields"]:
                name = field_name(field, "ets")
                lines.append(f"    {ets_write_stmt(field, f'value.{name}', codec_type)}")
            lines.append("  }")
            lines.extend(["", f"  static sizeOf{item['name']}(value: {item['name']}): number {{", "    let size = 0;"])
            for field in item["fields"]:
                name = field_name(field, "ets")
                lines.append(f"    size += {ets_size_expr(field, f'value.{name}', codec_type)};")
            lines.extend(["    return size;", "  }"])
            if item["kind"] == "payload":
                lines.extend([
                    "",
                    f"  static encode{item['name']}(value: {item['name']}): ArrayBuffer {{",
                    f"    const writer = new BinaryWriter({codec_type}.sizeOf{item['name']}(value));",
                    f"    {codec_type}.write{item['name']}(writer, value);",
                    "    return writer.getBuffer();",
                    "  }",
                ])
    for item in input_pack_items(schema):
        lines.extend(generate_ets_pack_methods(item, schema, codec_type))
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def generate_ets(schema, target_name, target, out_root):
    by_domain = {}
    for item in visible_schema_types(schema):
        by_domain.setdefault(item["domain"], []).append(item)
    enums_by_domain = {}
    for item in schema["enums"]:
        enums_by_domain.setdefault(item["domain"], []).append(item)
        by_domain.setdefault(item["domain"], [])
    for domain, items in by_domain.items():
        path = out_root / ets_domain_file(target, domain)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(generate_ets_domain(domain, items, enums_by_domain.get(domain, []), schema, target), encoding="utf-8")
    codec_path = out_root / target["codec_file"]
    codec_path.parent.mkdir(parents=True, exist_ok=True)
    codec_path.write_text(generate_ets_codec(schema, target), encoding="utf-8")
    return [str(out_root)]
