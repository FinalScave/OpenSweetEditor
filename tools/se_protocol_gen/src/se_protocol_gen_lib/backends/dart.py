from ..ir import *


DART_RESERVED = {
    "abstract", "as", "assert", "async", "await", "base", "break", "case",
    "catch", "class", "const", "continue", "covariant", "default", "deferred",
    "do", "dynamic", "else", "enum", "export", "extends", "extension", "external",
    "factory", "false", "final", "finally", "for", "Function", "get", "hide",
    "if", "implements", "import", "in", "interface", "is", "late", "library",
    "mixin", "new", "null", "on", "operator", "part", "required", "rethrow",
    "return", "sealed", "set", "show", "static", "super", "switch", "sync",
    "this", "throw", "true", "try", "typedef", "var", "void", "when", "while",
    "with", "yield",
}


def dart_name(name):
    result = snake_to_camel(name.lower())
    return f"{result}_" if result in DART_RESERVED else result

def dart_field_name(field):
    return dart_name(field["name"])

def dart_enum_value_name(name):
    return dart_name(name)

def dart_uses_ffi_pointer(target):
    return target is not None

def dart_part_of(target):
    return target.get("part_of") if target else None

def dart_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"List<{inner}>"
    wire = field["wire"]
    if wire == "enum_i32" and field["cpp_type"] in schema_enums:
        return field["cpp_type"]
    if wire in ("u8", "u16", "i32", "u32", "i64", "u64", "size_as_i32", "size_as_u32", "size_as_i64", "size_as_u64", "enum_i32"):
        return "int"
    if wire in ("f32", "f64"):
        return "double"
    if wire in ("bool_i32", "bool_u8"):
        return "bool"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "String"
    if field["cpp_type"] in schema_types:
        return field["cpp_type"]
    raise SystemExit(f"Unsupported Dart field type: {field['cpp_type']} ({wire})")

def dart_default_expr(type_name, schema_enums=None):
    if type_name == "bool":
        return "false"
    if type_name == "int":
        return "0"
    if type_name == "double":
        return "0.0"
    if type_name == "String":
        return "''"
    if type_name.startswith("List<"):
        return "const []"
    if schema_enums and type_name in schema_enums:
        enum_item = schema_enums[type_name]
        fallback = enum_item.get("fallback") or enum_item["values"][0]["name"]
        return f"{type_name}.{dart_enum_value_name(fallback)}"
    return f"const {type_name}()"

def dart_default_for_field(field, type_name, schema_enums):
    default = field.get("default")
    if not default or "," in default:
        return dart_default_expr(type_name, schema_enums)
    if "::" in default:
        enum_name, enum_value = default.split("::", 1)
        if enum_name in schema_enums and type_name == enum_name:
            return f"{enum_name}.{dart_enum_value_name(enum_value)}"
        return dart_default_expr(type_name, schema_enums)
    if default in ("true", "false"):
        return default
    if not is_cpp_number(default):
        return dart_default_expr(type_name, schema_enums)
    number = sanitize_cpp_number(default)
    if type_name == "double" and "." not in number:
        return f"{number}.0"
    if type_name in ("int", "double"):
        return number
    return dart_default_expr(type_name, schema_enums)

def dart_read_expr(field):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"_read{inner}List(reader)"
    wire = field["wire"]
    if wire == "enum_i32":
        return f"{field['cpp_type']}.fromValue(reader.readInt32())"
    if wire == "u8":
        return "reader.readUint8()"
    if wire == "u16":
        return "reader.readUint16()"
    if wire in ("i32", "size_as_i32", "enum_i32"):
        return "reader.readInt32()"
    if wire in ("u32", "size_as_u32"):
        return "reader.readUint32()"
    if wire in ("i64", "size_as_i64"):
        return "reader.readInt64()"
    if wire in ("u64", "size_as_u64"):
        return "reader.readUint64()"
    if wire == "f32":
        return "reader.readFloat32()"
    if wire == "f64":
        return "reader.readFloat64()"
    if wire == "bool_i32":
        return "reader.readBoolI32()"
    if wire == "bool_u8":
        return "reader.readBoolUint8()"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return "_readUtf8String(reader)"
    if wire == "struct":
        return f"_read{field['cpp_type']}(reader)"
    raise SystemExit(f"Unsupported Dart read wire: {wire}")

