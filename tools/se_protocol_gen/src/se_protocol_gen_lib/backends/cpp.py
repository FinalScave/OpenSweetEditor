from pathlib import Path

from ..ir import *


def cpp_decodable_types(schema):
    schema_types = type_map(schema)
    names = {
        item["name"]
        for item in schema["types"]
        if item["direction"] in ("in", "both", "value")
    }
    changed = True
    while changed:
        changed = False
        for name in list(names):
            item = schema_types.get(name)
            if item is None:
                continue
            for field in item["fields"]:
                entry_item = map_entry_item(field, schema)
                fields = entry_item["fields"] if entry_item is not None else [field]
                for entry_field in fields:
                    inner = vector_inner(entry_field["cpp_type"])
                    dep = inner or entry_field["cpp_type"]
                    if dep in schema_types and dep not in names:
                        names.add(dep)
                        changed = True
    return [item for item in schema["types"] if item["name"] in names]

def cpp_encodable_types(schema):
    schema_types = type_map(schema)
    names = {
        item["name"]
        for item in schema["types"]
        if item["direction"] in ("in", "out", "both", "value")
    }
    changed = True
    while changed:
        changed = False
        for name in list(names):
            item = schema_types.get(name)
            if item is None:
                continue
            for field in item["fields"]:
                entry_item = map_entry_item(field, schema)
                fields = entry_item["fields"] if entry_item is not None else [field]
                for entry_field in fields:
                    inner = vector_inner(entry_field["cpp_type"])
                    dep = inner or entry_field["cpp_type"]
                    if dep in schema_types and dep not in names:
                        names.add(dep)
                        changed = True
    return [item for item in schema["types"] if item["name"] in names]

def cpp_literal_type(cpp_type):
    return cpp_type

def cpp_reader_call(wire):
    return {
        "u8": ("uint8_t", "readU8"),
        "u16": ("uint16_t", "readU16"),
        "i32": ("int32_t", "readI32"),
        "u32": ("uint32_t", "readU32"),
        "i64": ("int64_t", "readI64"),
        "u64": ("uint64_t", "readU64"),
        "f32": ("float", "readF32"),
        "f64": ("double", "readF64"),
        "size_as_i32": ("int32_t", "readI32"),
        "size_as_u32": ("uint32_t", "readU32"),
        "size_as_i64": ("int64_t", "readI64"),
        "size_as_u64": ("uint64_t", "readU64"),
        "enum_i32": ("int32_t", "readI32"),
        "bool_i32": ("int32_t", "readI32"),
        "bool_u8": ("uint8_t", "readU8"),
    }.get(wire)

def cpp_read_scalar_lines(field, target_expr, indent):
    wire = field["wire"]
    prefix = " " * indent
    if wire in ("utf8_string", "u16_string"):
        return [f"{prefix}if (!readUtf8String({target_expr})) return false;"]
    call = cpp_reader_call(wire)
    if call is None:
        if wire == "struct":
            return [f"{prefix}if (!read({target_expr})) return false;"]
        raise SystemExit(f"Unsupported C++ read wire: {wire}")
    temp_type, reader_name = call
    temp_name = f"{target_expr.replace('.', '_').replace('->', '_')}_value"
    lines = [
        f"{prefix}{temp_type} {temp_name}{{}};",
        f"{prefix}if (!{reader_name}({temp_name})) return false;",
    ]
    if wire in ("bool_i32", "bool_u8"):
        lines.append(f"{prefix}{target_expr} = {temp_name} != 0;")
    elif wire.startswith("size_as_"):
        if wire in ("size_as_i32", "size_as_i64"):
            lines.append(f"{prefix}if ({temp_name} < 0) return false;")
        lines.append(f"{prefix}{target_expr} = static_cast<{cpp_literal_type(field['cpp_type'])}>({temp_name});")
    elif wire == "enum_i32":
        lines.append(f"{prefix}{target_expr} = static_cast<{cpp_literal_type(field['cpp_type'])}>({temp_name});")
    else:
        lines.append(f"{prefix}{target_expr} = static_cast<{cpp_literal_type(field['cpp_type'])}>({temp_name});")
    return lines

