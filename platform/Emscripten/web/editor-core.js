const FALLBACK_SPAN_LAYER = Object.freeze({
  SYNTAX: 0,
  SEMANTIC: 1,
});

const FALLBACK_INLAY_TYPE = Object.freeze({
  TEXT: 0,
  ICON: 1,
  COLOR: 2,
});

const FALLBACK_SEPARATOR_STYLE = Object.freeze({
  SINGLE: 0,
  DOUBLE: 1,
});

const FALLBACK_DIAGNOSTIC_SEVERITY = Object.freeze({
  DIAG_ERROR: 0,
  DIAG_WARNING: 1,
  DIAG_INFO: 2,
  DIAG_HINT: 3,
});

function resolveEnum(moduleObj, enumName, fallback) {
  const enumObj = moduleObj && moduleObj[enumName];
  if (!enumObj || typeof enumObj !== "object") {
    return fallback;
  }
  const resolved = { ...fallback };
  Object.keys(fallback).forEach((key) => {
    if (!(key in enumObj)) {
      return;
    }
    const value = toFiniteNumber(enumObj[key]);
    if (value !== null) {
      resolved[key] = value;
    }
  });
  return Object.freeze(resolved);
}

function toFiniteNumber(value) {
  if (value && typeof value === "object" && "value" in value) {
    const enumValue = Number(value.value);
    if (Number.isFinite(enumValue)) {
      return enumValue;
    }
  }

  const n = Number(value);
  if (Number.isFinite(n)) {
    return n;
  }
  return null;
}

function toInt(value, fallback = 0) {
  const n = toFiniteNumber(value);
  if (n === null) {
    return fallback;
  }
  return Math.trunc(n);
}

