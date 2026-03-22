# SweetEditor 架构设计文档

## 目录

- [设计理念](#设计理念)
- [总体架构](#总体架构)
- [核心模块详解](#核心模块详解)
  - [Document — 文档模型](#document--文档模型)
  - [TextLayout — 布局引擎](#textlayout--布局引擎)
  - [DecorationManager — 装饰系统](#decorationmanager--装饰系统)
  - [EditorCore — 编辑器协调器](#editorcore--编辑器协调器)
  - [GestureHandler — 手势识别](#gesturehandler--手势识别)
  - [UndoManager — 撤销/重做](#undomanager--撤销重做)
  - [Buffer — 数据源抽象](#buffer--数据源抽象)
- [渲染管线](#渲染管线)
- [跨平台桥接策略](#跨平台桥接策略)
- [数据流](#数据流)
- [内存管理](#内存管理)
- [性能优化策略](#性能优化策略)

---

## 设计理念

SweetEditor 的核心设计理念是 **"计算与渲染的彻底分离"**：

1. **C++ 核心不做任何渲染** — 不依赖任何图形库（OpenGL / Skia / Metal 等），也不持有任何平台 UI 对象
2. **C++ 核心不做字体测量** — 通过 `TextMeasurer` 接口将测量权反转给平台
3. **C++ 核心输出结构化渲染模型** — 内部统一组装 `EditorRenderModel`；Android / C API / bridge 路径都围绕这份模型对外
4. **平台层尽量薄** — 主要负责事件转发、字体测量、二进制协议解码和按模型绘制，不承载跨平台编辑语义

这种设计带来的核心优势：

- **行为一致性**：文本编辑、光标移动、选区计算等所有逻辑只有一份实现
- **可测试性**：核心逻辑可以脱离 UI 进行单元测试
- **平台适配成本可控**：新增平台的最小闭环是 `TextMeasurer` + 输入转发 + payload 解码 + 绘制；复杂度主要留在核心，不留在平台语义层
- **渲染质量最优**：每个平台使用自己最擅长的文字渲染技术

---

## 总体架构

```
┌────────────────────────────────────────────────────────────────────┐
│                      平台层 (Input + Render)                      │
│                                                                    │
│ Android        iOS/macOS         Swing/WinForms        Web/OHOS    │
│ Canvas        CoreText/CG          Java2D / GDI+       (预留目录)   │
└───────────────┬───────────────────────────────┬────────────────────┘
                │                               │
                │ JNI 直连 C++                  │ C ABI / Binary Payload
                ▼                               ▼
      ┌─────────────────────┐         ┌──────────────────────────┐
      │ Android Bridge      │         │ C API Bridge             │
      │ (jni_entry+jeditor) │         │ extern \"C\" + intptr_t   │
      └───────────┬─────────┘         └────────────┬─────────────┘
                  └──────────────────────┬──────────┘
                                         ▼
      ┌──────────────────────────────────────────────────────────┐
      │                    SweetEditor Core (C++17)             │
      │                                                          │
      │  Document · TextLayout · DecorationManager · EditorCore │
      │  GestureHandler · UndoManager · LinkedEditing           │
      └──────────────────────────────────────────────────────────┘
```

当前接入状态（代码现状）：

- Android：已接入（JNI 直连）
- Swing / WinForms：已接入（C API）
- Apple：已接入（Swift Package + 手工 bridge）
- Web(Emscripten)：目录存在，绑定文件当前为空
- OHOS：目录存在，当前仅占位

---

## 核心模块详解

### Document — 文档模型

**文件**：`src/include/document.h` · `src/core/document.cpp`

Document 是文本内容的抽象层，定义了统一的文本操作接口。

当前字符串模型有一个容易误判的点：

- **存储层**：`Document` 及编辑入口以 UTF-8 为主
- **布局/测量层**：`LogicalLine.cached_text`、`TextLayout` 测量缓存、`VisualRun.text` 使用 UTF-16
- **平台协议层**：C API 的复杂结构走二进制 payload；其中渲染模型文本字段当前序列化为 UTF-8，`get_document_line_text()` 则单独返回 UTF-16 指针

因此核心不是“全 UTF-8”或“全 UTF-16”，而是“UTF-8 存储 + UTF-16 布局/测量 + binary payload 传输”的混合模型。

#### 抽象接口

```cpp
class Document {
  virtual U8String getU8Text() = 0;               // 获取全文（UTF-8）
  virtual U16String getU16Text() = 0;              // 获取全文（UTF-16）
  virtual size_t getLineCount() const = 0;         // 总行数
  virtual U16String getLineU16Text(size_t line) = 0; // 指定行文本
  virtual void insertU8Text(const TextPosition& pos, const U8String& text) = 0;
  virtual void deleteU8Text(const TextRange& range) = 0;
  virtual void replaceU8Text(const TextRange& range, const U8String& text) = 0;
  virtual Vector<LogicalLine>& getLogicalLines() = 0;
  // ...
};
```

#### 两种实现

| 实现 | 适用场景 | 内部结构 |
|------|---------|---------|
| `LineArrayDocument` | 中小文件、频繁按行操作 | `Vector<U8String>` 按行存储 |
| `PieceTableDocument` | 大文件、频繁编辑 | Piece Table（原始 Buffer + 编辑 Buffer + Segment 列表） |

#### LogicalLine — 逻辑行

每个逻辑行维护以下数据：

```cpp
struct LogicalLine {
  size_t start_byte;            // 在全文中的字节偏移
  size_t start_char;            // 在全文中的字符偏移
  U16String cached_text;        // 行文本缓存（UTF-16）
  bool is_char_dirty;           // 字符数据是否需要刷新
  LineEnding line_ending;       // 换行符类型（LF/CR/CRLF）
  float start_y;                // 行起始 Y 坐标
  float height;                 // 行渲染高度（含换行折叠）
  Vector<VisualLine> visual_lines; // 视觉行布局数据
  bool is_layout_dirty;         // 布局是否需要重建
  bool is_fold_hidden;          // 是否被折叠隐藏
};
```

关键设计：**双 dirty 标记机制** — `is_char_dirty` 标记文本数据需要刷新，`is_layout_dirty` 标记布局需要重建。编辑操作只标记 dirty，实际计算延迟到 `buildRenderModel()` 时按需执行。

---

### TextLayout — 布局引擎

**文件**：`src/include/layout.h` · `src/core/layout.cpp`

布局引擎是整个编辑器中最核心的模块，负责将逻辑行文本转化为可渲染的视觉行。

#### 核心职责

1. **行文本布局** — 将一行文本 + 高亮 spans + inlay hints + phantom texts 做"拉链对齐"（zipper merge），生成 `VisualRun` 序列
2. **自动换行** — 根据 `WrapMode` 将超长行拆分为多个视觉行
3. **视口裁剪** — 只布局和输出可见区域的行，跳过视口外的行
4. **HitTest** — 屏幕坐标 → 文本位置的精确映射
5. **宽度测量** — 通过 `TextMeasurer` 接口调用平台字体测量，结果缓存

#### 布局流程

```
layoutVisibleLines()                    ← 布局入口
    │
    ▼
resolveVisibleLines()                   ← 边布局边计算可见行范围
    │  遍历所有逻辑行，对每行调用 layoutLine()：
    │    · 若该行 is_layout_dirty，触发重新布局
    │    · 累加行高，定位第一/最后可见行
    │    · 一旦超出视口底部立即返回，跳过后续行
    │
    │  layoutLine() 内部对 dirty 行执行：
    │    ├→ buildLineRuns()             ← 拉链合并：文本 + spans + inlay hints + phantom texts
    │    │                                 生成 VisualRun 序列（TEXT / INLAY_HINT / PHANTOM_TEXT）
    │    ├→ layoutLineIntoVisualLines() ← 将 runs 按 WrapMode 拆分为多个 VisualLine
    │    │    ├→ wrapLineRuns()            NONE: 不拆分 / CHAR_BREAK / WORD_BREAK
    │    │    └→ 处理 phantom text 跨行续行
    │    └→ 追加折叠占位符 run（若为折叠首行）
    │
    ▼
遍历 [first_line, last_line] 可见行
    │  对每个 VisualLine：
    │    · 绝对坐标 → 屏幕坐标转换
    │    · cropVisualLineRuns()          ← 水平视口裁剪（非换行模式下移除不可见的 run）
    │    · 填充行号图标、折叠状态
    │
    ▼
Vector<VisualLine>  → 输出到 EditorRenderModel
```

#### 换行模式

```cpp
enum struct WrapMode {
  NONE,        // 不换行（水平滚动）
  CHAR_BREAK,  // 字符级换行
  WORD_BREAK,  // 单词级换行（按空格/标点断行）
};
```

#### TextMeasurer — 文字测量接口

```cpp
class TextMeasurer {
  virtual float measureWidth(const U16String& text, int32_t font_style) = 0;
  virtual float measureInlayHintWidth(const U16String& text) = 0;
  virtual float measureIconWidth(int32_t icon_id) = 0;
  virtual FontMetrics getFontMetrics() = 0;
};
```

由各平台实现。C API 通过回调结构体 `text_measurer_t` 传入：

```c
typedef struct {
  float (*measure_text_width)(const U16Char* text, int32_t font_style);
  float (*measure_inlay_hint_width)(const U16Char* text);
  float (*measure_icon_width)(int32_t icon_id);
  void  (*get_font_metrics)(float* arr, size_t length);
} text_measurer_t;
```

#### 等宽 vs 非等宽字体

布局引擎内部通过 `m_is_monospace_` 标志区分：
- **等宽字体**：可使用 `字符数 × 字符宽度` 快速计算，避免逐字测量
- **非等宽字体**：必须调用 `TextMeasurer` 逐段测量，结果缓存在 `m_text_widths_` HashMap 中

---

### DecorationManager — 装饰系统

**文件**：`src/include/decoration.h` · `src/core/decoration.cpp`

统一管理所有非文本内容的视觉元素。

#### 管理的数据类型

| 数据类型 | 结构体 | 存储方式 | 影响布局 |
|---------|--------|---------|---------|
| 语法高亮 | `StyleSpan` {column, length, style_id} | 按行存储 `Vector<Vector<StyleSpan>>` | ✅（字体样式影响宽度） |
| Inlay Hint | `InlayHint` {type, column, text, icon_id} | 按行存储 `Vector<Vector<InlayHint>>` | ✅（插入额外宽度） |
| 幽灵文本 | `PhantomText` {column, text} | 按行存储 `Vector<Vector<PhantomText>>` | ✅（可能跨行展开） |
| 行号图标 | `GutterIcon` {icon_id} | `HashMap<line, Vector<GutterIcon>>` | ❌ |
| 折叠区域 | `FoldRegion` {start_line, end_line, collapsed} | `Vector<FoldRegion>` | ✅（隐藏行） |
| 缩进线 | `IndentGuide` {start, end} | `Vector<IndentGuide>` | ❌ |
| 括号配对线 | `BracketGuide` {parent, end, children} | `Vector<BracketGuide>` | ❌ |
| 控制流箭头 | `FlowGuide` {start, end} | `Vector<FlowGuide>` | ❌ |
| 分割线 | `SeparatorGuide` {line, style, count} | `Vector<SeparatorGuide>` | ❌ |

补充说明：

- `InlayHint.text` / `PhantomText.text` 当前在 `DecorationManager` 中仍以 UTF-8 存储。
- `TextLayout::buildLineRuns()` 在生成 `VisualRun` 时会把需要绘制/测量的装饰文本转换为 UTF-16。
- 因此装饰管理器保存的是“编辑语义数据”，不是平台可直接消费的绘制对象。

#### StyleRegistry — 样式注册表

```cpp
class StyleRegistry {
  void registerStyle(Style&& style);       // 注册：style_id → {color, font_style}
  Style& getStyle(uint32_t style_id);      // 查询
};
```

平台侧先注册样式（ID → 颜色 + 字体样式），再通过 `setLineSpans` 为每行设置样式区间。这种设计解耦了"样式定义"和"样式应用"，便于主题切换。

#### 编辑后自动调整

```cpp
void adjustForEdit(const TextRange& old_range, const TextPosition& new_end);
```

当文本发生编辑时，所有 decoration 的行列偏移需要同步调整。`adjustForEdit` 统一处理这个逻辑，确保编辑后高亮、inlay hints 等不会错位。

---

### EditorCore — 编辑器协调器

**文件**：`src/include/editor_core.h` · `src/core/editor_core.cpp`

EditorCore 是最顶层的类，组合所有子模块并提供完整的编辑器 API。

#### 内部组件

```cpp
class EditorCore {
  Ptr<TextMeasurer>       m_measurer_;         // 文字测量（平台实现）
  Ptr<Document>           m_document_;         // 文档模型
  Ptr<DecorationManager>  m_decorations_;      // 装饰管理器
  UPtr<GestureHandler>    m_gesture_handler_;  // 手势识别
  UPtr<TextLayout>        m_text_layout_;      // 布局引擎
  UPtr<UndoManager>       m_undo_manager_;     // 撤销/重做
  // 光标、选区、IME 状态...
};
```

#### 核心方法分组

| 方法组 | 说明 |
|--------|------|
| `loadDocument()` | 加载文档 |
| `handleGestureEvent()` | 处理触摸/鼠标事件 → 返回 GestureResult |
| `handleKeyEvent()` | 处理键盘事件 → 返回 KeyEventResult |
| `insertText()` / `backspace()` / `deleteForward()` | 原子文本操作 |
| `moveCursor*()` | 光标移动（上下左右、行首行尾） |
| `setSelection()` / `selectAll()` | 选区管理 |
| `compositionStart/Update/End/Cancel()` | IME 组合输入 |
| `undo()` / `redo()` | 撤销/重做 |
| `registerStyle()` / `setLineSpans()` / `setBatchLineSpans()` / `setLineInlayHints()` / `setLinePhantomTexts()` | 装饰设置 |
| `setFoldRegions()` / `foldAt()` / `unfoldAt()` | 代码折叠 |
| `add*Guide()` | 代码结构线 |
| `buildRenderModel()` | **核心输出**：生成一帧渲染模型 |

#### 统一编辑入口

所有文本修改操作最终都通过 `applyEdit()` 执行：

```cpp
TextEditResult applyEdit(const TextRange& range, const U8String& new_text, bool record_undo = true);
```

这个方法：
1. 记录旧文本（用于 undo）
2. 执行文档编辑（`Document::replaceU8Text`）
3. 调整所有 decoration 偏移（`DecorationManager::adjustForEdit`）
4. 自动展开被编辑区域的折叠（`autoUnfoldForEdit`）
5. 标记受影响行的布局为 dirty
6. 推入 undo 栈
7. 返回精确变更信息（`TextEditResult`）

---

### GestureHandler — 手势识别

**文件**：`src/include/gesture.h` · `src/core/gesture.cpp`

统一处理触摸和鼠标两种输入模式的手势识别引擎。

#### 事件类型

```
触摸系列：TOUCH_DOWN → TOUCH_MOVE → TOUCH_UP（含多指 POINTER_DOWN/UP）
鼠标系列：MOUSE_DOWN → MOUSE_MOVE → MOUSE_UP + MOUSE_WHEEL + MOUSE_RIGHT_DOWN
直通系列：DIRECT_SCALE（触控板缩放）、DIRECT_SCROLL（触控板滚动）
```

#### 识别的手势

| 手势 | 触发条件 |
|------|---------|
| `TAP` | 按下→松开，移动距离 < touch_slop |
| `DOUBLE_TAP` | 两次 TAP 间隔 < double_tap_timeout |
| `LONG_PRESS` | 按下后保持 > long_press_ms |
| `SCALE` | 双指捏合 或 DIRECT_SCALE |
| `SCROLL` | 单指移动距离 > touch_slop 或 MOUSE_WHEEL / DIRECT_SCROLL |
| `FAST_SCROLL` | 快速 fling 惯性滚动 |
| `DRAG_SELECT` | 鼠标按住拖动 或 长按后拖动 |
| `CONTEXT_MENU` | 鼠标右键 或 长按 |

#### 修饰键

```cpp
enum struct Modifier : uint8_t {
  NONE  = 0,
  SHIFT = 1 << 0,  // Shift+Click = 扩展选区
  CTRL  = 1 << 1,  // Ctrl+Click = 多光标（未来）
  ALT   = 1 << 2,
  META  = 1 << 3,  // Cmd (macOS)
};
```

---

### UndoManager — 撤销/重做

**文件**：`src/include/undo.h`

基于双栈（undo stack + redo stack）的撤销/重做实现。

#### 操作合并

连续的单字符输入或删除会自动合并为一个操作（合并窗口：500ms）：

```
用户输入 "hello" → 不是 5 次 undo，而是 1 次 undo 恢复整个 "hello"
```

合并规则：
- 相邻的单字符插入（位置连续，间隔 < 500ms）
- 相邻的 Backspace 删除（位置连续）
- 相邻的 Delete Forward 删除（位置连续）
- 换行符不参与合并（回车总是独立一步）
- 有选区的操作不参与合并

#### 栈深度限制

默认最大 512 步，超出时丢弃最早的操作。

---

### Buffer — 数据源抽象

**文件**：`src/include/buffer.h` · `src/core/buffer.cpp`

| 实现 | 用途 |
|------|------|
| `U8StringBuffer` | 可读写的内存字符串 Buffer |
| `MappedFileBuffer` | 文件内存映射（mmap / CreateFileMapping），只读，零拷贝打开大文件 |

---

## 渲染管线

### EditorRenderModel — 渲染模型

`buildRenderModel()` 每帧调用一次，先在核心内组装完整渲染指令；C API 层再把它编码为二进制 payload：

```cpp
struct EditorRenderModel {
  float split_x;                        // 行号分割线 X 位置
  float scroll_x, scroll_y;             // 当前滚动偏移
  float viewport_width, viewport_height; // 视口尺寸
  PointF current_line;                  // 当前行背景位置
  Vector<VisualLine> lines;             // 可见视觉行
  Cursor cursor;                        // 光标
  Vector<SelectionRect> selection_rects; // 选区高亮
  SelectionHandle selection_start_handle; // 选区起始拖拽手柄
  SelectionHandle selection_end_handle;  // 选区结束拖拽手柄
  CompositionDecoration composition_decoration; // IME 下划线
  Vector<GuideSegment> guide_segments;   // 代码结构线
  Vector<DiagnosticDecoration> diagnostic_decorations; // 诊断装饰
  uint32_t max_gutter_icons;            // Gutter 图标数
  Vector<LinkedEditingRect> linked_editing_rects; // 联动编辑高亮
  Vector<BracketHighlightRect> bracket_highlight_rects; // 括号高亮
};
```

当前 C API 约定：

- `build_editor_render_model()`：返回本机字节序二进制 payload（当前支持平台均为 little-endian）
- `get_layout_metrics()`：返回 `LayoutMetrics` 二进制 payload，供平台查询布局参数

### VisualLine 与 VisualRun

每个可见的视觉行包含多个渲染片段：

```
VisualLine
├── VisualRun (TEXT)           — 普通代码文本，带样式
├── VisualRun (WHITESPACE)     — 空格（可选可视化）
├── VisualRun (INLAY_HINT)     — Inlay Hint（文本或图标）
├── VisualRun (PHANTOM_TEXT)   — 幽灵文本
├── VisualRun (FOLD_PLACEHOLDER) — 折叠占位符 "…"
└── VisualRun (NEWLINE)        — 换行符
```

每个 VisualRun 包含精确的绘制坐标 `(x, y)`、宽度 `width`、文本内容 `text`、样式 `style`（颜色 + 字体样式）。

这里需要区分“核心内部表示”和“跨语言传输格式”：

- 核心内部 `VisualRun.text` 是 `U16String`
- `build_editor_render_model()` 在 C API 路径里会把 `VisualRun.text` 转成长度前缀 UTF-8 字节串
- Swing / WinForms / Apple / Android 的桥接层再把这段 UTF-8 解码成各自语言的 `String`

### 平台侧绘制顺序

```
1. 填充背景色
2. 绘制当前行高亮背景（current_line）
3. 绘制选区高亮矩形（selection_rects）
4. 绘制代码结构线（guide_segments）
5. 绘制行号分割线（split_x）
6. 遍历 lines：
   a. 绘制行号（line_number_position）
   b. 绘制 gutter 图标（gutter_icon_ids）
   c. 绘制折叠箭头（fold_state）
   d. 遍历 runs：
      - TEXT / WHITESPACE: drawText(run.text, run.x, run.y) with run.style
      - INLAY_HINT: 绘制背景圆角矩形 + 文本/图标
      - PHANTOM_TEXT: 以半透明绘制
      - FOLD_PLACEHOLDER: 绘制 "…" 占位
7. 绘制 IME 组合输入下划线（composition_decoration）
8. 绘制诊断装饰（diagnostic_decorations）
9. 绘制联动编辑高亮（linked_editing_rects）
10. 绘制括号高亮（bracket_highlight_rects）
11. 绘制光标竖线（cursor）
12. 绘制选区拖拽手柄（selection handles）
```

---

## 跨平台桥接策略

### C API 层

非 Android 的主桥接契约是 `extern "C"` C API，对象通过 `intptr_t` 句柄传递：

```c
// 创建
uint8_t options_data[] = {/* LE 编码的 EditorOptions */};
intptr_t editor = create_editor(measurer, options_data, sizeof(options_data));

// 使用
set_editor_viewport(editor, width, height);
set_editor_document(editor, document);
size_t payload_size = 0;
const uint8_t* payload = build_editor_render_model(editor, &payload_size);

// 释放
free_binary_data((intptr_t)payload);
free_editor(editor);
```

### 数据交换格式

当前 C API 路径的数据交换统一为二进制 payload（本机字节序，当前支持平台均为 little-endian）：

- `build_editor_render_model()` → `EditorRenderModel`
- `get_layout_metrics()` → `LayoutMetrics`
- `handle_editor_gesture_event*()` → `GestureResult`
- `handle_editor_key_event()` → `KeyEventResult`
- `editor_insert_text()` / `undo()` / `redo()` 等 → `TextEditResult`
- `editor_get_scroll_metrics()` → `ScrollMetrics`

此外，`editor_set_line_spans()`、`editor_set_line_diagnostics()`、`editor_set_fold_regions()`、`editor_start_linked_editing()` 等输入型接口，也使用紧凑二进制 payload 传参。

字符串补充约定：

- binary payload 内的字符串字段当前统一为长度前缀 UTF-8
- `create_document_from_utf16()` / `get_document_line_text()` 是显式 UTF-16 边界
- 少量查询接口仍返回 UTF-8 `const char*`（如 `editor_get_selected_text()`）

### 各平台桥接方式

| 平台 | 桥接技术 | 调用方式 |
|------|---------|---------|
| Android | JNI (`jni_entry.cpp` + `jeditor.hpp`) | Java `native*` 直连 C++ 对象 |
| iOS/macOS | Swift Package + 手工 C bridge | Swift 调 bridge 函数 |
| Windows | P/Invoke | `DllImport(\"sweeteditor.dll\")` |
| Swing | Java FFM | Downcall 到 C API |
| Web | Emscripten | 目录存在，绑定未完成 |
| OHOS | - | 目录存在，未接入实现 |

注意：Android 目前不是经由 `c_api.h` 调用链路；新增公共能力时需要同步 JNI 路径与 C API 路径。

补充：

- Android 虽然是 JNI 直连，但 `buildRenderModel()`、手势结果、键盘结果、文本编辑结果、滚动度量同样通过二进制协议解码。
- Swing / WinForms 当前都走 `ProtocolDecoder` / `EditorProtocol` 读取 UTF-8 字符串字段。
- Apple 通过手工 bridge + Swift `BinaryReader` 消费同一套二进制布局。

---

## 数据流

### 用户输入 → 渲染 的完整流程

> 下面流程以 C API 平台（Swing/WinForms/Apple）为例；Android 同构但入口是 JNI 直连。

```
   用户触摸/点击
        │
        ▼
  平台层捕获事件
        │
        ▼
  C API: handle_editor_gesture_event()
        │
        ▼
  GestureHandler.handleGestureEvent()
        │  识别手势类型（TAP/SCROLL/SCALE/...）
        ▼
  EditorCore.handleGestureEvent()
        │  根据手势类型执行对应操作：
        │  · TAP → placeCursorAt() 定位光标
        │  · DOUBLE_TAP → selectWordAt() 选词
        │  · SCROLL → setScroll() 更新滚动
        │  · SCALE → setScale() 更新缩放
        │  · DRAG_SELECT → dragSelectTo() 拖拽选择
        ▼
  返回 GestureResult (binary payload)
        │
        ▼
  平台层检查是否需要重绘
        │
        ▼
  C API: build_editor_render_model()
        │
        ▼
  EditorCore.buildRenderModel()
        │  1. 更新 dirty 行的文本数据
        │  2. 重新布局 dirty 行
        │  3. 计算可见行范围
        │  4. 生成 VisualLine + VisualRun
        │  5. 计算光标屏幕坐标
        │  6. 计算选区高亮矩形
        │  7. 生成代码结构线
        ▼
  返回 EditorRenderModel (binary payload)
        │
        ▼
  平台层按模型绘制到屏幕
```

### 文本编辑流程

```
  用户输入字符 / 按 Backspace / 粘贴
        │
        ▼
  EditorCore.insertText() / backspace() / deleteForward()
        │
        ▼
  applyEdit(range, new_text)
        │
        ├──→ Document.replaceU8Text()        // 修改文本
        ├──→ DecorationManager.adjustForEdit() // 调整装饰偏移
        ├──→ autoUnfoldForEdit()              // 自动展开折叠
        ├──→ 标记 dirty 行                     // 延迟重新布局
        └──→ UndoManager.pushAction()          // 记录 undo
        │
        ▼
  返回 TextEditResult
        │  {changes:[{range:{start,end}, new_text}]}
        ▼
  平台层收到变更 → 调用 buildRenderModel() 重绘
```

---

## 内存管理

### 智能指针策略

| 指针类型 | 使用场景 |
|---------|---------|
| `Ptr<T>` (`shared_ptr`) | 跨模块共享的对象：Document、TextMeasurer、DecorationManager、StyleRegistry |
| `UPtr<T>` (`unique_ptr`) | 独占所有权：TextLayout、GestureHandler、UndoManager、Buffer |
| `WPtr<T>` (`weak_ptr`) | 需要时使用（目前未大量使用） |

### C API 的句柄管理

通过 `intptr_t` 传递句柄，C++ 侧实际用 `CPtrHolder<T>` 包装 `shared_ptr` 管理对象生命周期：

```cpp
intptr_t create_editor(...) {
  return makeCPtrHolderToIntPtr<EditorCore>(config, measurer);
}

void free_editor(intptr_t handle) {
  deleteCPtrHolder<EditorCore>(handle);
}
```

平台层须确保：

- 对象句柄在不再使用时调用 `free_document()` / `free_editor()`
- `build_editor_render_model()` 等返回的二进制 payload 用 `free_binary_data()` 释放
- `get_document_line_text()` 返回的 UTF-16 文本用 `free_u16_string()` 释放

---

## 性能优化策略

| 策略 | 描述 |
|------|------|
| **Dirty 标记延迟计算** | 编辑操作只标记 dirty，布局计算延迟到 `buildRenderModel()` 时按需执行 |
| **视口裁剪** | 只布局和生成可见区域的行，万行文档也只处理几十行 |
| **测量缓存** | `TextLayout` 内置 `HashMap<TextWidthKey, float>` 缓存已测量的文本宽度 |
| **SIMD Unicode** | 使用 simdutf 库进行 UTF-8 ↔ UTF-16 转换，利用 NEON/SSE/AVX 指令加速 |
| **文件内存映射** | `MappedFileBuffer` 使用 mmap 零拷贝打开大文件 |
| **Undo 操作合并** | 连续单字符输入/删除自动合并，减少内存占用 |
| **行高缓存** | `EditorCore` 维护 `HashMap<size_t, float> m_line_heights_` 缓存行高 |
| **二进制 payload 传递** | 渲染模型、布局度量、事件结果、编辑结果走紧凑二进制协议，减少跨语言解析成本 |