def cpp_read_value_lines(field, target_expr, schema, indent):
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        return cpp_read_map_lines(field, target_expr, entry_item, schema, indent)
    inner = vector_inner(field["cpp_type"])
    prefix = " " * indent
    if inner is not None:
        return [f"{prefix}if (!readList({target_expr})) return false;"]
    return cpp_read_scalar_lines(field, target_expr, indent)

def cpp_read_map_lines(field, target_expr, entry_item, schema, indent):
    prefix = " " * indent
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    lines = [
        f"{prefix}uint32_t count{{}};",
        f"{prefix}if (!readU32(count)) return false;",
        f"{prefix}if (count > remaining()) return false;",
        f"{prefix}{target_expr}.clear();",
        f"{prefix}{target_expr}.reserve(count);",
        f"{prefix}for (uint32_t index = 0; index < count; ++index) {{",
        f"{prefix}  {cpp_literal_type(key_field['cpp_type'])} key{{}};",
        f"{prefix}  {cpp_literal_type(value_field['cpp_type'])} value{{}};",
    ]
    lines.extend(cpp_read_value_lines(key_field, "key", schema, indent + 2))
    lines.extend(cpp_read_value_lines(value_field, "value", schema, indent + 2))
    lines.extend([
        f"{prefix}  {target_expr}.emplace_back(std::move(key), std::move(value));",
        f"{prefix}}}",
    ])
    return lines

def cpp_write_scalar_lines(field, value_expr, indent):
    wire = field["wire"]
    prefix = " " * indent
    cpp_type = cpp_literal_type(field["cpp_type"])
    if wire == "utf8_string":
        return [f"{prefix}if (!writeUtf8String({value_expr})) return false;"]
    if wire in ("u16_string", "u16_as_utf8"):
        return [f"{prefix}if (!writeU16AsUtf8String({value_expr})) return false;"]
    if wire == "struct":
        return [f"{prefix}if (!write({value_expr})) return false;"]
    if wire == "u8":
        return [f"{prefix}if (!writeU8(static_cast<uint8_t>({value_expr}))) return false;"]
    if wire == "u16":
        return [f"{prefix}if (!writeU16(static_cast<uint16_t>({value_expr}))) return false;"]
    if wire in ("i32", "enum_i32"):
        return [f"{prefix}if (!writeI32(static_cast<int32_t>({value_expr}))) return false;"]
    if wire == "u32":
        return [f"{prefix}if (!writeU32(static_cast<uint32_t>({value_expr}))) return false;"]
    if wire == "i64":
        return [f"{prefix}if (!writeI64(static_cast<int64_t>({value_expr}))) return false;"]
    if wire == "u64":
        return [f"{prefix}if (!writeU64(static_cast<uint64_t>({value_expr}))) return false;"]
    if wire == "f32":
        return [f"{prefix}if (!writeF32(static_cast<float>({value_expr}))) return false;"]
    if wire == "f64":
        return [f"{prefix}if (!writeF64(static_cast<double>({value_expr}))) return false;"]
    if wire == "size_as_i32":
        return [f"{prefix}if (!writeI32(static_cast<int32_t>({value_expr}))) return false;"]
    if wire == "size_as_u32":
        return [f"{prefix}if (!writeU32(static_cast<uint32_t>({value_expr}))) return false;"]
    if wire == "size_as_i64":
        return [f"{prefix}if (!writeI64(static_cast<int64_t>({value_expr}))) return false;"]
    if wire == "size_as_u64":
        return [f"{prefix}if (!writeU64(static_cast<uint64_t>({value_expr}))) return false;"]
    if wire == "bool_i32":
        return [f"{prefix}if (!writeI32({value_expr} ? 1 : 0)) return false;"]
    if wire == "bool_u8":
        return [f"{prefix}if (!writeU8(static_cast<uint8_t>({value_expr} ? 1 : 0))) return false;"]
    raise SystemExit(f"Unsupported C++ write wire: {wire} ({cpp_type})")