export function normalizeNewlines(text) {
  return String(text ?? "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

function hasLineBreak(text) {
  return /[\r\n]/.test(String(text ?? ""));
}

export function countLogicalLines(text) {
  const source = String(text ?? "");
  if (source.length === 0) {
    return 1;
  }

  let lines = 1;
  for (let i = 0; i < source.length; i += 1) {
    const code = source.charCodeAt(i);
    if (code === 10) {
      lines += 1;
      continue;
    }
    if (code === 13) {
      lines += 1;
      if (i + 1 < source.length && source.charCodeAt(i + 1) === 10) {
        i += 1;
      }
    }
  }
  return lines;
}

function asArray(value) {
  if (Array.isArray(value)) {
    return value;
  }

  if (!value) {
    return [];
  }

  if (typeof value.size === "function" && typeof value.get === "function") {
    const size = Math.max(0, toInt(value.size(), 0));
    const out = [];
    for (let i = 0; i < size; i += 1) {
      out.push(value.get(i));
    }
    return out;
  }

  if (typeof value[Symbol.iterator] === "function") {
    try {
      return Array.from(value);
    } catch (_) {
      return [];
    }
  }

  return [];
}

function ensureLine(value) {
  return Math.max(0, toInt(value, 0));
}

function ensureColumn(value) {
  return Math.max(0, toInt(value, 0));
}

function ensureLength(value) {
  return Math.max(0, toInt(value, 0));
}

function ensureRange(range, fallbackPosition = null) {
  if (range && range.start && range.end) {
    return {
      start: {
        line: ensureLine(range.start.line),
        column: ensureColumn(range.start.column),
      },
      end: {
        line: ensureLine(range.end.line),
        column: ensureColumn(range.end.column),
      },
    };
  }

  if (fallbackPosition && Number.isFinite(fallbackPosition.line) && Number.isFinite(fallbackPosition.column)) {
    return {
      start: {
        line: ensureLine(fallbackPosition.line),
        column: ensureColumn(fallbackPosition.column),
      },
      end: {
        line: ensureLine(fallbackPosition.line),
        column: ensureColumn(fallbackPosition.column),
      },
    };
  }

  return {
    start: { line: 0, column: 0 },
    end: { line: 0, column: 0 },
  };
}

export function clampVisibleLineRange(start, end, totalLines, maxLineSpan = Number.POSITIVE_INFINITY) {
  const total = Math.max(0, toInt(totalLines, 0));
  if (total <= 0) {
    return { start: 0, end: -1 };
  }

  let s = Math.max(0, toInt(start, 0));
  let e = Math.max(s, toInt(end, s));
  s = Math.min(s, total - 1);
  e = Math.min(e, total - 1);

  const maxSpan = Number(maxLineSpan);
  if (Number.isFinite(maxSpan)) {
    const limitedSpan = Math.max(1, toInt(maxSpan, 1));
    if ((e - s + 1) > limitedSpan) {
      e = Math.min(total - 1, s + limitedSpan - 1);
    }
  }

  return { start: s, end: e };
}

export function applyLineChangeToLines(lines, range, newText, options = {}) {
  if (!Array.isArray(lines)) {
    return;
  }

  const normalizedRange = ensureRange(range);
  if (lines.length === 0) {
    lines.push("");
  }

  let startLine = Math.max(0, toInt(normalizedRange.start.line, 0));
  let endLine = Math.max(0, toInt(normalizedRange.end.line, 0));
  let startColumn = Math.max(0, toInt(normalizedRange.start.column, 0));
  let endColumn = Math.max(0, toInt(normalizedRange.end.column, 0));

  if (startLine > endLine || (startLine === endLine && startColumn > endColumn)) {
    const swapLine = startLine;
    startLine = endLine;
    endLine = swapLine;

    const swapColumn = startColumn;
    startColumn = endColumn;
    endColumn = swapColumn;
  }

  startLine = Math.min(startLine, lines.length - 1);
  endLine = Math.min(endLine, lines.length - 1);

  const startText = String(lines[startLine] ?? "");
  const endText = String(lines[endLine] ?? "");
  startColumn = Math.min(startColumn, startText.length);
  endColumn = Math.min(endColumn, endText.length);

  const prefix = startText.slice(0, startColumn);
  const suffix = endText.slice(endColumn);

  const normalizeChangeText = options.normalizeNewlines !== false;
  const insertedText = normalizeChangeText ? normalizeNewlines(newText) : String(newText ?? "");
  const inserted = insertedText.split("\n");
  if (inserted.length === 0) {
    inserted.push("");
  }

  const replacement = [];
  if (inserted.length === 1) {
    replacement.push(`${prefix}${inserted[0]}${suffix}`);
  } else {
    replacement.push(`${prefix}${inserted[0]}`);
    for (let i = 1; i < inserted.length - 1; i += 1) {
      replacement.push(inserted[i]);
    }
    replacement.push(`${inserted[inserted.length - 1]}${suffix}`);
  }

  lines.splice(startLine, endLine - startLine + 1, ...replacement);
}

function lineColumnToOffset(text, targetLine, targetColumn) {
  const source = String(text ?? "");
  const targetLineNo = Math.max(0, toInt(targetLine, 0));
  const targetColumnNo = Math.max(0, toInt(targetColumn, 0));

  let line = 0;
  let index = 0;
  while (index < source.length && line < targetLineNo) {
    const code = source.charCodeAt(index);
    if (code === 13) {
      index += 1;
      if (index < source.length && source.charCodeAt(index) === 10) {
        index += 1;
      }
      line += 1;
      continue;
    }
    if (code === 10) {
      index += 1;
      line += 1;
      continue;
    }
    index += 1;
  }

  let column = 0;
  while (index < source.length && column < targetColumnNo) {
    const code = source.charCodeAt(index);
    if (code === 10 || code === 13) {
      break;
    }
    index += 1;
    column += 1;
  }
  return index;
}

export function applyTextChangeToText(originalText, range, newText, options = {}) {
  const source = String(originalText ?? "");
  const normalizedRange = ensureRange(range);
  let startOffset = lineColumnToOffset(source, normalizedRange.start.line, normalizedRange.start.column);
  let endOffset = lineColumnToOffset(source, normalizedRange.end.line, normalizedRange.end.column);
  if (startOffset > endOffset) {
    const tmp = startOffset;
    startOffset = endOffset;
    endOffset = tmp;
  }

  const insertedText = options.normalizeNewlines === false
    ? String(newText ?? "")
    : normalizeNewlines(newText);
  return `${source.slice(0, startOffset)}${insertedText}${source.slice(endOffset)}`;
}

export function applyTextChangesToText(originalText, changes, options = {}) {
  let output = String(originalText ?? "");
  asArray(changes).forEach((change) => {
    output = applyTextChangeToText(
      output,
      change?.range,
      change?.newText ?? change?.new_text ?? "",
      options,
    );
  });
  return output;
}

function isLineStructureChange(change) {
  const range = ensureRange(change?.range);
  if (range.start.line !== range.end.line) {
    return true;
  }

  return hasLineBreak(change?.oldText ?? change?.old_text ?? "")
    || hasLineBreak(change?.newText ?? change?.new_text ?? "");
}

function normalizePosition(position) {
  if (!position) {
    return { line: 0, column: 0 };
  }
  return {
    line: ensureLine(position.line),
    column: ensureColumn(position.column),
  };
}

function iterateLineEntries(input, callback) {
  if (!input) {
    return;
  }

  if (input instanceof Map) {
    input.forEach((items, line) => {
      callback(ensureLine(line), asArray(items));
    });
    return;
  }

  if (Array.isArray(input)) {
    input.forEach((entry, index) => {
      if (Array.isArray(entry) && entry.length >= 2) {
        callback(ensureLine(entry[0]), asArray(entry[1]));
        return;
      }
      if (entry && typeof entry === "object" && Number.isFinite(entry.line)) {
        const items = entry.items ?? entry.spans ?? entry.hints ?? entry.phantoms ?? entry.icons ?? entry.diagnostics;
        callback(ensureLine(entry.line), asArray(items));
        return;
      }
      callback(ensureLine(index), asArray(entry));
    });
    return;
  }

  if (typeof input === "object") {
    Object.keys(input).forEach((lineKey) => {
      callback(ensureLine(lineKey), asArray(input[lineKey]));
    });
  }
}

function cloneLineMap(input) {
  if (input == null) {
    return null;
  }
  const out = new Map();
  iterateLineEntries(input, (line, items) => {
    out.set(line, items.map((item) => ({ ...item })));
  });
  return out;
}

function cloneList(input) {
  if (input == null) {
    return null;
  }
  return asArray(input).map((item) => {
    if (item == null || typeof item !== "object") {
      return item;
    }
    if (Array.isArray(item)) {
      return item.slice();
    }
    return { ...item };
  });
}

function appendLineMap(target, source) {
  if (!source) {
    return;
  }
  source.forEach((items, line) => {
    if (!target.has(line)) {
      target.set(line, []);
    }
    const outItems = target.get(line);
    items.forEach((item) => {
      outItems.push({ ...item });
    });
  });
}

function modePriority(mode) {
  switch (mode) {
    case DecorationApplyMode.REPLACE_ALL:
      return 2;
    case DecorationApplyMode.REPLACE_RANGE:
      return 1;
    case DecorationApplyMode.MERGE:
    default:
      return 0;
  }
}

function mergeMode(current, next) {
  return modePriority(next) > modePriority(current) ? next : current;
}

function normalizeCompletionKind(kind) {
  const n = toInt(kind, CompletionItem.KIND_TEXT);
  return n >= CompletionItem.KIND_KEYWORD && n <= CompletionItem.KIND_TEXT
    ? n
    : CompletionItem.KIND_TEXT;
}

function normalizeInsertTextFormat(format) {
  const n = toInt(format, CompletionItem.INSERT_TEXT_FORMAT_PLAIN_TEXT);
  if (n === CompletionItem.INSERT_TEXT_FORMAT_SNIPPET) {
    return n;
  }
  return CompletionItem.INSERT_TEXT_FORMAT_PLAIN_TEXT;
}

function normalizeCompletionItem(input) {
  if (input instanceof CompletionItem) {
    return input;
  }
  return new CompletionItem(input || {});
}

function normalizeCompletionItems(items) {
  return asArray(items).map((item) => normalizeCompletionItem(item));
}

function safeCall(fn) {
  try {
    return fn();
  } catch (error) {
    console.error(error);
    return null;
  }
}

export async function loadSweetEditorCore(options = {}) {
  const { moduleFactory, modulePath, moduleOptions = {} } = options;

  let factory = moduleFactory;
  let moduleBaseUrl = null;
  if (!factory) {
    if (!modulePath) {
      throw new Error("modulePath or moduleFactory is required to load SweetEditor wasm module.");
    }
    moduleBaseUrl = new URL(modulePath, import.meta.url);
    const imported = await import(moduleBaseUrl.href);
    factory = imported.default || imported.createSweetEditorModule || imported;
  }

  if (typeof factory !== "function") {
    throw new Error("Invalid wasm module factory.");
  }

  const finalOptions = { ...moduleOptions };
  if (moduleBaseUrl && typeof finalOptions.locateFile !== "function") {
    finalOptions.locateFile = (path) => {
      const url = new URL(path, moduleBaseUrl);
      if (moduleBaseUrl.search && !url.search) {
        url.search = moduleBaseUrl.search;
      }
      return url.href;
    };
  }

  return factory(finalOptions);
}

export class Document {
  constructor(nativeDocument, kind) {
    if (new.target === Document) {
      throw new TypeError("Document is abstract. Use DocumentFactory.");
    }
    this._native = nativeDocument;
    this.kind = kind;
  }

  getNative() {
    return this._native;
  }

  getText() {
    return this._native.getU8Text();
  }

  getLineCount() {
    return this._native.getLineCount();
  }

  getLineText(line) {
    return this._native.getLineU16Text(line);
  }

  getPositionFromCharIndex(charIndex) {
    return this._native.getPositionFromCharIndex(charIndex);
  }

  getCharIndexFromPosition(position) {
    return this._native.getCharIndexFromPosition(position);
  }

  dispose() {
    if (this._native) {
      this._native.delete();
      this._native = null;
    }
  }
}

class PieceTableDocumentImpl extends Document {
  constructor(nativeDocument) {
    super(nativeDocument, "piece-table");
  }
}

class LineArrayDocumentImpl extends Document {
  constructor(nativeDocument) {
    super(nativeDocument, "line-array");
  }
}

export class DocumentFactory {
  constructor(wasmModule) {
    this._wasm = wasmModule;
  }

  fromText(text, options = {}) {
    const kind = options.kind || "piece-table";
    if (kind === "line-array") {
      return this.fromLineArray(text);
    }
    return this.fromPieceTable(text);
  }

  fromPieceTable(text) {
    return new PieceTableDocumentImpl(new this._wasm.PieceTableDocument(text || ""));
  }

  fromLineArray(text) {
    return new LineArrayDocumentImpl(new this._wasm.LineArrayDocument(text || ""));
  }
}
export class WebEditorCore {
  constructor(wasmModule, textMeasurerCallbacks, editorOptions = {}, onDidMutate = null) {
    this._wasm = wasmModule;
    this._onDidMutate = typeof onDidMutate === "function" ? onDidMutate : null;
    this._notifySuppressed = 0;
    this._notifyPending = false;

    const nativeOptions = {
      touch_slop: editorOptions.touchSlop ?? 10.0,
      double_tap_timeout: editorOptions.doubleTapTimeout ?? 300,
      long_press_ms: editorOptions.longPressMs ?? 500,
      max_undo_stack_size: editorOptions.maxUndoStackSize ?? 512,
    };

    this._native = new wasmModule.EditorCore(textMeasurerCallbacks, nativeOptions);
    this._spanLayer = resolveEnum(wasmModule, "SpanLayer", FALLBACK_SPAN_LAYER);
    this._inlayType = resolveEnum(wasmModule, "InlayType", FALLBACK_INLAY_TYPE);
    this._separatorStyle = resolveEnum(wasmModule, "SeparatorStyle", FALLBACK_SEPARATOR_STYLE);
    this._diagnosticSeverity = resolveEnum(wasmModule, "DiagnosticSeverity", FALLBACK_DIAGNOSTIC_SEVERITY);
  }

  getNative() {
    return this._native;
  }

  beginBatch() {
    this._notifySuppressed += 1;
  }

  endBatch() {
    if (this._notifySuppressed > 0) {
      this._notifySuppressed -= 1;
    }
    if (this._notifySuppressed === 0 && this._notifyPending) {
      this._notifyPending = false;
      this._emitMutate();
    }
  }

  withBatch(fn) {
    this.beginBatch();
    try {
      return fn();
    } finally {
      this.endBatch();
    }
  }

  _invoke(method, ...args) {
    const fn = this._native?.[method];
    if (typeof fn !== "function") {
      throw new Error(`EditorCore method not found: ${method}`);
    }
    return fn.apply(this._native, args);
  }

  call(method, ...args) {
    const result = this._invoke(method, ...args);
    this._notifyMutate();
    return result;
  }

  read(method, ...args) {
    return this._invoke(method, ...args);
  }

  loadDocument(document) {
    const nativeDoc = typeof document?.getNative === "function" ? document.getNative() : document;
    const result = this._native.loadDocument(nativeDoc);
    this._notifyMutate();
    return result;
  }

  setViewport(width, height) {
    const result = this._native.setViewport({ width, height });
    this._notifyMutate();
    return result;
  }

  buildRenderModel() {
    return this.read("buildRenderModel");
  }

  handleGestureEvent(eventData) {
    const result = this._native.handleGestureEventRaw(
      eventData.type ?? 0,
      eventData.points,
      eventData.modifiers ?? 0,
      eventData.wheel_delta_x ?? 0,
      eventData.wheel_delta_y ?? 0,
      eventData.direct_scale ?? 1.0,
    );
    this._notifyMutate();
    return result;
  }

  handleKeyEvent(eventData) {
    const result = this._native.handleKeyEventRaw(
      eventData.key_code ?? 0,
      eventData.text ?? "",
      eventData.modifiers ?? 0,
    );
    this._notifyMutate();
    return result;
  }

  tickEdgeScroll() {
    const result = this._native.tickEdgeScroll();
    this._notifyMutate();
    return result;
  }

  tickFling() {
    const result = this._native.tickFling();
    this._notifyMutate();
    return result;
  }

  onFontMetricsChanged() {
    const result = this._native.onFontMetricsChanged();
    this._notifyMutate();
    return result;
  }

  setFoldArrowMode(mode) {
    const result = this._native.setFoldArrowMode(toInt(mode, 0));
    this._notifyMutate();
    return result;
  }

  setWrapMode(mode) {
    const result = this._native.setWrapMode(toInt(mode, 0));
    this._notifyMutate();
    return result;
  }

  setTabSize(tabSize) {
    if (typeof this._native?.setTabSize === "function") {
      const result = this._native.setTabSize(Math.max(1, toInt(tabSize, 4)));
      this._notifyMutate();
      return result;
    }
  }

  setScale(scale) {
    const value = Number(scale);
    const result = this._native.setScale(Number.isFinite(value) ? value : 1.0);
    this._notifyMutate();
    return result;
  }

  setLineSpacing(add, mult) {
    const addValue = Number(add);
    const multValue = Number(mult);
    const result = this._native.setLineSpacing(
      Number.isFinite(addValue) ? addValue : 0.0,
      Number.isFinite(multValue) ? multValue : 1.0,
    );
    this._notifyMutate();
    return result;
  }

  setContentStartPadding(padding) {
    const value = Number(padding);
    const result = this._native.setContentStartPadding(Number.isFinite(value) ? value : 0.0);
    this._notifyMutate();
    return result;
  }

  setShowSplitLine(show) {
    const result = this._native.setShowSplitLine(Boolean(show));
    this._notifyMutate();
    return result;
  }

  setCurrentLineRenderMode(mode) {
    const result = this._native.setCurrentLineRenderMode(toInt(mode, 0));
    this._notifyMutate();
    return result;
  }

  getViewState() {
    return this.read("getViewState");
  }

  getScrollMetrics() {
    return this.read("getScrollMetrics");
  }

  getLayoutMetrics() {
    return this.read("getLayoutMetrics");
  }

  insert(text) {
    const result = this._native.insertText(String(text ?? ""));
    this._notifyMutate();
    return result;
  }

  replaceText(range, newText) {
    const result = this._native.replaceText(ensureRange(range), String(newText ?? ""));
    this._notifyMutate();
    return result;
  }

  deleteText(range) {
    const result = this._native.deleteText(ensureRange(range));
    this._notifyMutate();
    return result;
  }

  backspace() {
    const result = this._native.backspace();
    this._notifyMutate();
    return result;
  }

  deleteForward() {
    const result = this._native.deleteForward();
    this._notifyMutate();
    return result;
  }

  moveLineUp() {
    const result = this._native.moveLineUp();
    this._notifyMutate();
    return result;
  }

  moveLineDown() {
    const result = this._native.moveLineDown();
    this._notifyMutate();
    return result;
  }

  copyLineUp() {
    const result = this._native.copyLineUp();
    this._notifyMutate();
    return result;
  }

  copyLineDown() {
    const result = this._native.copyLineDown();
    this._notifyMutate();
    return result;
  }

  deleteLine() {
    const result = this._native.deleteLine();
    this._notifyMutate();
    return result;
  }

  insertLineAbove() {
    const result = this._native.insertLineAbove();
    this._notifyMutate();
    return result;
  }

  insertLineBelow() {
    const result = this._native.insertLineBelow();
    this._notifyMutate();
    return result;
  }

  undo() {
    const result = this._native.undo();
    this._notifyMutate();
    return result;
  }

  redo() {
    const result = this._native.redo();
    this._notifyMutate();
    return result;
  }

  setCursorPosition(position) {
    const result = this._native.setCursorPosition(normalizePosition(position));
    this._notifyMutate();
    return result;
  }

  setSelection(startOrRange, startColumn, endLine, endColumn) {
    let result;
    if (startOrRange && typeof startOrRange === "object" && startOrRange.start && startOrRange.end) {
      result = this._native.setSelection(ensureRange(startOrRange));
    } else {
      const range = ensureRange({
        start: {
          line: ensureLine(startOrRange),
          column: ensureColumn(startColumn),
        },
        end: {
          line: ensureLine(endLine),
          column: ensureColumn(endColumn),
        },
      });
      result = this._native.setSelection(range);
    }
    this._notifyMutate();
    return result;
  }

  clearSelection() {
    const result = this._native.clearSelection();
    this._notifyMutate();
    return result;
  }

  selectAll() {
    const result = this._native.selectAll();
    this._notifyMutate();
    return result;
  }

  getSelectedText() {
    return this.read("getSelectedText");
  }

  moveCursorLeft(extendSelection = false) {
    const result = this._native.moveCursorLeft(Boolean(extendSelection));
    this._notifyMutate();
    return result;
  }

  moveCursorRight(extendSelection = false) {
    const result = this._native.moveCursorRight(Boolean(extendSelection));
    this._notifyMutate();
    return result;
  }

  moveCursorUp(extendSelection = false) {
    const result = this._native.moveCursorUp(Boolean(extendSelection));
    this._notifyMutate();
    return result;
  }

  moveCursorDown(extendSelection = false) {
    const result = this._native.moveCursorDown(Boolean(extendSelection));
    this._notifyMutate();
    return result;
  }

  moveCursorToLineStart(extendSelection = false) {
    const result = this._native.moveCursorToLineStart(Boolean(extendSelection));
    this._notifyMutate();
    return result;
  }

  moveCursorToLineEnd(extendSelection = false) {
    const result = this._native.moveCursorToLineEnd(Boolean(extendSelection));
    this._notifyMutate();
    return result;
  }

  compositionStart() {
    const result = this._native.compositionStart();
    this._notifyMutate();
    return result;
  }

  compositionUpdate(text) {
    const result = this._native.compositionUpdate(String(text ?? ""));
    this._notifyMutate();
    return result;
  }

  compositionEnd(committedText) {
    const result = this._native.compositionEnd(String(committedText ?? ""));
    this._notifyMutate();
    return result;
  }

  compositionCancel() {
    const result = this._native.compositionCancel();
    this._notifyMutate();
    return result;
  }

  isComposing() {
    return this.read("isComposing");
  }

  setCompositionEnabled(enabled) {
    const result = this._native.setCompositionEnabled(Boolean(enabled));
    this._notifyMutate();
    return result;
  }

  isCompositionEnabled() {
    return this.read("isCompositionEnabled");
  }

  setReadOnly(readOnly) {
    const result = this._native.setReadOnly(Boolean(readOnly));
    this._notifyMutate();
    return result;
  }

  isReadOnly() {
    return this.read("isReadOnly");
  }

  setAutoIndentMode(mode) {
    const result = this._native.setAutoIndentMode(toInt(mode, 0));
    this._notifyMutate();
    return result;
  }

  getAutoIndentMode() {
    return this.read("getAutoIndentMode");
  }

  setHandleConfig(config) {
    const result = this._native.setHandleConfig(config || {});
    this._notifyMutate();
    return result;
  }

  getHandleConfig() {
    if (typeof this._native?.getHandleConfig === "function") {
      return this.read("getHandleConfig");
    }
    return null;
  }

  setScrollbarConfig(config) {
    const result = this._native.setScrollbarConfig(config || {});
    this._notifyMutate();
    return result;
  }

  getScrollbarConfig() {
    if (typeof this._native?.getScrollbarConfig === "function") {
      return this.read("getScrollbarConfig");
    }
    return null;
  }

  getPositionRect(line, column) {
    if (typeof this._native?.getPositionScreenRect === "function") {
      return this.read("getPositionScreenRect", ensureLine(line), ensureColumn(column));
    }
    return this.read("getPositionRect", ensureLine(line), ensureColumn(column));
  }

  getCursorRect() {
    if (typeof this._native?.getCursorScreenRect === "function") {
      return this.read("getCursorScreenRect");
    }
    return this.read("getCursorRect");
  }

  scrollToLine(line, behavior = 0) {
    const result = this._native.scrollToLine(ensureLine(line), toInt(behavior, 0));
    this._notifyMutate();
    return result;
  }

  gotoPosition(line, column) {
    const result = this._native.gotoPosition(ensureLine(line), ensureColumn(column));
    this._notifyMutate();
    return result;
  }

  setScroll(scrollX, scrollY) {
    const x = Number(scrollX);
    const y = Number(scrollY);
    const result = this._native.setScroll(
      Number.isFinite(x) ? x : 0.0,
      Number.isFinite(y) ? y : 0.0,
    );
    this._notifyMutate();
    return result;
  }

  insertSnippet(snippetTemplate) {
    const result = this._native.insertSnippet(String(snippetTemplate ?? ""));
    this._notifyMutate();
    return result;
  }

  startLinkedEditing(model) {
    const result = this._native.startLinkedEditing(model || {});
    this._notifyMutate();
    return result;
  }

  linkedEditingNext() {
    if (typeof this._native?.linkedEditingNextTabStop === "function") {
      const result = this._native.linkedEditingNextTabStop();
      this._notifyMutate();
      return result;
    }
    const result = this._native.linkedEditingNext();
    this._notifyMutate();
    return result;
  }

  linkedEditingPrev() {
    if (typeof this._native?.linkedEditingPrevTabStop === "function") {
      const result = this._native.linkedEditingPrevTabStop();
      this._notifyMutate();
      return result;
    }
    const result = this._native.linkedEditingPrev();
    this._notifyMutate();
    return result;
  }

  cancelLinkedEditing() {
    const result = this._native.cancelLinkedEditing();
    this._notifyMutate();
    return result;
  }

  finishLinkedEditing() {
    const result = this._native.finishLinkedEditing();
    this._notifyMutate();
    return result;
  }

  toggleFoldAt(line) {
    const result = this._native.toggleFoldAt(ensureLine(line));
    this._notifyMutate();
    return result;
  }

  foldAt(line) {
    const result = this._native.foldAt(ensureLine(line));
    this._notifyMutate();
    return result;
  }

  unfoldAt(line) {
    const result = this._native.unfoldAt(ensureLine(line));
    this._notifyMutate();
    return result;
  }

  foldAll() {
    const result = this._native.foldAll();
    this._notifyMutate();
    return result;
  }

  unfoldAll() {
    const result = this._native.unfoldAll();
    this._notifyMutate();
    return result;
  }

  isLineVisible(line) {
    return this.read("isLineVisible", ensureLine(line));
  }

  setMatchedBrackets(open, close) {
    let result;
    if (arguments.length >= 4) {
      const openPosition = { line: ensureLine(arguments[0]), column: ensureColumn(arguments[1]) };
      const closePosition = { line: ensureLine(arguments[2]), column: ensureColumn(arguments[3]) };
      result = this._native.setMatchedBrackets(openPosition, closePosition);
    } else {
      result = this._native.setMatchedBrackets(normalizePosition(open), normalizePosition(close));
    }
    this._notifyMutate();
    return result;
  }

  clearMatchedBrackets() {
    const result = this._native.clearMatchedBrackets();
    this._notifyMutate();
    return result;
  }

  getCursorPosition() {
    return this.read("getCursorPosition");
  }

  getWordRangeAtCursor() {
    return this.read("getWordRangeAtCursor");
  }

  getWordAtCursor() {
    return this.read("getWordAtCursor");
  }

  getSelection() {
    return this.read("getSelection");
  }

  hasSelection() {
    return this.read("hasSelection");
  }

  canUndo() {
    return this.read("canUndo");
  }

  canRedo() {
    return this.read("canRedo");
  }

  isInLinkedEditing() {
    return this.read("isInLinkedEditing");
  }

  registerTextStyle(styleId, color, backgroundColor = 0, fontStyle = 0) {
    const style = {
      color: toInt(color, 0),
      background_color: toInt(backgroundColor, 0),
      font_style: toInt(fontStyle, 0),
    };
    const result = this._native.registerTextStyle(toInt(styleId, 0), style);
    this._notifyMutate();
    return result;
  }

  setLineSpans(line, layer, spans) {
    const lineNo = ensureLine(line);
    const layerValue = toInt(layer, this._spanLayer.SYNTAX);
    const src = asArray(spans);
    this._callWithVector("StyleSpanVector", src, (span) => ({
      column: ensureColumn(span.column),
      length: ensureLength(span.length),
      style_id: toInt(span.styleId ?? span.style_id, 0),
    }), (vec) => {
      const result = this._native.setLineSpans(lineNo, layerValue, vec);
      this._notifyMutate();
      return result;
    });
  }

  setBatchLineSpans(layer, spansByLine) {
    const layerValue = toInt(layer, this._spanLayer.SYNTAX);
    const batched = this._callBatchLineEntries(
      "LineStyleSpansEntryVector",
      "StyleSpanVector",
      "spans",
      spansByLine,
      (span) => ({
        column: ensureColumn(span.column),
        length: ensureLength(span.length),
        style_id: toInt(span.styleId ?? span.style_id, 0),
      }),
      (entryVec) => {
        const result = this._native.setBatchLineSpans(layerValue, entryVec);
        return result;
      },
    );
    if (batched) {
      this._notifyMutate();
      return;
    }
    this.withBatch(() => {
      iterateLineEntries(spansByLine, (line, spans) => {
        this.setLineSpans(line, layerValue, spans);
      });
    });
  }

  setLineInlayHints(line, hints) {
    const lineNo = ensureLine(line);
    const src = asArray(hints);
    this._callWithVector("InlayHintVector", src, (hint) => this._toNativeInlayHint(hint), (vec) => {
      const result = this._native.setLineInlayHints(lineNo, vec);
      this._notifyMutate();
      return result;
    });
  }

  setBatchLineInlayHints(hintsByLine) {
    const batched = this._callBatchLineEntries(
      "LineInlayHintsEntryVector",
      "InlayHintVector",
      "hints",
      hintsByLine,
      (hint) => this._toNativeInlayHint(hint),
      (entryVec) => {
        const result = this._native.setBatchLineInlayHints(entryVec);
        return result;
      },
    );
    if (batched) {
      this._notifyMutate();
      return;
    }
    this.withBatch(() => {
      iterateLineEntries(hintsByLine, (line, hints) => {
        this.setLineInlayHints(line, hints);
      });
    });
  }

  setLinePhantomTexts(line, phantoms) {
    const lineNo = ensureLine(line);
    const src = asArray(phantoms);
    this._callWithVector("PhantomTextVector", src, (phantom) => ({
      column: ensureColumn(phantom.column),
      text: String(phantom.text ?? ""),
    }), (vec) => {
      const result = this._native.setLinePhantomTexts(lineNo, vec);
      this._notifyMutate();
      return result;
    });
  }

  setBatchLinePhantomTexts(phantomsByLine) {
    const batched = this._callBatchLineEntries(
      "LinePhantomTextsEntryVector",
      "PhantomTextVector",
      "phantoms",
      phantomsByLine,
      (phantom) => ({
        column: ensureColumn(phantom.column),
        text: String(phantom.text ?? ""),
      }),
      (entryVec) => {
        const result = this._native.setBatchLinePhantomTexts(entryVec);
        return result;
      },
    );
    if (batched) {
      this._notifyMutate();
      return;
    }
    this.withBatch(() => {
      iterateLineEntries(phantomsByLine, (line, phantoms) => {
        this.setLinePhantomTexts(line, phantoms);
      });
    });
  }

  setLineGutterIcons(line, icons) {
    const lineNo = ensureLine(line);
    const src = asArray(icons);
    this._callWithVector("GutterIconVector", src, (icon) => ({
      icon_id: toInt(icon.iconId ?? icon.icon_id ?? icon, 0),
    }), (vec) => {
      const result = this._native.setLineGutterIcons(lineNo, vec);
      this._notifyMutate();
      return result;
    });
  }

  setBatchLineGutterIcons(iconsByLine) {
    const batched = this._callBatchLineEntries(
      "LineGutterIconsEntryVector",
      "GutterIconVector",
      "icons",
      iconsByLine,
      (icon) => ({
        icon_id: toInt(icon.iconId ?? icon.icon_id ?? icon, 0),
      }),
      (entryVec) => {
        const result = this._native.setBatchLineGutterIcons(entryVec);
        return result;
      },
    );
    if (batched) {
      this._notifyMutate();
      return;
    }
    this.withBatch(() => {
      iterateLineEntries(iconsByLine, (line, icons) => {
        this.setLineGutterIcons(line, icons);
      });
    });
  }

  setLineDiagnostics(line, diagnostics) {
    const lineNo = ensureLine(line);
    const src = asArray(diagnostics);
    this._callWithVector("DiagnosticSpanVector", src, (item) => ({
      column: ensureColumn(item.column),
      length: ensureLength(item.length),
      severity: this._toNativeEnumValue("DiagnosticSeverity", item.severity, this._diagnosticSeverity.DIAG_HINT),
      color: toInt(item.color, 0),
    }), (vec) => {
      const result = this._native.setLineDiagnostics(lineNo, vec);
      this._notifyMutate();
      return result;
    });
  }

  setBatchLineDiagnostics(diagsByLine) {
    const batched = this._callBatchLineEntries(
      "LineDiagnosticsEntryVector",
      "DiagnosticSpanVector",
      "diagnostics",
      diagsByLine,
      (item) => ({
        column: ensureColumn(item.column),
        length: ensureLength(item.length),
        severity: this._toNativeEnumValue("DiagnosticSeverity", item.severity, this._diagnosticSeverity.DIAG_HINT),
        color: toInt(item.color, 0),
      }),
      (entryVec) => {
        const result = this._native.setBatchLineDiagnostics(entryVec);
        return result;
      },
    );
    if (batched) {
      this._notifyMutate();
      return;
    }
    this.withBatch(() => {
      iterateLineEntries(diagsByLine, (line, diagnostics) => {
        this.setLineDiagnostics(line, diagnostics);
      });
    });
  }

  setIndentGuides(guides) {
    this._callWithVector("IndentGuideVector", asArray(guides), (item) => ({
      start: normalizePosition(item.start),
      end: normalizePosition(item.end),
    }), (vec) => {
      const result = this._native.setIndentGuides(vec);
      this._notifyMutate();
      return result;
    });
  }

  setBracketGuides(guides) {
    this._callWithVector("BracketGuideVector", asArray(guides), (item) => ({
      parent: normalizePosition(item.parent),
      end: normalizePosition(item.end),
      children: asArray(item.children).map((child) => normalizePosition(child)),
    }), (vec) => {
      const result = this._native.setBracketGuides(vec);
      this._notifyMutate();
      return result;
    });
  }

  setFlowGuides(guides) {
    this._callWithVector("FlowGuideVector", asArray(guides), (item) => ({
      start: normalizePosition(item.start),
      end: normalizePosition(item.end),
    }), (vec) => {
      const result = this._native.setFlowGuides(vec);
      this._notifyMutate();
      return result;
    });
  }

  setSeparatorGuides(guides) {
    this._callWithVector("SeparatorGuideVector", asArray(guides), (item) => ({
      line: ensureLine(item.line),
      style: this._toNativeEnumValue("SeparatorStyle", item.style, this._separatorStyle.SINGLE),
      count: Math.max(0, toInt(item.count, 0)),
      text_end_column: Math.max(0, toInt(item.textEndColumn ?? item.text_end_column, 0)),
    }), (vec) => {
      const result = this._native.setSeparatorGuides(vec);
      this._notifyMutate();
      return result;
    });
  }

  setFoldRegions(regions) {
    this._callWithVector("FoldRegionVector", asArray(regions), (item) => ({
      start_line: ensureLine(item.startLine ?? item.start_line),
      end_line: ensureLine(item.endLine ?? item.end_line),
      collapsed: Boolean(item.collapsed),
    }), (vec) => {
      const result = this._native.setFoldRegions(vec);
      this._notifyMutate();
      return result;
    });
  }

  setMaxGutterIcons(count) {
    const result = this._native.setMaxGutterIcons(Math.max(0, toInt(count, 0)));
    this._notifyMutate();
    return result;
  }

  clearHighlights(layer = null) {
    let result;
    if (layer == null) {
      result = this._native.clearHighlights();
    } else {
      result = this._native.clearHighlights(toInt(layer, this._spanLayer.SYNTAX));
    }
    this._notifyMutate();
    return result;
  }

  clearInlayHints() {
    const result = this._native.clearInlayHints();
    this._notifyMutate();
    return result;
  }

  clearPhantomTexts() {
    const result = this._native.clearPhantomTexts();
    this._notifyMutate();
    return result;
  }

  clearGutterIcons() {
    const result = this._native.clearGutterIcons();
    this._notifyMutate();
    return result;
  }

  clearDiagnostics() {
    const result = this._native.clearDiagnostics();
    this._notifyMutate();
    return result;
  }

  clearGuides() {
    const result = this._native.clearGuides();
    this._notifyMutate();
    return result;
  }

  clearAllDecorations() {
    const result = this._native.clearAllDecorations();
    this._notifyMutate();
    return result;
  }

  setBracketPairs(bracketPairs) {
    this._callWithVector("BracketPairVector", asArray(bracketPairs), (pair) => ({
      open: toInt(pair.open, 0),
      close: toInt(pair.close, 0),
      auto_close: Boolean(pair.autoClose ?? pair.auto_close),
      surround: Boolean(pair.surround),
    }), (vec) => {
      const result = this._native.setBracketPairs(vec);
      this._notifyMutate();
      return result;
    });
  }

  _toNativeInlayHint(hint) {
    const typeValue = toInt(hint.type, this._inlayType.TEXT);
    const nativeType = this._toNativeEnumValue("InlayType", typeValue, this._inlayType.TEXT);
    if (typeValue === this._inlayType.ICON) {
      return {
        type: nativeType,
        column: ensureColumn(hint.column),
        text: "",
        icon_id: toInt(hint.iconId ?? hint.icon_id ?? hint.intValue, 0),
        color: 0,
      };
    }
    if (typeValue === this._inlayType.COLOR) {
      return {
        type: nativeType,
        column: ensureColumn(hint.column),
        text: "",
        icon_id: 0,
        color: toInt(hint.color ?? hint.colorValue ?? hint.intValue, 0),
      };
    }
    return {
      type: this._toNativeEnumValue("InlayType", this._inlayType.TEXT, this._inlayType.TEXT),
      column: ensureColumn(hint.column),
      text: String(hint.text ?? ""),
      icon_id: 0,
      color: 0,
    };
  }

  _toNativeEnumValue(enumName, value, fallback = 0) {
    const numericValue = toInt(value, fallback);
    const enumType = this._wasm?.[enumName];
    const enumValues = enumType?.values;
    if (enumValues && Object.prototype.hasOwnProperty.call(enumValues, String(numericValue))) {
      return enumValues[String(numericValue)];
    }
    return numericValue;
  }

  _callBatchLineEntries(entryVectorName, itemVectorName, entryFieldName, entriesByLine, itemMapper, fn) {
    const normalizedEntries = [];
    iterateLineEntries(entriesByLine, (line, items) => {
      normalizedEntries.push({
        line: ensureLine(line),
        items: asArray(items),
      });
    });
    if (normalizedEntries.length === 0) {
      return true;
    }

    const EntryVectorCtor = this._wasm?.[entryVectorName];
    const ItemVectorCtor = this._wasm?.[itemVectorName];
    if (typeof EntryVectorCtor !== "function" || typeof ItemVectorCtor !== "function") {
      return false;
    }

    const entryVec = new EntryVectorCtor();
    try {
      normalizedEntries.forEach((entry) => {
        const itemVec = new ItemVectorCtor();
        try {
          entry.items.forEach((item) => {
            itemVec.push_back(itemMapper(item));
          });
          entryVec.push_back({
            line: entry.line,
            [entryFieldName]: itemVec,
          });
        } finally {
          if (typeof itemVec.delete === "function") {
            itemVec.delete();
          }
        }
      });
      fn(entryVec);
      return true;
    } finally {
      if (typeof entryVec.delete === "function") {
        entryVec.delete();
      }
    }
  }

  _callWithVector(vectorName, items, mapper, fn) {
    const Ctor = this._wasm?.[vectorName];
    if (typeof Ctor !== "function") {
      throw new Error(`Vector constructor not found: ${vectorName}`);
    }
    const vec = new Ctor();
    try {
      asArray(items).forEach((item) => {
        vec.push_back(mapper(item));
      });
      fn(vec);
    } finally {
      if (typeof vec.delete === "function") {
        vec.delete();
      }
    }
  }

  dispose() {
    if (this._native) {
      this._native.delete();
      this._native = null;
    }
  }

  _notifyMutate() {
    if (this._notifySuppressed > 0) {
      this._notifyPending = true;
      return;
    }
    this._emitMutate();
  }

  _emitMutate() {
    if (this._onDidMutate) {
      this._onDidMutate();
    }
  }
}
export const CompletionTriggerKind = Object.freeze({
  INVOKED: 0,
  CHARACTER: 1,
  RETRIGGER: 2,
});

export class CompletionItem {
  static KIND_KEYWORD = 0;
  static KIND_FUNCTION = 1;
  static KIND_VARIABLE = 2;
  static KIND_CLASS = 3;
  static KIND_INTERFACE = 4;
  static KIND_MODULE = 5;
  static KIND_PROPERTY = 6;
  static KIND_SNIPPET = 7;
  static KIND_TEXT = 8;

  static INSERT_TEXT_FORMAT_PLAIN_TEXT = 1;
  static INSERT_TEXT_FORMAT_SNIPPET = 2;

  constructor(init = {}) {
    this.label = String(init.label ?? "");
    this.detail = init.detail == null ? null : String(init.detail);
    this.insertText = init.insertText == null ? null : String(init.insertText);
    this.insertTextFormat = normalizeInsertTextFormat(init.insertTextFormat);
    this.textEdit = init.textEdit
      ? {
          range: ensureRange(init.textEdit.range),
          newText: String(init.textEdit.newText ?? ""),
        }
      : null;
    this.filterText = init.filterText == null ? null : String(init.filterText);
    this.sortKey = init.sortKey == null ? null : String(init.sortKey);
    this.kind = normalizeCompletionKind(init.kind);
  }

  get matchText() {
    return this.filterText || this.label;
  }
}

export class CompletionContext {
  constructor({
    triggerKind = CompletionTriggerKind.INVOKED,
    triggerCharacter = null,
    cursorPosition = { line: 0, column: 0 },
    lineText = "",
    wordRange = null,
    languageConfiguration = null,
    editorMetadata = null,
  } = {}) {
    this.triggerKind = toInt(triggerKind, CompletionTriggerKind.INVOKED);
    this.triggerCharacter = triggerCharacter == null ? null : String(triggerCharacter);
    this.cursorPosition = normalizePosition(cursorPosition);
    this.lineText = String(lineText ?? "");
    this.wordRange = ensureRange(wordRange, this.cursorPosition);
    this.languageConfiguration = languageConfiguration;
    this.editorMetadata = editorMetadata;
  }
}

export class CompletionResult {
  constructor(items = [], isIncomplete = false) {
    this.items = normalizeCompletionItems(items);
    this.isIncomplete = Boolean(isIncomplete);
  }

  static EMPTY = new CompletionResult([], false);
}

export class CompletionReceiver {
  accept(_result) {
    throw new Error("CompletionReceiver.accept must be implemented");
  }

  get isCancelled() {
    return true;
  }
}

export class CompletionProvider {
  isTriggerCharacter(_ch) {
    return false;
  }

  provideCompletions(_context, _receiver) {
    // Host app should implement.
  }
}

class ManagedCompletionReceiver extends CompletionReceiver {
  constructor(manager, provider, generation) {
    super();
    this._manager = manager;
    this._provider = provider;
    this._generation = generation;
    this._cancelled = false;
  }

  cancel() {
    this._cancelled = true;
  }

  accept(result) {
    if (this._cancelled || this._generation !== this._manager._generation) {
      return false;
    }
    const normalized = result instanceof CompletionResult
      ? result
      : new CompletionResult(result?.items ?? [], result?.isIncomplete ?? false);
    this._manager._onProviderResult(this._provider, normalized, this._generation);
    return true;
  }

  get isCancelled() {
    return this._cancelled || this._generation !== this._manager._generation;
  }
}

export class CompletionProviderManager {
  constructor(options = {}) {
    this._providers = new Set();
    this._activeReceivers = new Map();
    this._generation = 0;
    this._mergedItems = [];

    this._buildContext = typeof options.buildContext === "function" ? options.buildContext : null;
    this._onItemsUpdated = typeof options.onItemsUpdated === "function" ? options.onItemsUpdated : null;
    this._onDismissed = typeof options.onDismissed === "function" ? options.onDismissed : null;

    this._debounceCharacterMs = Math.max(0, toInt(options.debounceCharacterMs, 50));
    this._debounceInvokedMs = Math.max(0, toInt(options.debounceInvokedMs, 0));

    this._lastTriggerKind = CompletionTriggerKind.INVOKED;
    this._lastTriggerChar = null;
    this._refreshTimer = 0;
  }

  setListener(listener = null) {
    this._onItemsUpdated = typeof listener?.onItemsUpdated === "function" ? listener.onItemsUpdated : null;
    this._onDismissed = typeof listener?.onDismissed === "function" ? listener.onDismissed : null;
  }

  addProvider(provider) {
    if (!provider) {
      return;
    }
    this._providers.add(provider);
  }

  removeProvider(provider) {
    if (!provider) {
      return;
    }
    this._providers.delete(provider);
    const receiver = this._activeReceivers.get(provider);
    if (receiver) {
      receiver.cancel();
      this._activeReceivers.delete(provider);
    }
  }

  isTriggerCharacter(ch) {
    const chText = String(ch ?? "");
    for (const provider of this._providers) {
      if (safeCall(() => provider.isTriggerCharacter(chText))) {
        return true;
      }
    }
    return false;
  }

  triggerCompletion(triggerKind = CompletionTriggerKind.INVOKED, triggerCharacter = null) {
    if (this._providers.size === 0) {
      return;
    }

    this._lastTriggerKind = toInt(triggerKind, CompletionTriggerKind.INVOKED);
    this._lastTriggerChar = triggerCharacter == null ? null : String(triggerCharacter);

    if (this._refreshTimer) {
      clearTimeout(this._refreshTimer);
      this._refreshTimer = 0;
    }

    const delay = this._lastTriggerKind === CompletionTriggerKind.INVOKED
      ? this._debounceInvokedMs
      : this._debounceCharacterMs;

    this._refreshTimer = setTimeout(() => {
      this._refreshTimer = 0;
      this._executeRefresh(this._lastTriggerKind, this._lastTriggerChar);
    }, Math.max(0, delay));
  }

  showItems(items) {
    if (this._refreshTimer) {
      clearTimeout(this._refreshTimer);
      this._refreshTimer = 0;
    }

    this._generation += 1;
    this._cancelAllReceivers();

    this._mergedItems = normalizeCompletionItems(items);
    if (this._mergedItems.length === 0) {
      this._emitDismiss();
      return;
    }

    this._emitItemsUpdated(this._mergedItems);
  }

  dismiss() {
    if (this._refreshTimer) {
      clearTimeout(this._refreshTimer);
      this._refreshTimer = 0;
    }

    this._generation += 1;
    this._cancelAllReceivers();
    this._mergedItems = [];
    this._emitDismiss();
  }

  _executeRefresh(triggerKind, triggerCharacter) {
    this._generation += 1;
    const generation = this._generation;

    this._cancelAllReceivers();
    this._mergedItems = [];

    const context = this._buildContext
      ? this._buildContext(triggerKind, triggerCharacter)
      : null;

    if (!context) {
      this.dismiss();
      return;
    }

    for (const provider of this._providers) {
      const receiver = new ManagedCompletionReceiver(this, provider, generation);
      this._activeReceivers.set(provider, receiver);
      try {
        provider.provideCompletions(context, receiver);
      } catch (error) {
        console.error("Completion provider error:", error);
      }
    }
  }

  _cancelAllReceivers() {
    this._activeReceivers.forEach((receiver) => {
      receiver.cancel();
    });
    this._activeReceivers.clear();
  }

  _onProviderResult(_provider, result, generation) {
    if (generation !== this._generation) {
      return;
    }

    this._mergedItems.push(...normalizeCompletionItems(result.items));
    this._mergedItems.sort((a, b) => {
      const keyA = a.sortKey || a.label;
      const keyB = b.sortKey || b.label;
      return keyA.localeCompare(keyB);
    });

    if (this._mergedItems.length === 0) {
      this._emitDismiss();
      return;
    }

    this._emitItemsUpdated(this._mergedItems);
  }

  _emitItemsUpdated(items) {
    if (this._onItemsUpdated) {
      this._onItemsUpdated(items.slice());
    }
  }

  _emitDismiss() {
    if (this._onDismissed) {
      this._onDismissed();
    }
  }
}
export const DecorationType = Object.freeze({
  SYNTAX_HIGHLIGHT: 1 << 0,
  SEMANTIC_HIGHLIGHT: 1 << 1,
  INLAY_HINT: 1 << 2,
  DIAGNOSTIC: 1 << 3,
  FOLD_REGION: 1 << 4,
  INDENT_GUIDE: 1 << 5,
  BRACKET_GUIDE: 1 << 6,
  FLOW_GUIDE: 1 << 7,
  SEPARATOR_GUIDE: 1 << 8,
  GUTTER_ICON: 1 << 9,
  PHANTOM_TEXT: 1 << 10,
});

export const DecorationApplyMode = Object.freeze({
  MERGE: 0,
  REPLACE_ALL: 1,
  REPLACE_RANGE: 2,
});

export const DecorationTextChangeMode = Object.freeze({
  INCREMENTAL: "incremental",
  FULL: "full",
  DISABLED: "disabled",
});

export const DecorationResultDispatchMode = Object.freeze({
  BOTH: "both",
  SYNC: "sync",
  ASYNC: "async",
});

export const DecorationProviderCallMode = Object.freeze({
  SYNC: "sync",
  ASYNC: "async",
});

export class DecorationContext {
  constructor({
    visibleStartLine = 0,
    visibleEndLine = -1,
    totalLineCount = 0,
    textChanges = [],
    languageConfiguration = null,
    editorMetadata = null,
  } = {}) {
    this.visibleStartLine = ensureLine(visibleStartLine);
    this.visibleEndLine = toInt(visibleEndLine, -1);
    this.totalLineCount = Math.max(0, toInt(totalLineCount, 0));
    this.textChanges = asArray(textChanges).map((change) => ({
      range: ensureRange(change.range),
      oldText: String(change.oldText ?? change.old_text ?? ""),
      newText: String(change.newText ?? change.new_text ?? ""),
    }));
    this.languageConfiguration = languageConfiguration;
    this.editorMetadata = editorMetadata;
  }
}

export class DecorationResult {
  constructor(init = {}) {
    this.syntaxSpans = init.syntaxSpans ?? null;
    this.semanticSpans = init.semanticSpans ?? null;
    this.inlayHints = init.inlayHints ?? null;
    this.diagnostics = init.diagnostics ?? null;
    this.indentGuides = init.indentGuides ?? null;
    this.bracketGuides = init.bracketGuides ?? null;
    this.flowGuides = init.flowGuides ?? null;
    this.separatorGuides = init.separatorGuides ?? null;
    this.foldRegions = init.foldRegions ?? null;
    this.gutterIcons = init.gutterIcons ?? null;
    this.phantomTexts = init.phantomTexts ?? null;

    this.syntaxSpansMode = toInt(init.syntaxSpansMode, DecorationApplyMode.MERGE);
    this.semanticSpansMode = toInt(init.semanticSpansMode, DecorationApplyMode.MERGE);
    this.inlayHintsMode = toInt(init.inlayHintsMode, DecorationApplyMode.MERGE);
    this.diagnosticsMode = toInt(init.diagnosticsMode, DecorationApplyMode.MERGE);
    this.indentGuidesMode = toInt(init.indentGuidesMode, DecorationApplyMode.MERGE);
    this.bracketGuidesMode = toInt(init.bracketGuidesMode, DecorationApplyMode.MERGE);
    this.flowGuidesMode = toInt(init.flowGuidesMode, DecorationApplyMode.MERGE);
    this.separatorGuidesMode = toInt(init.separatorGuidesMode, DecorationApplyMode.MERGE);
    this.foldRegionsMode = toInt(init.foldRegionsMode, DecorationApplyMode.MERGE);
    this.gutterIconsMode = toInt(init.gutterIconsMode, DecorationApplyMode.MERGE);
    this.phantomTextsMode = toInt(init.phantomTextsMode, DecorationApplyMode.MERGE);
  }
}

export class DecorationReceiver {
  accept(_result) {
    throw new Error("DecorationReceiver.accept must be implemented");
  }

  get isCancelled() {
    return true;
  }
}

export class DecorationProvider {
  getCapabilities() {
    return DecorationType.SYNTAX_HIGHLIGHT;
  }

  provideDecorations(_context, _receiver) {
    // Host app should implement.
  }
}

function splitSourceLines(text) {
  const lines = String(text ?? "").split("\n");
  if (lines.length === 0) {
    return [""];
  }
  return lines;
}

function safeDeleteNativeHandle(handle) {
  if (handle && typeof handle.delete === "function") {
    handle.delete();
  }
}

function iterateNativeList(list, fn) {
  if (!list || typeof fn !== "function") {
    return;
  }
  if (Array.isArray(list)) {
    list.forEach((item, index) => fn(item, index));
    return;
  }
  if (typeof list.size === "function" && typeof list.get === "function") {
    const size = Math.max(0, toInt(list.size(), 0));
    for (let i = 0; i < size; i += 1) {
      fn(list.get(i), i);
    }
  }
}

function extractSingleLineStyleSpan(token) {
  if (!token || !token.range || !token.range.start || !token.range.end) {
    return null;
  }
  const styleId = toInt(token.styleId ?? token.style_id, 0);
  if (styleId <= 0) {
    return null;
  }
  const startLine = toInt(token.range.start.line, 0);
  const endLine = toInt(token.range.end.line, startLine);
  const startColumn = Math.max(0, toInt(token.range.start.column, 0));
  const endColumn = Math.max(0, toInt(token.range.end.column, startColumn));
  if (startLine < 0 || startLine !== endLine || endColumn <= startColumn) {
    return null;
  }
  return {
    line: startLine,
    column: startColumn,
    length: endColumn - startColumn,
    styleId,
  };
}

function withSweetLineTextRange(sweetLine, range, fn) {
  const slRange = new sweetLine.TextRange();
  const start = new sweetLine.TextPosition();
  const end = new sweetLine.TextPosition();

  start.line = Math.max(0, toInt(range?.start?.line, 0));
  start.column = Math.max(0, toInt(range?.start?.column, 0));
  start.index = 0;

  end.line = Math.max(0, toInt(range?.end?.line, start.line));
  end.column = Math.max(0, toInt(range?.end?.column, start.column));
  end.index = 0;

  slRange.start = start;
  slRange.end = end;

  try {
    return fn(slRange);
  } finally {
    safeDeleteNativeHandle(start);
    safeDeleteNativeHandle(end);
    safeDeleteNativeHandle(slRange);
  }
}

export class SweetLineIncrementalDecorationProvider extends DecorationProvider {
  constructor(options = {}) {
    super();
    this._sweetLine = options.sweetLine ?? options.runtime?.sweetLine ?? null;
    this._highlightEngine = options.highlightEngine ?? options.runtime?.engine ?? null;

    this._defaultFileName = String(options.defaultFileName ?? "example.cpp");
    this._sourceFileName = this._defaultFileName;
    this._sourceText = "";
    this._sourceLines = [""];

    this._analysisDocument = null;
    this._documentAnalyzer = null;
    this._cacheHighlight = null;
    this._analysisReady = false;
    this._analyzedFileName = "";

    const maxRenderLinesValue = Number(options.maxRenderLinesPerPass);
    this._maxRenderLinesPerPass = Number.isFinite(maxRenderLinesValue)
      ? Math.max(1, toInt(maxRenderLinesValue, 1))
      : Number.POSITIVE_INFINITY;
    this._syntaxSpansMode = toInt(options.syntaxSpansMode, DecorationApplyMode.MERGE);
    this._capabilities = toInt(
      options.capabilities,
      DecorationType.SYNTAX_HIGHLIGHT,
    ) | DecorationType.SYNTAX_HIGHLIGHT;

    this._resolveFileName = typeof options.resolveFileName === "function"
      ? options.resolveFileName
      : null;
    this._buildAnalysisUri = typeof options.buildAnalysisUri === "function"
      ? options.buildAnalysisUri
      : (fileName) => `file:///${String(fileName || this._defaultFileName)}`;
    this._decorate = typeof options.decorate === "function"
      ? options.decorate
      : null;
    this._getDocumentText = typeof options.getDocumentText === "function"
      ? options.getDocumentText
      : null;
    this._syncSourceOnTextChange = options.syncSourceOnTextChange !== false;

    this.setDocumentSource(
      options.fileName ?? options.sourceFileName ?? this._defaultFileName,
      options.text ?? options.sourceText ?? "",
    );
  }

  getCapabilities() {
    return this._capabilities;
  }

  dispose() {
    this._disposeAnalyzer();
  }

  getLineCount() {
    return Math.max(0, this._sourceLines.length);
  }

  setDocumentSource(fileName, text) {
    this._sourceFileName = String(fileName || this._defaultFileName);
    this._setSourceText(text);
    this._disposeAnalyzer();
  }

  provideDecorations(context, receiver) {
    if (!this._sweetLine || !this._highlightEngine || !receiver) {
      return;
    }

    const changes = asArray(context?.textChanges).map((change) => ({
      range: ensureRange(change?.range),
      oldText: String(change?.oldText ?? change?.old_text ?? ""),
      newText: String(change?.newText ?? change?.new_text ?? ""),
    }));

    const resolvedFileName = this._resolveContextFileName(context);
    const fileChanged = resolvedFileName !== this._analyzedFileName;
    this._sourceFileName = resolvedFileName;

    if ((fileChanged || !this._documentAnalyzer || !this._analysisReady) && this._getDocumentText) {
      this._syncSourceFromDocument();
    } else if (changes.length > 0) {
      this._applyTextChanges(changes);
    }

    if (fileChanged || !this._documentAnalyzer || !this._analysisReady) {
      if (!this._tryRebuildAnalyzer(resolvedFileName)) {
        return;
      }
    } else if (changes.length > 0) {
      if (!this._tryAnalyzeIncremental(changes, resolvedFileName)) {
        return;
      }
    }

    const totalLineCount = Math.max(
      this._sourceLines.length,
      Math.max(0, toInt(context?.totalLineCount, this._sourceLines.length)),
    );

    const visibleStartLine = context?.visibleStartLine ?? 0;
    const originalVisibleEndLine = context?.visibleEndLine ?? (visibleStartLine + 120);
    const visibleEndLine = Math.floor((originalVisibleEndLine - visibleStartLine) * 1.75) + visibleStartLine;
    
    const visibleRange = clampVisibleLineRange(
      visibleStartLine,
      visibleEndLine,
      totalLineCount,
      this._maxRenderLinesPerPass,
    );
    if (visibleRange.end < visibleRange.start) {
      return;
    }

    const syntaxSpans = this._collectSyntaxSpans(visibleRange);
    receiver.accept(new DecorationResult({
      syntaxSpans,
      syntaxSpansMode: this._syntaxSpansMode,
    }));

    if (!this._decorate) {
      return;
    }

    const extraPatch = safeCall(() => this._decorate({
      context,
      receiver,
      fileName: resolvedFileName,
      visibleRange,
      sourceText: this._sourceText,
      sourceLines: this._sourceLines,
      totalLineCount,
      cacheHighlight: this._cacheHighlight,
    }));
    if (!extraPatch) {
      return;
    }

    receiver.accept(
      extraPatch instanceof DecorationResult
        ? extraPatch
        : new DecorationResult(extraPatch),
    );
  }

  _setSourceText(text) {
    this._sourceText = normalizeNewlines(text);
    this._sourceLines = splitSourceLines(this._sourceText);
  }

  _resolveContextFileName(context) {
    let fileName = this._sourceFileName || this._defaultFileName;
    const metadataFileName = context?.editorMetadata?.fileName;
    if (metadataFileName) {
      fileName = String(metadataFileName);
    }
    if (this._resolveFileName) {
      const resolved = safeCall(() => this._resolveFileName(context, fileName));
      if (resolved != null && resolved !== "") {
        fileName = String(resolved);
      }
    }
    return fileName || this._defaultFileName;
  }

  _syncSourceFromDocument() {
    if (!this._getDocumentText) {
      return false;
    }
    const sourceText = safeCall(() => this._getDocumentText());
    if (typeof sourceText !== "string") {
      return false;
    }
    const normalized = normalizeNewlines(sourceText);
    if (normalized === this._sourceText) {
      return false;
    }
    this._setSourceText(normalized);
    return true;
  }

  _applyTextChanges(changes) {
    if (!changes || changes.length === 0) {
      return;
    }
    this._sourceText = applyTextChangesToText(this._sourceText, changes);
    this._sourceLines = splitSourceLines(this._sourceText);
  }

  _tryRebuildAnalyzer(fileName) {
    try {
      this._rebuildAnalyzer(fileName);
      return true;
    } catch (error) {
      console.error("SweetLine full analyze failed:", error);
      this._disposeAnalyzer();
      return false;
    }
  }

  _tryAnalyzeIncremental(changes, fileName) {
    try {
      const hasStructuralChange = changes.some((change) => isLineStructureChange(change));
      if (hasStructuralChange) {
        this._rebuildAnalyzer(fileName);
        return true;
      }

      changes.forEach((change) => {
        if (!change?.range) {
          return;
        }
        const newText = normalizeNewlines(change.newText ?? "");
        withSweetLineTextRange(this._sweetLine, change.range, (slRange) => {
          this._cacheHighlight = this._documentAnalyzer.analyzeIncremental(slRange, newText);
        });
      });

      const shouldResyncText = changes.some((change) => {
        const range = change?.range;
        if (!range || !range.start || !range.end) {
          return false;
        }
        if (range.start.line !== range.end.line) {
          return true;
        }
        return hasLineBreak(change.oldText) || hasLineBreak(change.newText);
      });

      if (this._syncSourceOnTextChange && this._getDocumentText && shouldResyncText) {
        const beforeSync = this._sourceText;
        const synced = this._syncSourceFromDocument();
        if (synced && this._sourceText !== beforeSync) {
          this._rebuildAnalyzer(fileName);
        }
      }
      return true;
    } catch (error) {
      console.error("SweetLine incremental analyze failed:", error);
      if (!this._tryRebuildAnalyzer(fileName)) {
        return false;
      }
      return true;
    }
  }

  _disposeAnalyzer() {
    safeDeleteNativeHandle(this._cacheHighlight);
    safeDeleteNativeHandle(this._documentAnalyzer);
    safeDeleteNativeHandle(this._analysisDocument);
    this._cacheHighlight = null;
    this._documentAnalyzer = null;
    this._analysisDocument = null;
    this._analysisReady = false;
    this._analyzedFileName = "";
  }

  _rebuildAnalyzer(fileName) {
    this._disposeAnalyzer();
    this._analysisDocument = new this._sweetLine.Document(
      this._buildAnalysisUri(fileName),
      this._sourceText,
    );
    this._documentAnalyzer = this._highlightEngine.loadDocument(this._analysisDocument);
    this._cacheHighlight = this._documentAnalyzer.analyze();
    this._analysisReady = true;
    this._analyzedFileName = fileName;
  }

  _collectSyntaxSpans(visibleRange) {
    const out = new Map();
    const startLine = Math.max(0, toInt(visibleRange?.start, 0));
    const endLine = Math.max(startLine - 1, toInt(visibleRange?.end, startLine - 1));
    if (endLine < startLine) {
      return out;
    }

    const lineHighlights = this._cacheHighlight?.lines;
    if (!lineHighlights) {
      return out;
    }

    const getLineHighlight = (line) => {
      if (typeof lineHighlights.size === "function" && typeof lineHighlights.get === "function") {
        const total = Math.max(0, toInt(lineHighlights.size(), 0));
        if (line < 0 || line >= total) {
          return null;
        }
        return lineHighlights.get(line);
      }
      if (Array.isArray(lineHighlights)) {
        return lineHighlights[line] ?? null;
      }
      return null;
    };

    for (let line = startLine; line <= endLine; line += 1) {
      const lineHighlight = getLineHighlight(line);
      if (!lineHighlight) {
        continue;
      }
      iterateNativeList(lineHighlight.spans, (token) => {
        const span = extractSingleLineStyleSpan(token);
        if (!span || span.line < startLine || span.line > endLine) {
          return;
        }
        let lineSpans = out.get(span.line);
        if (!lineSpans) {
          lineSpans = [];
          out.set(span.line, lineSpans);
        }
        lineSpans.push({
          column: span.column,
          length: span.length,
          styleId: span.styleId,
        });
      });
    }

    out.forEach((spans) => {
      spans.sort((a, b) => a.column - b.column);
    });
    return out;
  }
}

class ManagedDecorationReceiver extends DecorationReceiver {
  constructor(manager, provider, generation) {
    super();
    this._manager = manager;
    this._provider = provider;
    this._generation = generation;
    this._cancelled = false;
    this._inSyncPhase = true;
  }

  cancel() {
    this._cancelled = true;
  }

  markAsyncPhase() {
    this._inSyncPhase = false;
  }

  accept(result) {
    if (this._cancelled || this._generation !== this._manager._generation) {
      return false;
    }

    const dispatchMode = this._manager._resultDispatchMode;
    if (dispatchMode === DecorationResultDispatchMode.SYNC && !this._inSyncPhase) {
      return false;
    }
    if (dispatchMode === DecorationResultDispatchMode.ASYNC && this._inSyncPhase) {
      return false;
    }

    const patch = result instanceof DecorationResult ? result : new DecorationResult(result || {});
    this._manager._onProviderPatch(this._provider, patch, this._generation);
    return true;
  }

  get isCancelled() {
    return this._cancelled || this._generation !== this._manager._generation;
  }
}

function cloneDecorationResult(result) {
  return {
    syntaxSpans: cloneLineMap(result.syntaxSpans),
    semanticSpans: cloneLineMap(result.semanticSpans),
    inlayHints: cloneLineMap(result.inlayHints),
    diagnostics: cloneLineMap(result.diagnostics),
    indentGuides: cloneList(result.indentGuides),
    bracketGuides: cloneList(result.bracketGuides),
    flowGuides: cloneList(result.flowGuides),
    separatorGuides: cloneList(result.separatorGuides),
    foldRegions: cloneList(result.foldRegions),
    gutterIcons: cloneLineMap(result.gutterIcons),
    phantomTexts: cloneLineMap(result.phantomTexts),

    syntaxSpansMode: toInt(result.syntaxSpansMode, DecorationApplyMode.MERGE),
    semanticSpansMode: toInt(result.semanticSpansMode, DecorationApplyMode.MERGE),
    inlayHintsMode: toInt(result.inlayHintsMode, DecorationApplyMode.MERGE),
    diagnosticsMode: toInt(result.diagnosticsMode, DecorationApplyMode.MERGE),
    indentGuidesMode: toInt(result.indentGuidesMode, DecorationApplyMode.MERGE),
    bracketGuidesMode: toInt(result.bracketGuidesMode, DecorationApplyMode.MERGE),
    flowGuidesMode: toInt(result.flowGuidesMode, DecorationApplyMode.MERGE),
    separatorGuidesMode: toInt(result.separatorGuidesMode, DecorationApplyMode.MERGE),
    foldRegionsMode: toInt(result.foldRegionsMode, DecorationApplyMode.MERGE),
    gutterIconsMode: toInt(result.gutterIconsMode, DecorationApplyMode.MERGE),
    phantomTextsMode: toInt(result.phantomTextsMode, DecorationApplyMode.MERGE),
  };
}

function mergeDecorationPatch(target, patch) {
  const fields = [
    ["syntaxSpans", "syntaxSpansMode"],
    ["semanticSpans", "semanticSpansMode"],
    ["inlayHints", "inlayHintsMode"],
    ["diagnostics", "diagnosticsMode"],
    ["indentGuides", "indentGuidesMode"],
    ["bracketGuides", "bracketGuidesMode"],
    ["flowGuides", "flowGuidesMode"],
    ["separatorGuides", "separatorGuidesMode"],
    ["foldRegions", "foldRegionsMode"],
    ["gutterIcons", "gutterIconsMode"],
    ["phantomTexts", "phantomTextsMode"],
  ];

  fields.forEach(([dataKey, modeKey]) => {
    if (patch[dataKey] != null) {
      target[dataKey] = patch[dataKey];
      target[modeKey] = patch[modeKey];
      return;
    }

    if (patch[modeKey] !== DecorationApplyMode.MERGE) {
      target[dataKey] = null;
      target[modeKey] = patch[modeKey];
    }
  });
}

function normalizeDecorationTextChangeMode(mode) {
  const value = String(mode ?? "").toLowerCase();
  if (value === DecorationTextChangeMode.FULL) {
    return DecorationTextChangeMode.FULL;
  }
  if (value === DecorationTextChangeMode.DISABLED) {
    return DecorationTextChangeMode.DISABLED;
  }
  return DecorationTextChangeMode.INCREMENTAL;
}

function normalizeDecorationResultDispatchMode(mode) {
  const value = String(mode ?? "").toLowerCase();
  if (value === DecorationResultDispatchMode.SYNC) {
    return DecorationResultDispatchMode.SYNC;
  }
  if (value === DecorationResultDispatchMode.ASYNC) {
    return DecorationResultDispatchMode.ASYNC;
  }
  return DecorationResultDispatchMode.BOTH;
}

function normalizeDecorationProviderCallMode(mode) {
  const value = String(mode ?? "").toLowerCase();
  if (value === DecorationProviderCallMode.ASYNC) {
    return DecorationProviderCallMode.ASYNC;
  }
  return DecorationProviderCallMode.SYNC;
}

export class DecorationProviderManager {
  constructor(options = {}) {
    this._providers = new Set();
    this._providerStates = new Map();

    this._buildContext = typeof options.buildContext === "function" ? options.buildContext : null;
    this._getVisibleLineRange = typeof options.getVisibleLineRange === "function" ? options.getVisibleLineRange : null;
    this._ensureVisibleLineRange = typeof options.ensureVisibleLineRange === "function"
      ? options.ensureVisibleLineRange
      : null;
    this._getTotalLineCount = typeof options.getTotalLineCount === "function" ? options.getTotalLineCount : null;
    this._getLanguageConfiguration = typeof options.getLanguageConfiguration === "function"
      ? options.getLanguageConfiguration
      : null;
    this._getMetadata = typeof options.getMetadata === "function" ? options.getMetadata : null;
    this._onApplyMerged = typeof options.onApplyMerged === "function" ? options.onApplyMerged : null;

    this._refreshTimer = 0;
    this._scrollRefreshTimer = 0;
    this._applyTimer = 0;

    this._pendingTextChanges = [];
    this._applyScheduled = false;
    this._generation = 0;
    this._lastVisibleStartLine = 0;
    this._lastVisibleEndLine = -1;
    this._lastScrollRefreshTickMs = 0;

    this._scrollRefreshMinIntervalMs = 50;
    this._overscanViewportMultiplier = 0.5;
    this._textChangeMode = DecorationTextChangeMode.INCREMENTAL;
    this._resultDispatchMode = DecorationResultDispatchMode.BOTH;
    this._providerCallMode = DecorationProviderCallMode.SYNC;
    this._applySynchronously = false;

    this.setOptions(options);
  }

  setOptions(options = {}) {
    if (!options || typeof options !== "object") {
      return;
    }

    if ("scrollRefreshMinIntervalMs" in options) {
      this._scrollRefreshMinIntervalMs = Math.max(0, toInt(options.scrollRefreshMinIntervalMs, 50));
    }
    if ("overscanViewportMultiplier" in options) {
      this._overscanViewportMultiplier = Math.max(0, Number(options.overscanViewportMultiplier ?? 0.5));
    }
    if ("textChangeMode" in options) {
      this._textChangeMode = normalizeDecorationTextChangeMode(options.textChangeMode);
    }
    if ("resultDispatchMode" in options) {
      this._resultDispatchMode = normalizeDecorationResultDispatchMode(options.resultDispatchMode);
    }
    if ("providerCallMode" in options) {
      this._providerCallMode = normalizeDecorationProviderCallMode(options.providerCallMode);
    }
    if ("applySynchronously" in options) {
      this._applySynchronously = Boolean(options.applySynchronously);
    }
  }

  getOptions() {
    return {
      scrollRefreshMinIntervalMs: this._scrollRefreshMinIntervalMs,
      overscanViewportMultiplier: this._overscanViewportMultiplier,
      textChangeMode: this._textChangeMode,
      resultDispatchMode: this._resultDispatchMode,
      providerCallMode: this._providerCallMode,
      applySynchronously: this._applySynchronously,
    };
  }

  addProvider(provider) {
    if (!provider) {
      return;
    }
    this._providers.add(provider);
    if (!this._providerStates.has(provider)) {
      this._providerStates.set(provider, {
        snapshot: null,
        activeReceiver: null,
      });
    }
    this.requestRefresh();
  }

  removeProvider(provider) {
    if (!provider) {
      return;
    }

    this._providers.delete(provider);
    const state = this._providerStates.get(provider);
    if (state?.activeReceiver) {
      state.activeReceiver.cancel();
    }
    this._providerStates.delete(provider);

    this._scheduleApply();
  }

  requestRefresh() {
    this._scheduleRefresh(0, null);
  }

  onDocumentLoaded() {
    this._scheduleRefresh(0, null);
  }

  onTextChanged(changes) {
    if (this._textChangeMode === DecorationTextChangeMode.DISABLED) {
      return;
    }
    this._scheduleRefresh(50, asArray(changes));
  }

  onScrollChanged() {
    const now = Date.now();
    const elapsed = now - this._lastScrollRefreshTickMs;
    const delay = elapsed >= this._scrollRefreshMinIntervalMs
      ? 0
      : (this._scrollRefreshMinIntervalMs - elapsed);

    if (this._scrollRefreshTimer) {
      return;
    }

    this._scrollRefreshTimer = setTimeout(() => {
      this._scrollRefreshTimer = 0;
      if (this._refreshTimer) {
        clearTimeout(this._refreshTimer);
        this._refreshTimer = 0;
      }
      this._doRefresh();
      this._lastScrollRefreshTickMs = Date.now();
    }, Math.max(0, delay));
  }

  _scheduleRefresh(delayMs, changes) {
    let effectiveDelayMs = Math.max(0, toInt(delayMs, 0));
    if (changes && changes.length > 0) {
      const normalizedChanges = [];
      changes.forEach((change) => {
        const normalizedChange = {
          range: ensureRange(change.range),
          oldText: String(change.oldText ?? change.old_text ?? ""),
          newText: String(change.newText ?? change.new_text ?? ""),
        };
        if (isLineStructureChange(normalizedChange)) {
          effectiveDelayMs = 0;
        }
        normalizedChanges.push(normalizedChange);
      });
      if (normalizedChanges.length > 0) {
        this._pendingTextChanges.push(...normalizedChanges);
      }
    }

    if (this._scrollRefreshTimer) {
      clearTimeout(this._scrollRefreshTimer);
      this._scrollRefreshTimer = 0;
    }

    if (this._refreshTimer) {
      clearTimeout(this._refreshTimer);
      this._refreshTimer = 0;
    }

    this._refreshTimer = setTimeout(() => {
      this._refreshTimer = 0;
      this._doRefresh();
    }, effectiveDelayMs);
  }

  _doRefresh() {
    this._generation += 1;
    const generation = this._generation;

    let visibleRange = this._resolveVisibleRange();
    if (visibleRange.end < visibleRange.start && this._ensureVisibleLineRange) {
      safeCall(() => this._ensureVisibleLineRange());
      visibleRange = this._resolveVisibleRange();
    }
    this._lastVisibleStartLine = visibleRange.start;
    this._lastVisibleEndLine = visibleRange.end;

    const totalLineCount = Math.max(0, toInt(this._getTotalLineCount?.(), 0));
    const pendingChanges = this._pendingTextChanges.slice();
    this._pendingTextChanges = [];
    const contextChanges = this._textChangeMode === DecorationTextChangeMode.FULL
      ? []
      : pendingChanges;

    const contextRange = this._resolveContextRange(visibleRange, totalLineCount);
    const context = this._buildContext
      ? this._buildContext({
          visibleStartLine: contextRange.start,
          visibleEndLine: contextRange.end,
          totalLineCount,
          textChanges: contextChanges,
          languageConfiguration: this._getLanguageConfiguration?.() ?? null,
          editorMetadata: this._getMetadata?.() ?? null,
        })
      : new DecorationContext({
          visibleStartLine: contextRange.start,
          visibleEndLine: contextRange.end,
          totalLineCount,
          textChanges: contextChanges,
          languageConfiguration: this._getLanguageConfiguration?.() ?? null,
          editorMetadata: this._getMetadata?.() ?? null,
        });

    for (const provider of this._providers) {
      let state = this._providerStates.get(provider);
      if (!state) {
        state = { snapshot: null, activeReceiver: null };
        this._providerStates.set(provider, state);
      }

      if (state.activeReceiver) {
        state.activeReceiver.cancel();
      }

      const receiver = new ManagedDecorationReceiver(this, provider, generation);
      state.activeReceiver = receiver;
      this._invokeProvider(provider, context, receiver);
    }
  }

  _invokeProvider(provider, context, receiver) {
    const run = () => {
      if (receiver.isCancelled) {
        return;
      }
      try {
        provider.provideDecorations(context, receiver);
      } catch (error) {
        console.error("Decoration provider error:", error);
      } finally {
        receiver.markAsyncPhase();
      }
    };

    if (this._providerCallMode === DecorationProviderCallMode.ASYNC) {
      setTimeout(run, 0);
      return;
    }
    run();
  }

  _resolveVisibleRange() {
    const range = this._getVisibleLineRange ? this._getVisibleLineRange() : null;
    const start = ensureLine(range?.start ?? range?.[0] ?? 0);
    const end = toInt(range?.end ?? range?.[1], -1);
    return { start, end };
  }

  _resolveContextRange(visibleRange, totalLineCount) {
    if (totalLineCount <= 0 || visibleRange.end < visibleRange.start) {
      return { start: visibleRange.start, end: visibleRange.end };
    }

    const viewportLineCount = visibleRange.end - visibleRange.start + 1;
    const overscan = Math.max(0, Math.ceil(viewportLineCount * this._overscanViewportMultiplier));

    return {
      start: Math.max(0, visibleRange.start - overscan),
      end: Math.min(totalLineCount - 1, visibleRange.end + overscan),
    };
  }

  _onProviderPatch(provider, patch, generation) {
    if (generation !== this._generation) {
      return;
    }

    const normalizedPatch = cloneDecorationResult(patch);
    let state = this._providerStates.get(provider);
    if (!state) {
      state = { snapshot: null, activeReceiver: null };
      this._providerStates.set(provider, state);
    }

    if (!state.snapshot) {
      state.snapshot = cloneDecorationResult(new DecorationResult());
    }

    mergeDecorationPatch(state.snapshot, normalizedPatch);
    this._scheduleApply();
  }

  _scheduleApply() {
    if (this._applyScheduled) {
      return;
    }

    this._applyScheduled = true;
    if (this._applySynchronously) {
      this._applyScheduled = false;
      this._applyMerged();
      return;
    }

    this._applyTimer = setTimeout(() => {
      this._applyTimer = 0;
      this._applyScheduled = false;
      this._applyMerged();
    }, 0);
  }

  _applyMerged() {
    const merged = {
      syntaxSpans: new Map(),
      semanticSpans: new Map(),
      inlayHints: new Map(),
      diagnostics: new Map(),
      indentGuides: null,
      bracketGuides: null,
      flowGuides: null,
      separatorGuides: null,
      foldRegions: [],
      gutterIcons: new Map(),
      phantomTexts: new Map(),

      syntaxSpansMode: DecorationApplyMode.MERGE,
      semanticSpansMode: DecorationApplyMode.MERGE,
      inlayHintsMode: DecorationApplyMode.MERGE,
      diagnosticsMode: DecorationApplyMode.MERGE,
      indentGuidesMode: DecorationApplyMode.MERGE,
      bracketGuidesMode: DecorationApplyMode.MERGE,
      flowGuidesMode: DecorationApplyMode.MERGE,
      separatorGuidesMode: DecorationApplyMode.MERGE,
      foldRegionsMode: DecorationApplyMode.MERGE,
      gutterIconsMode: DecorationApplyMode.MERGE,
      phantomTextsMode: DecorationApplyMode.MERGE,
    };

    for (const provider of this._providers) {
      const state = this._providerStates.get(provider);
      if (!state?.snapshot) {
        continue;
      }

      const snapshot = state.snapshot;

      merged.syntaxSpansMode = mergeMode(merged.syntaxSpansMode, snapshot.syntaxSpansMode);
      appendLineMap(merged.syntaxSpans, snapshot.syntaxSpans);

      merged.semanticSpansMode = mergeMode(merged.semanticSpansMode, snapshot.semanticSpansMode);
      appendLineMap(merged.semanticSpans, snapshot.semanticSpans);

      merged.inlayHintsMode = mergeMode(merged.inlayHintsMode, snapshot.inlayHintsMode);
      appendLineMap(merged.inlayHints, snapshot.inlayHints);

      merged.diagnosticsMode = mergeMode(merged.diagnosticsMode, snapshot.diagnosticsMode);
      appendLineMap(merged.diagnostics, snapshot.diagnostics);

      merged.gutterIconsMode = mergeMode(merged.gutterIconsMode, snapshot.gutterIconsMode);
      appendLineMap(merged.gutterIcons, snapshot.gutterIcons);

      merged.phantomTextsMode = mergeMode(merged.phantomTextsMode, snapshot.phantomTextsMode);
      appendLineMap(merged.phantomTexts, snapshot.phantomTexts);

      merged.indentGuidesMode = mergeMode(merged.indentGuidesMode, snapshot.indentGuidesMode);
      if (snapshot.indentGuides) {
        merged.indentGuides = cloneList(snapshot.indentGuides);
      }

      merged.bracketGuidesMode = mergeMode(merged.bracketGuidesMode, snapshot.bracketGuidesMode);
      if (snapshot.bracketGuides) {
        merged.bracketGuides = cloneList(snapshot.bracketGuides);
      }

      merged.flowGuidesMode = mergeMode(merged.flowGuidesMode, snapshot.flowGuidesMode);
      if (snapshot.flowGuides) {
        merged.flowGuides = cloneList(snapshot.flowGuides);
      }

      merged.separatorGuidesMode = mergeMode(merged.separatorGuidesMode, snapshot.separatorGuidesMode);
      if (snapshot.separatorGuides) {
        merged.separatorGuides = cloneList(snapshot.separatorGuides);
      }

      merged.foldRegionsMode = mergeMode(merged.foldRegionsMode, snapshot.foldRegionsMode);
      if (snapshot.foldRegions) {
        merged.foldRegions.push(...cloneList(snapshot.foldRegions));
      }
    }

    if (this._onApplyMerged) {
      this._onApplyMerged(merged, {
        startLine: this._lastVisibleStartLine,
        endLine: this._lastVisibleEndLine,
      });
    }
  }
}