def dart_write_stmt(field, value_expr):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"_write{inner}List(writer, {value_expr});"
    wire = field["wire"]
    if wire == "enum_i32":
        return f"writer.writeInt32({value_expr}.value);"
    if wire == "u8":
        return f"writer.writeUint8({value_expr});"
    if wire == "u16":
        return f"writer.writeUint16({value_expr});"
    if wire in ("i32", "size_as_i32", "enum_i32"):
        return f"writer.writeInt32({value_expr});"
    if wire in ("u32", "size_as_u32"):
        return f"writer.writeUint32({value_expr});"
    if wire in ("i64", "size_as_i64"):
        return f"writer.writeInt64({value_expr});"
    if wire in ("u64", "size_as_u64"):
        return f"writer.writeUint64({value_expr});"
    if wire == "f32":
        return f"writer.writeFloat32({value_expr});"
    if wire == "f64":
        return f"writer.writeFloat64({value_expr});"
    if wire == "bool_i32":
        return f"writer.writeBoolI32({value_expr});"
    if wire == "bool_u8":
        return f"writer.writeBoolUint8({value_expr});"
    if wire in ("utf8_string", "u16_string", "u16_as_utf8"):
        return f"_writeUtf8String(writer, {value_expr});"
    if wire == "struct":
        return f"_write{field['cpp_type']}(writer, {value_expr});"
    raise SystemExit(f"Unsupported Dart write wire: {wire}")

def dart_size_expr(field, value_expr):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"_sizeOf{inner}List({value_expr})"
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
        return f"_sizeOfUtf8String({value_expr})"
    if wire == "struct":
        return f"_sizeOf{field['cpp_type']}({value_expr})"
    raise SystemExit(f"Unsupported Dart size wire: {wire}")

def dart_map_value_type(field, schema_types, schema_enums):
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"List<{inner}>"
    return dart_type(field, schema_types, schema_enums)