def cpp_write_value_lines(field, value_expr, schema, indent):
    entry_item = map_entry_item(field, schema)
    if entry_item is not None:
        return cpp_write_map_lines(field, value_expr, entry_item, schema, indent)
    inner = vector_inner(field["cpp_type"])
    prefix = " " * indent
    if inner is not None:
        return [f"{prefix}if (!writeList({value_expr})) return false;"]
    return cpp_write_scalar_lines(field, value_expr, indent)

def cpp_write_map_lines(field, value_expr, entry_item, schema, indent):
    prefix = " " * indent
    key_field = entry_item["fields"][0]
    value_field = entry_item["fields"][1]
    lines = [
        f"{prefix}if ({value_expr}.size() > std::numeric_limits<uint32_t>::max()) return false;",
        f"{prefix}if (!writeU32(static_cast<uint32_t>({value_expr}.size()))) return false;",
        f"{prefix}for (const auto& entry : {value_expr}) {{",
        f"{prefix}  const auto& key = entry.first;",
        f"{prefix}  const auto& value = entry.second;",
    ]
    lines.extend(cpp_write_value_lines(key_field, "key", schema, indent + 2))
    lines.extend(cpp_write_value_lines(value_field, "value", schema, indent + 2))
    lines.append(f"{prefix}}}")
    return lines

def cpp_list_inner_names(items, schema):
    result = set()
    for item in items:
        for field in item["fields"]:
            if map_entry_item(field, schema) is not None:
                continue
            inner = vector_inner(field["cpp_type"])
            if inner is not None:
                result.add(inner)
    return sorted(result)

def generate_cpp_codec(schema):
    decodable_items = cpp_decodable_types(schema)
    encodable_items = cpp_encodable_types(schema)
    lines = [
        "#ifndef SWEETEDITOR_PROTOCOL_CODEC_H",
        "#define SWEETEDITOR_PROTOCOL_CODEC_H",
        "",
        "#include <cstddef>",
        "#include <cstdint>",
        "#include <cstring>",
        "#include <limits>",
        "#include <utility>",
        "#include <sweeteditor/protocol.h>",
        "",
        "namespace NS_SWEETEDITOR {",
        "namespace protocol {",
        "",
        "class ProtocolReader final {",
        "public:",
        "  inline ProtocolReader(const uint8_t* data, size_t size)",
        "    : cur_(data), end_(data + size) {",
        "  }",
        "",
        "  inline bool readU8(uint8_t& out) {",
        "    if (!has(1)) return false;",
        "    out = *cur_;",
        "    cur_ += 1;",
        "    return true;",
        "  }",
        "",
        "  inline bool readU16(uint16_t& out) {",
        "    if (!has(2)) return false;",
        "    out = static_cast<uint16_t>(cur_[0]) | static_cast<uint16_t>(cur_[1] << 8u);",
        "    cur_ += 2;",
        "    return true;",
        "  }",
        "",
        "  inline bool readU32(uint32_t& out) {",
        "    if (!has(4)) return false;",
        "    out = static_cast<uint32_t>(cur_[0]) |",
        "      (static_cast<uint32_t>(cur_[1]) << 8u) |",
        "      (static_cast<uint32_t>(cur_[2]) << 16u) |",
        "      (static_cast<uint32_t>(cur_[3]) << 24u);",
        "    cur_ += 4;",
        "    return true;",
        "  }",
        "",
        "  inline bool readI32(int32_t& out) {",
        "    uint32_t raw = 0;",
        "    if (!readU32(raw)) return false;",
        "    out = static_cast<int32_t>(raw);",
        "    return true;",
        "  }",
        "",
        "  inline bool readU64(uint64_t& out) {",
        "    uint32_t low = 0;",
        "    uint32_t high = 0;",
        "    if (!readU32(low) || !readU32(high)) return false;",
        "    out = static_cast<uint64_t>(low) | (static_cast<uint64_t>(high) << 32u);",
        "    return true;",
        "  }",
        "",
        "  inline bool readI64(int64_t& out) {",
        "    uint64_t raw = 0;",
        "    if (!readU64(raw)) return false;",
        "    out = static_cast<int64_t>(raw);",
        "    return true;",
        "  }",
        "",
        "  inline bool readF32(float& out) {",
        "    uint32_t raw = 0;",
        "    if (!readU32(raw)) return false;",
        "    std::memcpy(&out, &raw, sizeof(out));",
        "    return true;",
        "  }",
        "",
        "  inline bool readF64(double& out) {",
        "    uint64_t raw = 0;",
        "    if (!readU64(raw)) return false;",
        "    std::memcpy(&out, &raw, sizeof(out));",
        "    return true;",
        "  }",
        "",
        "  inline bool readBytes(const uint8_t*& out, size_t count) {",
        "    if (!has(count)) return false;",
        "    out = cur_;",
        "    cur_ += count;",
        "    return true;",
        "  }",
        "",
        "  inline bool readUtf8String(U8String& out) {",
        "    uint32_t length = 0;",
        "    if (!readU32(length)) return false;",
        "    const uint8_t* bytes = nullptr;",
        "    if (!readBytes(bytes, static_cast<size_t>(length))) return false;",
        "    out.assign(reinterpret_cast<const char*>(bytes), static_cast<size_t>(length));",
        "    return true;",
        "  }",
        "",
        "  inline bool done() const {",
        "    return cur_ == end_;",
        "  }",
        "",
        "  inline size_t remaining() const {",
        "    return static_cast<size_t>(end_ - cur_);",
        "  }",
        "",
    ]
    for item in decodable_items:
        lines.append(f"  inline bool read({item['name']}& out) {{")
        for field in item["fields"]:
            lines.extend(cpp_read_value_lines(field, f"out.{field['name']}", schema, 4))
        lines.extend([
            "    return true;",
            "  }",
            "",
        ])
    lines.extend([
        "  template <typename T>",
        "  bool readList(Vector<T>& out) {",
        "    uint32_t count = 0;",
        "    if (!readU32(count)) return false;",
        "    if (count > remaining()) return false;",
        "    out.clear();",
        "    out.reserve(count);",
        "    for (uint32_t index = 0; index < count; ++index) {",
        "      T value{};",
        "      if (!read(value)) return false;",
        "      out.push_back(std::move(value));",
        "    }",
        "    return true;",
        "  }",
        "",
        "  template <typename T>",
        "  static bool decode(const uint8_t* data, size_t size, T& out) {",
        "    if (data == nullptr) return false;",
        "    ProtocolReader reader(data, size);",
        "    return reader.read(out) && reader.done();",
        "  }",
        "",
        "private:",
        "  inline bool has(size_t count) const {",
        "    return count <= remaining();",
        "  }",
        "",
        "  const uint8_t* cur_;",
        "  const uint8_t* end_;",
        "};",
        "",
    ])
    lines.extend([
        "class ProtocolWriter final {",
        "public:",
        "  inline ProtocolWriter() = default;",
        "",
        "  inline void reserve(size_t size) {",
        "    buffer_.reserve(size);",
        "  }",
        "",
        "  inline const uint8_t* data() const {",
        "    return buffer_.data();",
        "  }",
        "",
        "  inline size_t size() const {",
        "    return buffer_.size();",
        "  }",
        "",
        "  inline bool writeU8(uint8_t value) {",
        "    buffer_.push_back(value);",
        "    return true;",
        "  }",
        "",
        "  inline bool writeU16(uint16_t value) {",
        "    buffer_.push_back(static_cast<uint8_t>(value & 0xffu));",
        "    buffer_.push_back(static_cast<uint8_t>((value >> 8u) & 0xffu));",
        "    return true;",
        "  }",
        "",
        "  inline bool writeU32(uint32_t value) {",
        "    buffer_.push_back(static_cast<uint8_t>(value & 0xffu));",
        "    buffer_.push_back(static_cast<uint8_t>((value >> 8u) & 0xffu));",
        "    buffer_.push_back(static_cast<uint8_t>((value >> 16u) & 0xffu));",
        "    buffer_.push_back(static_cast<uint8_t>((value >> 24u) & 0xffu));",
        "    return true;",
        "  }",
        "",
        "  inline bool writeI32(int32_t value) {",
        "    return writeU32(static_cast<uint32_t>(value));",
        "  }",
        "",
        "  inline bool writeU64(uint64_t value) {",
        "    return writeU32(static_cast<uint32_t>(value & 0xffffffffu)) &&",
        "      writeU32(static_cast<uint32_t>((value >> 32u) & 0xffffffffu));",
        "  }",
        "",
        "  inline bool writeI64(int64_t value) {",
        "    return writeU64(static_cast<uint64_t>(value));",
        "  }",
        "",
        "  inline bool writeF32(float value) {",
        "    uint32_t raw = 0;",
        "    std::memcpy(&raw, &value, sizeof(value));",
        "    return writeU32(raw);",
        "  }",
        "",
        "  inline bool writeF64(double value) {",
        "    uint64_t raw = 0;",
        "    std::memcpy(&raw, &value, sizeof(value));",
        "    return writeU64(raw);",
        "  }",
        "",
        "  inline bool writeBytes(const uint8_t* data, size_t size) {",
        "    if (size == 0) return true;",
        "    if (data == nullptr) return false;",
        "    buffer_.insert(buffer_.end(), data, data + size);",
        "    return true;",
        "  }",
        "",
        "  inline bool writeUtf8String(const U8String& value) {",
        "    if (value.size() > std::numeric_limits<uint32_t>::max()) return false;",
        "    if (!writeU32(static_cast<uint32_t>(value.size()))) return false;",
        "    return writeBytes(reinterpret_cast<const uint8_t*>(value.data()), value.size());",
        "  }",
        "",
        "  inline bool writeU16AsUtf8String(const U16String& value) {",
        "    U8String utf8;",
        "    if (!value.empty()) {",
        "      StrUtil::convertUTF16ToUTF8(value, utf8);",
        "    }",
        "    return writeUtf8String(utf8);",
        "  }",
        "",
    ])
    for item in encodable_items:
        lines.append(f"  inline bool write(const {item['name']}& value) {{")
        for field in item["fields"]:
            lines.extend(cpp_write_value_lines(field, f"value.{field['name']}", schema, 4))
        lines.extend([
            "    return true;",
            "  }",
            "",
        ])
    lines.extend([
        "  template <typename T>",
        "  bool writeList(const Vector<T>& values) {",
        "    if (values.size() > std::numeric_limits<uint32_t>::max()) return false;",
        "    if (!writeU32(static_cast<uint32_t>(values.size()))) return false;",
        "    for (const auto& value : values) {",
        "      if (!write(value)) return false;",
        "    }",
        "    return true;",
        "  }",
        "",
        "  template <typename T>",
        "  static Vector<uint8_t> encode(const T& value, size_t reserve_size = 0) {",
        "    ProtocolWriter writer;",
        "    writer.reserve(reserve_size);",
        "    if (!writer.write(value)) return {};",
        "    return std::move(writer.buffer_);",
        "  }",
        "",
        "private:",
        "  Vector<uint8_t> buffer_;",
        "};",
        "",
    ])
    lines.extend([
        "} // namespace protocol",
        "} // namespace NS_SWEETEDITOR",
        "",
        "#endif // SWEETEDITOR_PROTOCOL_CODEC_H",
        "",
    ])
    return "\n".join(lines)

def generate_cpp(schema, target_name, target, out_root):
    header_path = out_root / target.get("header_file", "include/sweeteditor/protocol_codec.h")
    header_path.parent.mkdir(parents=True, exist_ok=True)
    header_path.write_text(generate_cpp_codec(schema), encoding="utf-8")
    return [str(header_path)]