def dart_pack_param_type(field, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        key_field = entry_item["fields"][0]
        value_field = entry_item["fields"][1]
        key_type = dart_type(key_field, schema_types, schema_enums)
        value_type = dart_map_value_type(value_field, schema_types, schema_enums)
        return f"Map<{key_type}, {value_type}>?"
    inner = vector_inner(field["cpp_type"])
    if inner is not None:
        return f"List<{inner}>?"
    return dart_type(field, schema_types, schema_enums)

def dart_pack_params(item, schema):
    return [
        (dart_pack_param_type(field, schema), payload_param_name(field, "java", schema), field)
        for field in item["fields"]
    ]

def dart_size_value_line(field, value_expr):
    return f"    size += {dart_size_expr(field, value_expr)};"

def dart_write_value_line(field, value_expr):
    return f"    {dart_write_stmt(field, value_expr)}"

def dart_size_map_field_lines(field, param_name, schema):
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    return [
        "    size += 4;",
        f"    if ({param_name} != null) {{",
        f"      final keys = {param_name}.keys.toList()..sort();",
        "      for (final key in keys) {",
        f"        final value = {param_name}[key]!;",
        f"        size += {dart_size_expr(key_field, 'key')};",
        f"        size += {dart_size_expr(value_field, 'value')};",
        "      }",
        "    }",
    ]

def dart_write_map_field_lines(field, param_name, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    key_type = dart_type(key_field, schema_types, schema_enums)
    return [
        f"    final keys = {param_name} == null ? <{key_type}>[] : ({param_name}.keys.toList()..sort());",
        "    writer.writeInt32(keys.length);",
        "    for (final key in keys) {",
        f"      final value = {param_name}![key]!;",
        f"      {dart_write_stmt(key_field, 'key')}",
        f"      {dart_write_stmt(value_field, 'value')}",
        "    }",
    ]

def dart_size_payload_field_lines(field, param_name, schema):
    if map_entry_item(field, schema) is not None:
        return dart_size_map_field_lines(field, param_name, schema)
    return [dart_size_value_line(field, param_name)]

def dart_write_payload_field_lines(field, param_name, schema):
    if map_entry_item(field, schema) is not None:
        return dart_write_map_field_lines(field, param_name, schema)
    return [dart_write_value_line(field, param_name)]

def generate_dart_pack_methods(item, schema):
    pack_name = payload_encode_function_name(item)
    if not is_hidden_input_type(item):
        return [
            "",
            f"  static Uint8List {pack_name}({item['name']} value) {{",
            f"    final writer = _BinaryWriter(_sizeOf{item['name']}(value));",
            f"    _write{item['name']}(writer, value);",
            "    return writer.toBytes();",
            "  }",
        ]
    params = dart_pack_params(item, schema)
    params_sig = ", ".join(f"{type_name} {name}" for type_name, name, _ in params)
    args = ", ".join(name for _, name, _ in params)
    wire_name = upper_first(pack_name[len("encode"):])
    lines = [
        "",
        f"  static void _write{wire_name}Wire(_BinaryWriter writer, {params_sig}) {{",
    ]
    for _, name, field in params:
        lines.extend(dart_write_payload_field_lines(field, name, schema))
    lines.append("  }")
    lines.extend([
        "",
        f"  static int _sizeOf{wire_name}Wire({params_sig}) {{",
        "    var size = 0;",
    ])
    for _, name, field in params:
        lines.extend(dart_size_payload_field_lines(field, name, schema))
    lines.extend([
        "    return size;",
        "  }",
        "",
        f"  static Uint8List {pack_name}({params_sig}) {{",
        f"    final writer = _BinaryWriter(_sizeOf{wire_name}Wire({args}));",
        f"    _write{wire_name}Wire(writer, {args});",
        "    return writer.toBytes();",
        "  }",
    ])
    return lines

def generate_dart_enum(item):
    if item["kind"] == "flags":
        lines = [f"class {item['name']} {{", f"  {item['name']}._();"]
        for value in item["values"]:
            lines.append(f"  static const int {dart_enum_value_name(value['name'])} = {value['value']};")
        lines.append("}")
        return lines
    fallback = dart_enum_value_name(item["fallback"])
    lines = [f"enum {item['name']} {{"]
    for index, value in enumerate(item["values"]):
        suffix = "," if index + 1 < len(item["values"]) else ";"
        lines.append(f"  {dart_enum_value_name(value['name'])}({value['value']}){suffix}")
    lines.extend([
        "",
        f"  const {item['name']}(this.value);",
        "  final int value;",
        "",
        f"  static {item['name']} fromValue(int value) {{",
        "    switch (value) {",
    ])
    for value in item["values"]:
        lines.append(f"      case {value['value']}: return {dart_enum_value_name(value['name'])};")
    lines.extend([
        f"      default: return {fallback};",
        "    }",
        "  }",
        "}",
    ])
    return lines

def generate_dart_class(item, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    lines = [f"class {item['name']} {{"]
    if item["fields"]:
        lines.append(f"  const {item['name']}({{")
        for field in item["fields"]:
            type_name = dart_type(field, schema_types, schema_enums)
            default = dart_default_for_field(field, type_name, schema_enums)
            lines.append(f"    this.{dart_field_name(field)} = {default},")
        lines.append("  });")
        lines.append("")
        for field in item["fields"]:
            lines.append(f"  final {dart_type(field, schema_types, schema_enums)} {dart_field_name(field)};")
    else:
        lines.append(f"  const {item['name']}();")
    lines.append("}")
    return lines

def generate_dart_codec(schema, target=None):
    if dart_uses_ffi_pointer(target):
        lines = [
            "class _BinaryReader {",
            "  _BinaryReader.fromPointer(ffi.Pointer<ffi.Uint8> ptr, int size)",
            "    : _data = ByteData.sublistView(ptr.asTypedList(size));",
            "",
            "  final ByteData _data;",
            "  int _offset = 0;",
        ]
    else:
        lines = [
            "class _BinaryReader {",
            "  _BinaryReader(Uint8List bytes) : _data = ByteData.sublistView(bytes);",
            "",
            "  final ByteData _data;",
            "  int _offset = 0;",
        ]
    lines.extend([
        "",
        "  int readUint8() {",
        "    final value = _data.getUint8(_offset);",
        "    _offset += 1;",
        "    return value;",
        "  }",
        "",
        "  int readUint16() {",
        "    final value = _data.getUint16(_offset, Endian.little);",
        "    _offset += 2;",
        "    return value;",
        "  }",
        "",
        "  int readInt32() {",
        "    final value = _data.getInt32(_offset, Endian.little);",
        "    _offset += 4;",
        "    return value;",
        "  }",
        "",
        "  int readUint32() {",
        "    final value = _data.getUint32(_offset, Endian.little);",
        "    _offset += 4;",
        "    return value;",
        "  }",
        "",
        "  int readInt64() {",
        "    final value = _data.getInt64(_offset, Endian.little);",
        "    _offset += 8;",
        "    return value;",
        "  }",
        "",
        "  int readUint64() {",
        "    final value = _data.getUint64(_offset, Endian.little);",
        "    _offset += 8;",
        "    return value;",
        "  }",
        "",
        "  double readFloat32() {",
        "    final value = _data.getFloat32(_offset, Endian.little);",
        "    _offset += 4;",
        "    return value;",
        "  }",
        "",
        "  double readFloat64() {",
        "    final value = _data.getFloat64(_offset, Endian.little);",
        "    _offset += 8;",
        "    return value;",
        "  }",
        "",
        "  bool readBoolI32() => readInt32() != 0;",
        "  bool readBoolUint8() => readUint8() != 0;",
        "",
        "  Uint8List readBytes(int length) {",
        "    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _offset, length);",
        "    _offset += length;",
        "    return bytes;",
        "  }",
        "}",
        "",
        "class _BinaryWriter {",
        "  _BinaryWriter(int size) : _data = ByteData(size);",
        "",
        "  final ByteData _data;",
        "  int _offset = 0;",
        "",
        "  Uint8List toBytes() => _data.buffer.asUint8List();",
        "",
        "  void writeUint8(int value) {",
        "    _data.setUint8(_offset, value);",
        "    _offset += 1;",
        "  }",
        "",
        "  void writeUint16(int value) {",
        "    _data.setUint16(_offset, value, Endian.little);",
        "    _offset += 2;",
        "  }",
        "",
        "  void writeInt32(int value) {",
        "    _data.setInt32(_offset, value, Endian.little);",
        "    _offset += 4;",
        "  }",
        "",
        "  void writeUint32(int value) {",
        "    _data.setUint32(_offset, value, Endian.little);",
        "    _offset += 4;",
        "  }",
        "",
        "  void writeInt64(int value) {",
        "    _data.setInt64(_offset, value, Endian.little);",
        "    _offset += 8;",
        "  }",
        "",
        "  void writeUint64(int value) {",
        "    _data.setUint64(_offset, value, Endian.little);",
        "    _offset += 8;",
        "  }",
        "",
        "  void writeFloat32(double value) {",
        "    _data.setFloat32(_offset, value, Endian.little);",
        "    _offset += 4;",
        "  }",
        "",
        "  void writeFloat64(double value) {",
        "    _data.setFloat64(_offset, value, Endian.little);",
        "    _offset += 8;",
        "  }",
        "",
        "  void writeBoolI32(bool value) => writeInt32(value ? 1 : 0);",
        "  void writeBoolUint8(bool value) => writeUint8(value ? 1 : 0);",
        "",
        "  void writeBytes(List<int> bytes) {",
        "    _data.buffer.asUint8List().setAll(_offset, bytes);",
        "    _offset += bytes.length;",
        "  }",
        "}",
        "",
        "String _readUtf8String(_BinaryReader reader) {",
        "  final length = reader.readInt32();",
        "  if (length <= 0) return '';",
        "  return utf8.decode(reader.readBytes(length));",
        "}",
        "",
        "void _writeUtf8String(_BinaryWriter writer, String? value) {",
        "  final bytes = value == null ? const <int>[] : utf8.encode(value);",
        "  writer.writeInt32(bytes.length);",
        "  writer.writeBytes(bytes);",
        "}",
        "",
        "int _sizeOfUtf8String(String? value) {",
        "  return 4 + (value == null ? 0 : utf8.encode(value).length);",
        "}",
    ])
    for inner in list_inner_names(schema):
        if inner_needs_reader(schema, inner):
            lines.extend([
                "",
                f"List<{inner}> _read{inner}List(_BinaryReader reader) {{",
                "  final count = reader.readInt32();",
                f"  final values = <{inner}>[];",
                "  for (var i = 0; i < count; i++) {",
                f"    values.add(_read{inner}(reader));",
                "  }",
                "  return values;",
                "}",
            ])
        if inner_needs_writer(schema, inner):
            lines.extend([
                "",
                f"void _write{inner}List(_BinaryWriter writer, List<{inner}>? values) {{",
                "  final count = values == null ? 0 : values.length;",
                "  writer.writeInt32(count);",
                "  for (var i = 0; i < count; i++) {",
                f"    _write{inner}(writer, values![i]);",
                "  }",
                "}",
                "",
                f"int _sizeOf{inner}List(List<{inner}>? values) {{",
                "  var size = 4;",
                "  if (values != null) {",
                "    for (final value in values) {",
                f"      size += _sizeOf{inner}(value);",
                "    }",
                "  }",
                "  return size;",
                "}",
            ])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            lines.extend(["", f"{item['name']} _read{item['name']}(_BinaryReader reader) {{"])
            if not item["fields"]:
                lines.append(f"  return const {item['name']}();")
            else:
                lines.append(f"  return {item['name']}(")
                for field in item["fields"]:
                    lines.append(f"    {dart_field_name(field)}: {dart_read_expr(field)},")
                lines.append("  );")
            lines.append("}")
        if needs_writer(item):
            lines.extend(["", f"void _write{item['name']}(_BinaryWriter writer, {item['name']} value) {{"])
            for field in item["fields"]:
                lines.append(f"  {dart_write_stmt(field, f'value.{dart_field_name(field)}')}")
            lines.append("}")
            lines.extend(["", f"int _sizeOf{item['name']}({item['name']} value) {{"])
            if not item["fields"]:
                lines.append("  return 0;")
            else:
                lines.append("  var size = 0;")
                for field in item["fields"]:
                    lines.append(f"  size += {dart_size_expr(field, f'value.{dart_field_name(field)}')};")
                lines.append("  return size;")
            lines.append("}")
    codec_type = protocol_type_name(target, "core_protocol.dart")
    lines.extend(["", f"class {codec_type} {{", f"  {codec_type}._();"])
    for item in visible_schema_types(schema):
        if needs_reader(item):
            name = upper_first(item["name"])
            if dart_uses_ffi_pointer(target):
                lines.extend([
                    "",
                    f"  static {item['name']} decode{name}FromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {{",
                    "    final reader = _BinaryReader.fromPointer(ptr, size);",
                    f"    return _read{item['name']}(reader);",
                    "  }",
                ])
            else:
                lines.extend([
                    "",
                    f"  static {item['name']} decode{name}(Uint8List data) {{",
                    "    final reader = _BinaryReader(data);",
                    f"    return _read{item['name']}(reader);",
                    "  }",
                ])
        if needs_writer(item) and item["kind"] == "payload":
            name = upper_first(item["name"])
            lines.extend([
                "",
                f"  static Uint8List encode{name}({item['name']} value) {{",
                f"    final writer = _BinaryWriter(_sizeOf{item['name']}(value));",
                f"    _write{item['name']}(writer, value);",
                "    return writer.toBytes();",
                "  }",
            ])
    for item in input_pack_items(schema):
        lines.extend(generate_dart_pack_methods(item, schema))
    lines.append("}")
    return lines

def dart_domain_file(target, domain):
    return domain_value(target, domain, f"{domain}.dart")

def dart_field_dependency_names(field, schema):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        fields = entry_item["fields"]
    else:
        fields = [field]
    names = set()
    for dependency_field in fields:
        type_name = dart_type(dependency_field, schema_types, schema_enums)
        if type_name.startswith("List<") and type_name.endswith(">"):
            names.add(type_name[len("List<"):-1])
        else:
            names.add(type_name)
    return names

def dart_domain_import_files(domain, items, schema, target):
    schema_types = type_map(schema)
    schema_enums = enum_map(schema)
    imports = set()
    for item in items:
        for field in item["fields"]:
            for custom in dart_field_dependency_names(field, schema):
                if custom in schema_types and schema_types[custom]["domain"] != domain:
                    imports.add(dart_domain_file(target, schema_types[custom]["domain"]))
                if custom in schema_enums and schema_enums[custom]["domain"] != domain:
                    imports.add(dart_domain_file(target, schema_enums[custom]["domain"]))
    return sorted(imports)

def generate_dart_domain_file(domain, items, enums, schema, target):
    lines = [
        "// ignore_for_file: unused_element",
        "",
    ]
    part_of = dart_part_of(target)
    if part_of:
        lines.append(f"part of '{part_of}';")
        lines.append("")
    else:
        imports = dart_domain_import_files(domain, items, schema, target)
        for import_file in imports:
            lines.append(f"import '{import_file}';")
        if imports:
            lines.append("")
    for item in enums:
        lines.extend(generate_dart_enum(item))
        lines.append("")
    for item in items:
        lines.extend(generate_dart_class(item, schema))
        lines.append("")
    return "\n".join(lines)

def generate_dart_codec_file(schema, target, import_files):
    lines = [
        "// ignore_for_file: unused_element",
        "",
    ]
    part_of = dart_part_of(target)
    if part_of:
        lines.append(f"part of '{part_of}';")
        lines.append("")
    else:
        lines.append("import 'dart:convert';")
        if dart_uses_ffi_pointer(target):
            lines.append("import 'dart:ffi' as ffi;")
        lines.extend([
            "import 'dart:typed_data';",
            "",
        ])
        for import_file in import_files:
            lines.append(f"import '{import_file}';")
        if import_files:
            lines.append("")
    lines.extend(generate_dart_codec(schema, target))
    lines.append("")
    return "\n".join(lines)

def generate_dart_library_file(target, part_files):
    lines = [
        "// ignore_for_file: unused_element",
        "",
    ]
    for part_file in part_files:
        lines.append(f"export '{part_file}';")
    lines.append("")
    return "\n".join(lines)

def generate_dart_file(schema):
    lines = [
        "// ignore_for_file: unused_element",
        "",
        "import 'dart:convert';",
        "import 'dart:typed_data';",
        "",
    ]
    for item in schema["enums"]:
        lines.extend(generate_dart_enum(item))
        lines.append("")
    for item in visible_schema_types(schema):
        lines.extend(generate_dart_class(item, schema))
        lines.append("")
    lines.extend(generate_dart_codec(schema))
    lines.append("")
    return "\n".join(lines)

def generate_dart(schema, target_name, target, out_root):
    if target.get("layout") == "split_by_domain":
        written = []
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
        part_files = []
        for domain in domains:
            file_name = dart_domain_file(target, domain)
            path = out_root / file_name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(
                generate_dart_domain_file(
                    domain,
                    items_by_domain.get(domain, []),
                    enums_by_domain.get(domain, []),
                    schema,
                    target,
                ),
                encoding="utf-8",
            )
            written.append(str(path))
            part_files.append(file_name)
        codec_file = target.get("codec_file", "core_protocol.dart")
        codec_path = out_root / codec_file
        codec_path.parent.mkdir(parents=True, exist_ok=True)
        codec_path.write_text(generate_dart_codec_file(schema, target, part_files), encoding="utf-8")
        written.append(str(codec_path))
        part_files.append(codec_file)
        if not dart_part_of(target):
            library_file = target.get("library_file", "sweet_editor_protocol.dart")
            if library_file:
                library_path = out_root / library_file
                library_path.parent.mkdir(parents=True, exist_ok=True)
                library_path.write_text(generate_dart_library_file(target, part_files), encoding="utf-8")
                written.append(str(library_path))
        return written
    path = out_root / target.get("file", "sweet_editor_protocol.dart")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(generate_dart_file(schema), encoding="utf-8")
    return [str(path)]
