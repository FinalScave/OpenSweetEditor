import {
  DocumentFactory,
  WebEditorCore,
  CompletionItem,
  CompletionContext,
  CompletionTriggerKind,
  CompletionProviderManager,
  DecorationContext,
  DecorationApplyMode,
  DecorationProviderManager,
  SweetLineIncrementalDecorationProvider,
} from "./editor-core.js";

const FALLBACK_EVENT_TYPE = {
  TOUCH_DOWN: 1,
  TOUCH_POINTER_DOWN: 2,
  TOUCH_MOVE: 3,
  TOUCH_POINTER_UP: 4,
  TOUCH_UP: 5,
  TOUCH_CANCEL: 6,
  MOUSE_DOWN: 7,
  MOUSE_MOVE: 8,
  MOUSE_UP: 9,
  MOUSE_WHEEL: 10,
  MOUSE_RIGHT_DOWN: 11,
};

const FALLBACK_GESTURE_TYPE = {
  TAP: 1,
  DOUBLE_TAP: 2,
  LONG_PRESS: 3,
  SCALE: 4,
  SCROLL: 5,
  FAST_SCROLL: 6,
  DRAG_SELECT: 7,
  CONTEXT_MENU: 8,
};

const FALLBACK_KEY_CODE = {
  BACKSPACE: 8,
  TAB: 9,
  ENTER: 13,
  ESCAPE: 27,
  DELETE_KEY: 46,
  LEFT: 37,
  UP: 38,
  RIGHT: 39,
  DOWN: 40,
  HOME: 36,
  END: 35,
  PAGE_UP: 33,
  PAGE_DOWN: 34,
  A: 65,
  C: 67,
  V: 86,
  X: 88,
  Z: 90,
  Y: 89,
  K: 75,
};

const FALLBACK_MODIFIER = {
  SHIFT: 1,
  CTRL: 2,
  ALT: 4,
  META: 8,
};

const FALLBACK_SPAN_LAYER = {
  SYNTAX: 0,
  SEMANTIC: 1,
};

const FALLBACK_HIT_TARGET_TYPE = {
  NONE: 0,
  INLAY_HINT_TEXT: 1,
  INLAY_HINT_ICON: 2,
  GUTTER_ICON: 3,
  FOLD_PLACEHOLDER: 4,
  FOLD_GUTTER: 5,
  INLAY_HINT_COLOR: 6,
};

function resolveEnum(moduleObj, enumName, fallback) {
  const enumObj = moduleObj && moduleObj[enumName];
  if (!enumObj || typeof enumObj !== "object") {
    return fallback;
  }
  const resolved = { ...fallback };
  Object.keys(fallback).forEach((key) => {
    if (!(key in enumObj)) return;
    const value = toFiniteNumber(enumObj[key]);
    if (value !== null) {
      resolved[key] = value;
    }
  });
  return resolved;
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

function cloneTheme(theme) {
  return { ...theme };
}

function forVector(vec, fn) {
  if (!vec || typeof vec.size !== "function") return;
  const size = vec.size();
  for (let i = 0; i < size; i += 1) {
    fn(vec.get(i), i);
  }
}

const CONTEXT_MENU_I18N = {
  en: {
    undo: "Undo",
    redo: "Redo",
    cut: "Cut",
    copy: "Copy",
    paste: "Paste",
    selectAll: "Select All",
  },
  zh: {
    undo: "撤销",
    redo: "重做",
    cut: "剪切",
    copy: "复制",
    paste: "粘贴",
    selectAll: "全选",
  },
};

function resolveLocale(locale) {
  const value = String(locale || "").toLowerCase();
  return value.startsWith("zh") ? "zh" : "en";
}

const DEFAULT_THEME = {
  background: "#1e1e1e",
  text: "#d4d4d4",
  lineNumber: "#858585",
  splitLine: "#333333",
  currentLine: "rgba(255,255,255,0.06)",
  selection: "rgba(90,140,255,0.30)",
  cursor: "#ffffff",
  inlayHintBg: "rgba(80,80,80,0.85)",
  foldPlaceholderBg: "rgba(70,70,70,0.9)",
  foldPlaceholderText: "#cfcfcf",
  phantomText: "rgba(180,180,180,0.75)",
  gutterIconFallback: "rgba(255,255,255,0.68)",
};

export const EditorEventType = Object.freeze({
  TEXT_CHANGED: "TextChanged",
  CURSOR_CHANGED: "CursorChanged",
  SELECTION_CHANGED: "SelectionChanged",
  SCROLL_CHANGED: "ScrollChanged",
  SCALE_CHANGED: "ScaleChanged",
  LONG_PRESS: "LongPress",
  DOUBLE_TAP: "DoubleTap",
  CONTEXT_MENU: "ContextMenu",
  INLAY_HINT_CLICK: "InlayHintClick",
  GUTTER_ICON_CLICK: "GutterIconClick",
  FOLD_TOGGLE: "FoldToggle",
  DOCUMENT_LOADED: "DocumentLoaded",
});

const TextChangeAction = Object.freeze({
  INSERT: "Insert",
  UNDO: "Undo",
  REDO: "Redo",
  KEY: "Key",
  COMPOSITION: "Composition",
});

function clonePosition(position) {
  if (!position) {
    return null;
  }
  return {
    line: toInt(position.line, 0),
    column: toInt(position.column, 0),
  };
}

function cloneRange(range) {
  if (!range || !range.start || !range.end) {
    return null;
  }
  return {
    start: clonePosition(range.start),
    end: clonePosition(range.end),
  };
}

function equalPosition(a, b) {
  if (!a && !b) return true;
  if (!a || !b) return false;
  return toInt(a.line, -1) === toInt(b.line, -1)
    && toInt(a.column, -1) === toInt(b.column, -1);
}

function equalRange(a, b) {
  if (!a && !b) return true;
  if (!a || !b) return false;
  return equalPosition(a.start, b.start) && equalPosition(a.end, b.end);
}

function isImageLikeObject(value) {
  if (!value || typeof value !== "object") {
    return false;
  }
  if (typeof ImageBitmap !== "undefined" && value instanceof ImageBitmap) {
    return true;
  }
  if (typeof HTMLImageElement !== "undefined" && value instanceof HTMLImageElement) {
    return true;
  }
  if (typeof HTMLCanvasElement !== "undefined" && value instanceof HTMLCanvasElement) {
    return true;
  }
  if (typeof OffscreenCanvas !== "undefined" && value instanceof OffscreenCanvas) {
    return true;
  }
  if (typeof ImageData !== "undefined" && value instanceof ImageData) {
    return true;
  }
  return false;
}

function argbToCss(argb, fallback) {
  if (!argb) return fallback;
  const a = ((argb >>> 24) & 0xff) / 255;
  const r = (argb >>> 16) & 0xff;
  const g = (argb >>> 8) & 0xff;
  const b = argb & 0xff;
  return `rgba(${r}, ${g}, ${b}, ${a.toFixed(3)})`;
}

class Canvas2DRenderer {
  constructor(theme = {}) {
    this.theme = { ...DEFAULT_THEME, ...cloneTheme(theme) };
    this._measureCanvas = document.createElement("canvas");
    this._measureCtx = this._measureCanvas.getContext("2d");
    this._baseFontSize = 14;
    this._fontFamily = "Menlo, Consolas, Monaco, monospace";
    this._iconProvider = null;
    this._pixelRatioX = 1;
    this._pixelRatioY = 1;
  }

  createTextMeasurerCallbacks() {
    return {
      measureTextWidth: (text, fontStyle) => {
        this._measureCtx.font = this._fontByStyle(fontStyle);
        return this._measureCtx.measureText(text || "").width;
      },
      measureInlayHintWidth: (text) => {
        this._measureCtx.font = `12px ${this._fontFamily}`;
        return this._measureCtx.measureText(text || "").width;
      },
      measureIconWidth: (iconId) => {
        const iconDescriptor = this._resolveIconDescriptor(iconId);
        const width = Number(iconDescriptor?.width);
        if (Number.isFinite(width) && width > 0) {
          return width;
        }
        return this._baseFontSize;
      },
      getFontMetrics: () => {
        this._measureCtx.font = this._fontByStyle(0);
        const metrics = this._measureCtx.measureText("Mg");
        const ascent = metrics.actualBoundingBoxAscent || this._baseFontSize * 0.8;
        const descent = metrics.actualBoundingBoxDescent || this._baseFontSize * 0.2;
        return { ascent: -ascent, descent };
      },
    };
  }

  applyTheme(theme = {}) {
    this.theme = { ...DEFAULT_THEME, ...cloneTheme(theme) };
    return this.getTheme();
  }

  getTheme() {
    return cloneTheme(this.theme);
  }

  setEditorIconProvider(provider) {
    this._iconProvider = provider || null;
  }

  getEditorIconProvider() {
    return this._iconProvider;
  }

  _setPixelSnapContext(ctx) {
    if (!ctx || typeof ctx.getTransform !== "function") {
      this._pixelRatioX = 1;
      this._pixelRatioY = 1;
      return;
    }
    const transform = ctx.getTransform();
    const ratioX = Number(transform?.a);
    const ratioY = Number(transform?.d);
    this._pixelRatioX = Number.isFinite(ratioX) && ratioX > 0 ? ratioX : 1;
    this._pixelRatioY = Number.isFinite(ratioY) && ratioY > 0 ? ratioY : 1;
  }

  _snapX(value) {
    const n = Number(value);
    if (!Number.isFinite(n)) {
      return 0;
    }
    return Math.round(n * this._pixelRatioX) / this._pixelRatioX;
  }

  _snapY(value) {
    const n = Number(value);
    if (!Number.isFinite(n)) {
      return 0;
    }
    return Math.round(n * this._pixelRatioY) / this._pixelRatioY;
  }

  _snapRect(x, y, width, height) {
    const x1 = this._snapX(x);
    const y1 = this._snapY(y);
    const x2 = this._snapX((Number(x) || 0) + Math.max(0, Number(width) || 0));
    const y2 = this._snapY((Number(y) || 0) + Math.max(0, Number(height) || 0));
    return {
      x: x1,
      y: y1,
      width: Math.max(0, x2 - x1),
      height: Math.max(0, y2 - y1),
    };
  }

  render(ctx, model, viewportWidth, viewportHeight) {
    this._setPixelSnapContext(ctx);
    ctx.fillStyle = this.theme.background;
    ctx.fillRect(0, 0, viewportWidth, viewportHeight);
    if (!model) return;

    this._drawCurrentLine(ctx, model, viewportWidth);
    this._drawSelection(ctx, model);
    this._drawLines(ctx, model);
    this._drawCursor(ctx, model);
    this._drawGutter(ctx, model, viewportHeight);
  }

  _drawCurrentLine(ctx, model, viewportWidth) {
    if (!model.current_line) return;
    const cursor = model.cursor;
    const h = cursor && cursor.height > 0 ? cursor.height : this._baseFontSize * 1.4;
    const rect = this._snapRect(0, model.current_line.y, viewportWidth, h);
    ctx.fillStyle = this.theme.currentLine;
    ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
  }

  _drawSelection(ctx, model) {
    ctx.fillStyle = this.theme.selection;
    forVector(model.selection_rects, (rect) => {
      const snapped = this._snapRect(rect.origin.x, rect.origin.y, rect.width, rect.height);
      ctx.fillRect(snapped.x, snapped.y, snapped.width, snapped.height);
    });
  }

  _drawLines(ctx, model) {
    forVector(model.lines, (line) => {
      forVector(line.runs, (run) => {
        this._drawRun(ctx, run);
      });
    });
  }

  _drawRun(ctx, run) {
    if (!run) return;
    const style = run.style || {};
    const text = run.text || "";
    const topY = this._snapY(run.y - this._baseFontSize);
    const baselineY = this._snapY(run.y);
    const runType = toInt(run.type, 0);
    const lineHeight = this._baseFontSize * 1.3;

    if (style.background_color) {
      const backgroundRect = this._snapRect(run.x, topY, run.width, lineHeight);
      ctx.fillStyle = argbToCss(style.background_color, "transparent");
      ctx.fillRect(backgroundRect.x, backgroundRect.y, backgroundRect.width, backgroundRect.height);
    }

    if (runType === 5) {
      const foldRect = this._snapRect(run.x, topY, run.width, lineHeight);
      ctx.fillStyle = this.theme.foldPlaceholderBg;
      ctx.fillRect(foldRect.x, foldRect.y, foldRect.width, foldRect.height);
      ctx.fillStyle = this.theme.foldPlaceholderText;
    } else if (runType === 3) {
      this._drawInlayHintRun(ctx, run, topY, style, text);
      return;
    } else if (runType === 4) {
      ctx.fillStyle = this.theme.phantomText;
    } else {
      ctx.fillStyle = argbToCss(style.color, this.theme.text);
    }

    if (text.length > 0) {
      ctx.font = this._fontByStyle(style.font_style || 0);
      ctx.fillText(text, run.x, baselineY);
    }
  }

  _drawCursor(ctx, model) {
    if (!model.cursor || !model.cursor.visible) return;
    const rect = this._snapRect(model.cursor.position.x, model.cursor.position.y, 2, model.cursor.height);
    ctx.fillStyle = this.theme.cursor;
    ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
  }

  _drawGutter(ctx, model, viewportHeight) {
    if (model.split_x <= 0) return;
    const gutterRect = this._snapRect(0, 0, model.split_x, viewportHeight);
    ctx.fillStyle = this.theme.background;
    ctx.fillRect(gutterRect.x, gutterRect.y, gutterRect.width, gutterRect.height);

    ctx.strokeStyle = this.theme.splitLine;
    if (model.split_line_visible) {
      const splitX = this._snapX(model.split_x) + (0.5 / this._pixelRatioX);
      ctx.beginPath();
      ctx.moveTo(splitX, 0);
      ctx.lineTo(splitX, viewportHeight);
      ctx.stroke();
    }

    ctx.fillStyle = this.theme.lineNumber;
    ctx.font = `12px ${this._fontFamily}`;
    forVector(model.lines, (line) => {
      if (line.wrap_index !== 0 || line.is_phantom_line) return;
      const p = line.line_number_position;
      ctx.fillText(String(line.logical_line + 1), p.x, this._snapY(p.y));
    });

    forVector(model.gutter_icons, (item) => {
      this._drawGutterIcon(ctx, item);
    });

    forVector(model.fold_markers, (item) => {
      this._drawFoldMarker(ctx, item);
    });
  }

  _fontByStyle(fontStyle) {
    const bold = (fontStyle & 1) !== 0;
    const italic = (fontStyle & 2) !== 0;
    const weight = bold ? "700" : "400";
    const slope = italic ? "italic" : "normal";
    return `${slope} ${weight} ${this._baseFontSize}px ${this._fontFamily}`;
  }

  _drawInlayHintRun(ctx, run, topY, style, text) {
    const margin = Math.max(0, Number(run.margin) || 0);
    const padding = Math.max(0, Number(run.padding) || 0);
    const runHeight = this._baseFontSize * 1.3;
    const bgX = run.x + margin;
    const bgY = this._snapY(topY);
    const bgWidth = Math.max(1, run.width - margin * 2);
    const bgHeight = runHeight;

    if (run.color_value) {
      const blockSize = Math.max(4, Math.min(bgHeight, bgWidth));
      const blockX = bgX;
      const blockY = this._snapY(bgY + (bgHeight - blockSize) * 0.5);
      const color = argbToCss(toInt(run.color_value, 0), this.theme.inlayHintBg);
      const colorRect = this._snapRect(blockX, blockY, blockSize, blockSize);
      ctx.fillStyle = color;
      ctx.fillRect(colorRect.x, colorRect.y, colorRect.width, colorRect.height);
      ctx.strokeStyle = "rgba(0,0,0,0.24)";
      ctx.strokeRect(
        colorRect.x + (0.5 / this._pixelRatioX),
        colorRect.y + (0.5 / this._pixelRatioY),
        Math.max(1, colorRect.width - (1 / this._pixelRatioX)),
        Math.max(1, colorRect.height - (1 / this._pixelRatioY)),
      );
      return;
    }

    const bgRect = this._snapRect(bgX, bgY, bgWidth, bgHeight);
    ctx.fillStyle = this.theme.inlayHintBg;
    ctx.fillRect(bgRect.x, bgRect.y, bgRect.width, bgRect.height);

    if (toInt(run.icon_id, 0) > 0) {
      const iconSize = Math.max(4, Math.min(bgHeight - padding * 2, bgWidth - padding * 2));
      const iconX = bgX + (bgWidth - iconSize) * 0.5;
      const iconY = bgY + (bgHeight - iconSize) * 0.5;
      this._drawIconGlyphOrImage(ctx, toInt(run.icon_id, 0), iconX, iconY, iconSize, iconSize, true);
      return;
    }

    ctx.fillStyle = argbToCss(style.color, this.theme.text);
    if (text.length > 0) {
      ctx.font = this._fontByStyle(style.font_style || 0);
      const textX = bgX + padding;
      ctx.fillText(text, textX, this._snapY(run.y));
    }
  }

  _drawGutterIcon(ctx, item) {
    if (!item) return;
    const width = Number(item.width);
    const height = Number(item.height);
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
      return;
    }
    const iconId = toInt(item.icon_id, 0);
    const x = Number(item.origin?.x) || 0;
    const y = this._snapY(item.origin?.y);
    this._drawIconGlyphOrImage(ctx, iconId, x, y, width, height, false);
  }

  _drawFoldMarker(ctx, marker) {
    if (!marker) return;
    const width = Number(marker.width);
    const height = Number(marker.height);
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
      return;
    }
    const state = toInt(marker.fold_state, 0);
    if (state <= 0) {
      return;
    }

    const x = Number(marker.origin?.x) || 0;
    const y = this._snapY(marker.origin?.y);
    const centerX = x + width * 0.5;
    const centerY = y + height * 0.5;
    const halfSize = Math.max(2, Math.min(width, height) * 0.28);
    ctx.strokeStyle = this.theme.lineNumber;
    ctx.lineWidth = Math.max(1, height * 0.1);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    if (state === 2) {
      ctx.moveTo(centerX - halfSize * 0.5, centerY - halfSize);
      ctx.lineTo(centerX + halfSize * 0.5, centerY);
      ctx.lineTo(centerX - halfSize * 0.5, centerY + halfSize);
    } else {
      ctx.moveTo(centerX - halfSize, centerY - halfSize * 0.5);
      ctx.lineTo(centerX, centerY + halfSize * 0.5);
      ctx.lineTo(centerX + halfSize, centerY - halfSize * 0.5);
    }
    ctx.stroke();
  }

  _drawIconGlyphOrImage(ctx, iconId, x, y, width, height, inlay = false) {
    if (iconId <= 0 || width <= 0 || height <= 0) {
      return;
    }
    const descriptor = this._resolveIconDescriptor(iconId);
    if (descriptor?.image && isImageLikeObject(descriptor.image)) {
      try {
        const imageRect = this._snapRect(x, y, width, height);
        ctx.drawImage(descriptor.image, imageRect.x, imageRect.y, imageRect.width, imageRect.height);
        return;
      } catch (_) {
        // ignore
      }
    }

    const color = descriptor?.color ?? this.theme.gutterIconFallback;
    const cssColor = typeof color === "number"
      ? argbToCss(color >>> 0, this.theme.gutterIconFallback)
      : String(color || this.theme.gutterIconFallback);

    if (descriptor?.glyph || descriptor?.text) {
      const glyph = String(descriptor.glyph ?? descriptor.text ?? "");
      if (glyph.length > 0) {
        ctx.fillStyle = cssColor;
        ctx.font = `${Math.max(8, Math.floor(Math.min(width, height) * 0.8))}px ${this._fontFamily}`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(glyph, this._snapX(x + width * 0.5), this._snapY(y + height * 0.5));
        ctx.textAlign = "start";
        ctx.textBaseline = "alphabetic";
        return;
      }
    }

    if (descriptor?.color || !inlay) {
      ctx.fillStyle = cssColor;
      const radius = Math.max(2, Math.min(width, height) * 0.22);
      const cx = x + width * 0.5;
      const cy = y + height * 0.5;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.fill();
      return;
    }

    ctx.fillStyle = cssColor;
    const colorRect = this._snapRect(x, y, width, height);
    ctx.fillRect(colorRect.x, colorRect.y, colorRect.width, colorRect.height);
  }

  _resolveIconDescriptor(iconId) {
    const provider = this._iconProvider;
    if (!provider) {
      return null;
    }

    let raw = null;
    try {
      if (typeof provider === "function") {
        raw = provider(iconId);
      } else if (typeof provider.getIconDescriptor === "function") {
        raw = provider.getIconDescriptor(iconId);
      } else if (typeof provider.getIcon === "function") {
        raw = provider.getIcon(iconId);
      } else if (typeof provider.getIconImage === "function") {
        raw = provider.getIconImage(iconId);
      }
    } catch (error) {
      console.warn("Editor icon provider error:", error);
      return null;
    }

    if (raw == null) {
      return null;
    }

    if (isImageLikeObject(raw)) {
      return { image: raw };
    }

    if (typeof raw === "string") {
      return { glyph: raw };
    }

    if (typeof raw === "number") {
      return { color: raw >>> 0 };
    }

    if (typeof raw === "object") {
      const descriptor = { ...raw };
      if (descriptor.canvas && !descriptor.image) {
        descriptor.image = descriptor.canvas;
      }
      if (descriptor.image && !isImageLikeObject(descriptor.image)) {
        delete descriptor.image;
      }
      return descriptor;
    }

    return null;
  }
}

class CompletionPopupController {
  constructor(container) {
    this._container = container;
    this._panel = document.createElement("div");
    this._panel.style.position = "absolute";
    this._panel.style.display = "none";
    this._panel.style.minWidth = "260px";
    this._panel.style.maxWidth = "420px";
    this._panel.style.maxHeight = "220px";
    this._panel.style.overflowY = "auto";
    this._panel.style.zIndex = "36";
    this._panel.style.border = "1px solid rgba(255,255,255,0.16)";
    this._panel.style.borderRadius = "8px";
    this._panel.style.background = "#1f2937";
    this._panel.style.boxShadow = "0 12px 24px rgba(0,0,0,0.35)";
    this._panel.style.padding = "4px";

    this._items = [];
    this._selectedIndex = 0;
    this._confirmListener = null;
    this._renderer = null;

    this._cursorX = 0;
    this._cursorY = 0;
    this._cursorHeight = 18;

    this._container.appendChild(this._panel);
  }

  setConfirmListener(listener) {
    this._confirmListener = typeof listener === "function" ? listener : null;
  }

  setRenderer(renderer) {
    this._renderer = typeof renderer === "function" ? renderer : null;
    this._renderItems();
  }

  get isShowing() {
    return this._panel.style.display !== "none";
  }

  updateCursorPosition(x, y, height) {
    this._cursorX = Number.isFinite(x) ? x : 0;
    this._cursorY = Number.isFinite(y) ? y : 0;
    this._cursorHeight = Math.max(12, Number.isFinite(height) ? height : 18);
    if (this.isShowing) {
      this._applyPosition();
    }
  }

  updateItems(items) {
    this._items = asArray(items).slice();
    this._selectedIndex = 0;
    if (this._items.length === 0) {
      this.dismissPanel();
      return;
    }
    this._renderItems();
    this._show();
  }

  dismissPanel() {
    this._panel.style.display = "none";
  }

  dispose() {
    this.dismissPanel();
    this._items = [];
    if (this._panel) {
      this._panel.remove();
    }
    this._panel = null;
    this._confirmListener = null;
    this._renderer = null;
  }

  handleKeyEvent(event) {
    if (!this.isShowing || this._items.length === 0) {
      return false;
    }

    switch (event.key) {
      case "ArrowUp":
        this._moveSelection(-1);
        return true;
      case "ArrowDown":
        this._moveSelection(1);
        return true;
      case "Enter":
      case "Tab":
        this._confirmSelected();
        return true;
      case "Escape":
        this.dismissPanel();
        return true;
      default:
        return false;
    }
  }

  _show() {
    this._panel.style.display = "block";
    this._applyPosition();
  }

  _applyPosition() {
    const gap = 4;
    const panelRect = this._panel.getBoundingClientRect();
    const hostRect = this._container.getBoundingClientRect();

    let x = this._cursorX;
    let y = this._cursorY + this._cursorHeight + gap;

    const maxX = Math.max(0, hostRect.width - panelRect.width - gap);
    const maxY = Math.max(0, hostRect.height - panelRect.height - gap);

    if (x > maxX) {
      x = maxX;
    }

    if (y > maxY) {
      y = this._cursorY - panelRect.height - gap;
    }

    x = Math.max(0, x);
    y = Math.max(0, y);

    this._panel.style.left = `${Math.round(x)}px`;
    this._panel.style.top = `${Math.round(y)}px`;
  }

  _renderItems() {
    this._panel.innerHTML = "";

    this._items.forEach((item, index) => {
      const row = document.createElement("div");
      row.style.display = "flex";
      row.style.alignItems = "center";
      row.style.gap = "8px";
      row.style.padding = "6px 8px";
      row.style.borderRadius = "6px";
      row.style.cursor = "pointer";
      row.style.fontFamily = "Consolas, Menlo, Monaco, monospace";
      row.style.fontSize = "13px";
      row.style.color = "#f3f4f6";

      const selected = index === this._selectedIndex;
      row.style.background = selected ? "rgba(255,255,255,0.12)" : "transparent";

      if (this._renderer) {
        this._renderer({
          row,
          item,
          index,
          selected,
        });
      } else {
        const badge = document.createElement("span");
        badge.style.minWidth = "18px";
        badge.style.height = "18px";
        badge.style.borderRadius = "6px";
        badge.style.display = "inline-flex";
        badge.style.alignItems = "center";
        badge.style.justifyContent = "center";
        badge.style.fontSize = "10px";
        badge.style.fontWeight = "700";
        badge.style.background = "rgba(148,163,184,0.45)";
        badge.style.color = "#ffffff";
        badge.textContent = this._kindLetter(item.kind);

        const label = document.createElement("span");
        label.style.flex = "1 1 auto";
        label.textContent = item.label || "";

        const detail = document.createElement("span");
        detail.style.flex = "0 0 auto";
        detail.style.opacity = "0.75";
        detail.style.fontSize = "11px";
        detail.textContent = item.detail || "";

        row.appendChild(badge);
        row.appendChild(label);
        row.appendChild(detail);
      }

      row.addEventListener("mouseenter", () => {
        this._selectedIndex = index;
        this._rerenderSelection();
      });

      row.addEventListener("mousedown", (event) => {
        event.preventDefault();
        this._selectedIndex = index;
        this._confirmSelected();
      });

      this._panel.appendChild(row);
    });
  }

  _kindLetter(kind) {
    switch (toInt(kind, CompletionItem.KIND_TEXT)) {
      case CompletionItem.KIND_KEYWORD: return "K";
      case CompletionItem.KIND_FUNCTION: return "F";
      case CompletionItem.KIND_VARIABLE: return "V";
      case CompletionItem.KIND_CLASS: return "C";
      case CompletionItem.KIND_INTERFACE: return "I";
      case CompletionItem.KIND_MODULE: return "M";
      case CompletionItem.KIND_PROPERTY: return "P";
      case CompletionItem.KIND_SNIPPET: return "S";
      default: return "T";
    }
  }

  _moveSelection(delta) {
    if (this._items.length === 0) {
      return;
    }
    this._selectedIndex = Math.max(0, Math.min(this._items.length - 1, this._selectedIndex + delta));
    this._rerenderSelection();
  }

  _rerenderSelection() {
    const children = this._panel.children;
    for (let i = 0; i < children.length; i += 1) {
      const selected = i === this._selectedIndex;
      children[i].style.background = selected ? "rgba(255,255,255,0.12)" : "transparent";
    }
  }

  _confirmSelected() {
    if (this._selectedIndex < 0 || this._selectedIndex >= this._items.length) {
      return;
    }
    const item = this._items[this._selectedIndex];
    this.dismissPanel();
    if (this._confirmListener) {
      this._confirmListener(item);
    }
  }
}
export class SweetEditorWidget {
  constructor(container, wasmModule, options = {}) {
    this.container = container;
    this._wasm = wasmModule;
    this._options = options;
    this._locale = resolveLocale(options.locale || (typeof navigator !== "undefined" ? navigator.language : "en"));
    this._i18n = CONTEXT_MENU_I18N[this._locale];
    this._eventType = resolveEnum(wasmModule, "EventType", FALLBACK_EVENT_TYPE);
    this._gestureType = resolveEnum(wasmModule, "GestureType", FALLBACK_GESTURE_TYPE);
    this._keyCode = resolveEnum(wasmModule, "KeyCode", FALLBACK_KEY_CODE);
    this._modifier = resolveEnum(wasmModule, "Modifier", FALLBACK_MODIFIER);
    this._spanLayer = resolveEnum(wasmModule, "SpanLayer", FALLBACK_SPAN_LAYER);
    this._hitTargetType = resolveEnum(wasmModule, "HitTargetType", FALLBACK_HIT_TARGET_TYPE);

    this._renderer = new Canvas2DRenderer(options.theme || {});
    this._core = new WebEditorCore(
      wasmModule,
      this._renderer.createTextMeasurerCallbacks(),
      options.editorOptions || {},
      () => this._markDirty(),
    );

    this._documentFactory = new DocumentFactory(wasmModule);
    this._document = null;
    this._languageConfiguration = options.languageConfiguration || null;
    this._metadata = options.metadata || null;

    this._activeTouches = new Map();
    this._edgeTimer = null;
    this._rafHandle = 0;
    this._dirty = false;
    this._renderErrorLogged = false;
    this._disposed = false;
    this._viewportWidth = 0;
    this._viewportHeight = 0;
    this._lastRenderModel = null;
    this._rafScheduledAt = 0;

    const perfOverlayOptions = (options.performanceOverlay && typeof options.performanceOverlay === "object")
      ? options.performanceOverlay
      : {};
    this._performanceOverlayEnabled = options.performanceOverlay === false
      ? false
      : Boolean(perfOverlayOptions.enabled ?? true);
    this._performanceOverlayUpdateIntervalMs = Math.max(120, toInt(perfOverlayOptions.updateIntervalMs, 250));
    this._performanceOverlay = null;
    this._perfStats = {
      frameCount: 0,
      fpsWindowStartAt: 0,
      fps: 0,
      avgFrameMs: 0,
      avgBuildMs: 0,
      avgDrawMs: 0,
      avgRafLagMs: 0,
      maxFrameMs: 0,
      requeueCount: 0,
      lastOverlayUpdatedAt: 0,
      lastFrameMs: 0,
      lastScrollSampleY: 0,
      lastScrollSampleAt: 0,
      scrollSpeedY: 0,
    };
    this._debugInputLogsEnabled = options.debugInputLogs === undefined
      ? true
      : Boolean(options.debugInputLogs);
    this._debugInputLogSeq = 0;

    this._isComposing = false;
    this._compositionCommitPending = false;
    this._compositionEndFallbackData = "";
    this._compositionEndTimer = 0;
    this._suppressNextInputEvent = false;
    this._printableFallbackEpoch = 0;
    this._pendingPrintableFallbackTimers = new Set();
    this._documentKeyRouteActive = false;
    this._newLineActionProviders = [];
    this._ownedDecorationProviders = new Set();
    this._listeners = new Map();

    this._lastCursorPosition = null;
    this._lastSelection = null;
    this._lastHasSelection = false;
    this._lastScrollX = 0;
    this._lastScrollY = 0;
    this._lastScale = 1.0;

    this._contextMenuVisible = false;
    this._contextMenuButtons = {};
    this._bracketPairsUnsupportedLogged = false;
    this._lastContextMenuEvent = { time: 0, x: 0, y: 0 };
    this._settingsState = {
      wrapMode: options.editorOptions?.wrapMode ?? null,
      readOnly: !!options.editorOptions?.readOnly,
      autoIndentMode: options.editorOptions?.autoIndentMode ?? null,
      maxGutterIcons: options.editorOptions?.maxGutterIcons ?? 0,
      lineSpacingAdd: options.editorOptions?.lineSpacingAdd ?? 0,
      lineSpacingMult: options.editorOptions?.lineSpacingMult ?? 1,
    };
    this._settingsFacade = this._createSettingsFacade();

    this._onDocumentPointerDown = (event) => this._handleDocumentPointerDown(event);
    this._onDocumentKeyDown = (event) => this._handleDocumentKeyDown(event);
    this._onWindowBlur = () => {
      this._documentKeyRouteActive = false;
      this._hideContextMenu();
      this.dismissCompletion();
    };

    this._completionPopupController = new CompletionPopupController(this.container);
    this._completionPopupController.setConfirmListener((item) => this._applyCompletionItem(item));

    this._completionProviderManager = new CompletionProviderManager({
      buildContext: (triggerKind, triggerCharacter) => this._buildCompletionContext(triggerKind, triggerCharacter),
      onItemsUpdated: (items) => {
        this._updateCompletionPopupCursorAnchor();
        this._completionPopupController.updateItems(items);
      },
      onDismissed: () => {
        this._completionPopupController.dismissPanel();
      },
    });

    const decorationOptions = options.decorationOptions || options.decorationProviderOptions || {};
    this._decorationProviderManager = new DecorationProviderManager({
      buildContext: (ctx) => new DecorationContext(ctx),
      getVisibleLineRange: () => this.getVisibleLineRange(),
      ensureVisibleLineRange: () => this._refreshRenderModelSnapshot(),
      getTotalLineCount: () => this.getTotalLineCount(),
      getLanguageConfiguration: () => this._languageConfiguration,
      getMetadata: () => this._metadata,
      onApplyMerged: (merged, visibleRange) => this._applyMergedDecorations(merged, visibleRange),
      textChangeMode: decorationOptions.textChangeMode,
      resultDispatchMode: decorationOptions.resultDispatchMode,
      providerCallMode: decorationOptions.providerCallMode,
      scrollRefreshMinIntervalMs: decorationOptions.scrollRefreshMinIntervalMs,
      overscanViewportMultiplier: decorationOptions.overscanViewportMultiplier,
      applySynchronously: decorationOptions.applySynchronously,
    });

    this._setupDom();
    this._bindEvents();
    this._resize();

    this._core.setCompositionEnabled(options.enableComposition ?? true);
    if (options.editorIconProvider) {
      this.setEditorIconProvider(options.editorIconProvider);
    }
    if (options.settings && typeof options.settings === "object") {
      this._applySettingsObject(options.settings);
    }
    this._applyLanguageBracketPairs();

    if (options.text != null) {
      this.loadText(options.text, { kind: options.documentKind || "piece-table" });
    }

    this._syncEventStateFromCore();
    this._markDirty();
  }

  getCore() {
    return this._core;
  }

  getDocumentFactory() {
    return this._documentFactory;
  }

  subscribe(eventType, listener) {
    const key = String(eventType || "");
    if (!key || typeof listener !== "function") {
      return () => {};
    }
    if (!this._listeners.has(key)) {
      this._listeners.set(key, new Set());
    }
    const bucket = this._listeners.get(key);
    bucket.add(listener);
    return () => {
      this.unsubscribe(key, listener);
    };
  }

  unsubscribe(eventType, listener) {
    const key = String(eventType || "");
    if (!key || typeof listener !== "function") {
      return;
    }
    const bucket = this._listeners.get(key);
    if (!bucket) {
      return;
    }
    bucket.delete(listener);
    if (bucket.size === 0) {
      this._listeners.delete(key);
    }
  }

  getSettings() {
    return this._settingsFacade;
  }

  applyTheme(theme = {}) {
    this._renderer.applyTheme(theme || {});
    this._markDirty();
    return this.getTheme();
  }

  getTheme() {
    return this._renderer.getTheme();
  }

  setEditorIconProvider(provider) {
    this._renderer.setEditorIconProvider(provider || null);
    this._markDirty();
  }

  getEditorIconProvider() {
    return this._renderer.getEditorIconProvider();
  }

  addNewLineActionProvider(provider) {
    if (typeof provider !== "function") {
      return;
    }
    if (!this._newLineActionProviders.includes(provider)) {
      this._newLineActionProviders.push(provider);
    }
  }

  removeNewLineActionProvider(provider) {
    const index = this._newLineActionProviders.indexOf(provider);
    if (index >= 0) {
      this._newLineActionProviders.splice(index, 1);
    }
  }

  setScale(scale) {
    this._core.setScale(scale);
    this._emitScrollScaleFromCore(false, true);
  }

  setWrapMode(mode) {
    const value = toInt(mode, 0);
    this._settingsState.wrapMode = value;
    this._core.setWrapMode(value);
  }

  setReadOnly(readOnly) {
    const value = !!readOnly;
    this._settingsState.readOnly = value;
    this._core.setReadOnly(value);
  }

  isReadOnly() {
    return !!this._core.isReadOnly();
  }

  setAutoIndentMode(mode) {
    const value = toInt(mode, 0);
    this._settingsState.autoIndentMode = value;
    this._core.setAutoIndentMode(value);
  }

  getAutoIndentMode() {
    return this._core.getAutoIndentMode();
  }

  setMaxGutterIcons(count) {
    const value = Math.max(0, toInt(count, 0));
    this._settingsState.maxGutterIcons = value;
    this._core.setMaxGutterIcons(value);
  }

  setLineSpacing(add, mult) {
    const addValue = Number(add);
    const multValue = Number(mult);
    this._settingsState.lineSpacingAdd = Number.isFinite(addValue) ? addValue : 0;
    this._settingsState.lineSpacingMult = Number.isFinite(multValue) ? multValue : 1;
    this._core.setLineSpacing(this._settingsState.lineSpacingAdd, this._settingsState.lineSpacingMult);
  }

  setContentStartPadding(padding) {
    const value = Number(padding);
    this._settingsState.contentStartPadding = Number.isFinite(value) ? value : 0;
    this._core.setContentStartPadding(this._settingsState.contentStartPadding);
  }

  getContentStartPadding() {
    return this._settingsState.contentStartPadding || 0;
  }

  setDecorationScrollRefreshMinIntervalMs(intervalMs) {
    const value = Math.max(0, toInt(intervalMs, 0));
    this.setDecorationProviderOptions({ scrollRefreshMinIntervalMs: value });
  }

  getDecorationScrollRefreshMinIntervalMs() {
    return toInt(this.getDecorationProviderOptions()?.scrollRefreshMinIntervalMs, 0);
  }

  setDecorationOverscanViewportMultiplier(multiplier) {
    const value = Number(multiplier);
    this.setDecorationProviderOptions({
      overscanViewportMultiplier: Number.isFinite(value) ? Math.max(0, value) : 0.5,
    });
  }

  getDecorationOverscanViewportMultiplier() {
    const value = Number(this.getDecorationProviderOptions()?.overscanViewportMultiplier);
    return Number.isFinite(value) ? value : 0.5;
  }

  insert(text) {
    const result = this._core.insert(String(text ?? ""));
    this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
    return result;
  }

  insertText(text) {
    return this.insert(text);
  }

  replace(range, newText) {
    const result = this._core.replaceText(range, String(newText ?? ""));
    this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
    return result;
  }

  replaceText(range, newText) {
    return this.replace(range, newText);
  }

  delete(range) {
    const result = this._core.deleteText(range);
    this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
    return result;
  }

  deleteText(range) {
    return this.delete(range);
  }

  undo() {
    const result = this._core.undo();
    this._handleTextEditResult(result, { action: TextChangeAction.UNDO });
    return !!(result && (result.changed || asArray(result.changes).length > 0));
  }

  redo() {
    const result = this._core.redo();
    this._handleTextEditResult(result, { action: TextChangeAction.REDO });
    return !!(result && (result.changed || asArray(result.changes).length > 0));
  }

  canUndo() {
    return !!this._core.canUndo();
  }

  canRedo() {
    return !!this._core.canRedo();
  }

  getCursorPosition() {
    return this._core.getCursorPosition();
  }

  setCursorPosition(position) {
    this._core.setCursorPosition(position);
    this._emitStateEventsFromCore({ forceCursor: true });
  }

  getSelection() {
    if (!this._core.hasSelection()) {
      return { hasSelection: false, range: null };
    }
    return {
      hasSelection: true,
      range: this._core.getSelection(),
    };
  }

  getSelectionRange() {
    return this._core.getSelection();
  }

  hasSelection() {
    return !!this._core.hasSelection();
  }

  setSelection(startOrRange, startColumn, endLine, endColumn) {
    this._core.setSelection(startOrRange, startColumn, endLine, endColumn);
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: true });
  }

  clearSelection() {
    this._core.clearSelection();
    this._emitStateEventsFromCore({ forceSelection: true });
  }

  selectAll() {
    this._core.selectAll();
    this._emitStateEventsFromCore({ forceSelection: true, forceCursor: true });
  }

  getSelectedText() {
    return String(this._core.getSelectedText() ?? "");
  }

  moveCursorLeft(extendSelection = false) {
    this._core.moveCursorLeft(extendSelection);
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: !!extendSelection });
  }

  moveCursorRight(extendSelection = false) {
    this._core.moveCursorRight(extendSelection);
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: !!extendSelection });
  }

  moveCursorUp(extendSelection = false) {
    this._core.moveCursorUp(extendSelection);
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: !!extendSelection });
  }

  moveCursorDown(extendSelection = false) {
    this._core.moveCursorDown(extendSelection);
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: !!extendSelection });
  }

  moveCursorToLineStart(extendSelection = false) {
    this._core.moveCursorToLineStart(extendSelection);
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: !!extendSelection });
  }

  moveCursorToLineEnd(extendSelection = false) {
    this._core.moveCursorToLineEnd(extendSelection);
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: !!extendSelection });
  }

  goto(line, column = 0) {
    this.gotoPosition(line, column);
  }

  gotoPosition(line, column = 0) {
    this._core.gotoPosition(line, column);
    this._emitStateEventsFromCore({ forceCursor: true, includeScrollScale: true });
  }

  scrollToLine(line, behavior = 0) {
    this._core.scrollToLine(line, behavior);
    this._emitScrollScaleFromCore(true, false);
  }

  setScroll(scrollX, scrollY) {
    this._core.setScroll(scrollX, scrollY);
    this._emitScrollScaleFromCore(true, false);
  }

  getScrollMetrics() {
    return this._core.getScrollMetrics();
  }

  getPositionRect(line, column) {
    return this._core.getPositionRect(line, column);
  }

  getCursorRect() {
    return this._core.getCursorRect();
  }

  getViewState() {
    return this._core.getViewState();
  }

  getLayoutMetrics() {
    return this._core.getLayoutMetrics();
  }

  setLineInlayHints(line, hints) {
    this._core.setLineInlayHints(line, hints);
  }

  setBatchLineInlayHints(hintsByLine) {
    this._core.setBatchLineInlayHints(hintsByLine);
  }

  setLinePhantomTexts(line, phantoms) {
    this._core.setLinePhantomTexts(line, phantoms);
  }

  setBatchLinePhantomTexts(phantomsByLine) {
    this._core.setBatchLinePhantomTexts(phantomsByLine);
  }

  setLineGutterIcons(line, icons) {
    this._core.setLineGutterIcons(line, icons);
  }

  setBatchLineGutterIcons(iconsByLine) {
    this._core.setBatchLineGutterIcons(iconsByLine);
  }

  setLineDiagnostics(line, diagnostics) {
    this._core.setLineDiagnostics(line, diagnostics);
  }

  setBatchLineDiagnostics(diagsByLine) {
    this._core.setBatchLineDiagnostics(diagsByLine);
  }

  setIndentGuides(guides) {
    this._core.setIndentGuides(guides);
  }

  setBatchIndentGuides(guides) {
    this.setIndentGuides(guides);
  }

  setBracketGuides(guides) {
    this._core.setBracketGuides(guides);
  }

  setBatchBracketGuides(guides) {
    this.setBracketGuides(guides);
  }

  setFlowGuides(guides) {
    this._core.setFlowGuides(guides);
  }

  setBatchFlowGuides(guides) {
    this.setFlowGuides(guides);
  }

  setSeparatorGuides(guides) {
    this._core.setSeparatorGuides(guides);
  }

  setBatchSeparatorGuides(guides) {
    this.setSeparatorGuides(guides);
  }

  setFoldRegions(regions) {
    this._core.setFoldRegions(regions);
  }

  setBatchFoldRegions(regions) {
    this.setFoldRegions(regions);
  }

  clearInlayHints() {
    this._core.clearInlayHints();
  }

  clearPhantomTexts() {
    this._core.clearPhantomTexts();
  }

  clearGutterIcons() {
    this._core.clearGutterIcons();
  }

  clearDiagnostics() {
    this._core.clearDiagnostics();
  }

  clearGuides() {
    this._core.clearGuides();
  }

  clearAllDecorations() {
    this._core.clearAllDecorations();
  }

  insertSnippet(snippetTemplate) {
    const result = this._core.insertSnippet(snippetTemplate);
    this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
    return result;
  }

  startLinkedEditing(model) {
    this._core.startLinkedEditing(model || {});
    this._markDirty();
  }

  isInLinkedEditing() {
    return !!this._core.isInLinkedEditing();
  }

  linkedEditingNext() {
    const result = this._core.linkedEditingNext();
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: true });
    return !!result;
  }

  linkedEditingPrev() {
    const result = this._core.linkedEditingPrev();
    this._emitStateEventsFromCore({ forceCursor: true, forceSelection: true });
    return !!result;
  }

  cancelLinkedEditing() {
    this._core.cancelLinkedEditing();
  }

  finishLinkedEditing() {
    this._core.finishLinkedEditing();
  }

  toggleFoldAt(line) {
    return !!this._core.toggleFoldAt(line);
  }

  toggleFold(line) {
    return this.toggleFoldAt(line);
  }

  foldAt(line) {
    return !!this._core.foldAt(line);
  }

  unfoldAt(line) {
    return !!this._core.unfoldAt(line);
  }

  foldAll() {
    this._core.foldAll();
  }

  unfoldAll() {
    this._core.unfoldAll();
  }

  isLineVisible(line) {
    return !!this._core.isLineVisible(line);
  }

  setMatchedBrackets(open, close, closeLine, closeColumn) {
    if (arguments.length >= 4) {
      this._core.setMatchedBrackets(open, close, closeLine, closeColumn);
      return;
    }
    this._core.setMatchedBrackets(open, close);
  }

  clearMatchedBrackets() {
    this._core.clearMatchedBrackets();
  }

  setLocale(locale) {
    this._locale = resolveLocale(locale);
    this._i18n = CONTEXT_MENU_I18N[this._locale];
    this._refreshContextMenuLabels();
  }

  setLanguageConfiguration(config) {
    this._languageConfiguration = config || null;
    this._applyLanguageBracketPairs();
    this.requestDecorationRefresh();
  }

  getLanguageConfiguration() {
    return this._languageConfiguration;
  }

  setMetadata(metadata) {
    this._metadata = metadata ?? null;
  }

  getMetadata() {
    return this._metadata;
  }

  getText() {
    if (!this._document) {
      return "";
    }
    return String(this._document.getText() ?? "");
  }

  loadText(text, options = {}) {
    if (this._document) {
      this._document.dispose();
    }

    this._document = this._documentFactory.fromText(String(text ?? ""), options);
    this._core.loadDocument(this._document);

    this._decorationProviderManager.onDocumentLoaded();
    this.dismissCompletion();
    this._syncEventStateFromCore();
    this._emitEvent(EditorEventType.DOCUMENT_LOADED, {
      textLength: this.getText().length,
      lineCount: this.getTotalLineCount(),
    });
    this._markDirty();
  }

  dispose() {
    if (this._disposed) return;
    this._disposed = true;

    this._invalidatePrintableFallback();
    this._suppressNextInputEvent = false;

    if (this._compositionEndTimer) {
      clearTimeout(this._compositionEndTimer);
      this._compositionEndTimer = 0;
    }

    this._hideContextMenu();
    this.dismissCompletion();

    document.removeEventListener("pointerdown", this._onDocumentPointerDown, true);
    document.removeEventListener("keydown", this._onDocumentKeyDown, true);
    window.removeEventListener("blur", this._onWindowBlur);

    if (this._rafHandle) {
      cancelAnimationFrame(this._rafHandle);
      this._rafHandle = 0;
    }
    if (this._edgeTimer) {
      clearInterval(this._edgeTimer);
      this._edgeTimer = null;
    }
    if (this._resizeObserver) {
      this._resizeObserver.disconnect();
      this._resizeObserver = null;
    }

    if (this._document) {
      this._document.dispose();
      this._document = null;
    }

    this._ownedDecorationProviders.forEach((provider) => {
      if (provider && typeof provider.dispose === "function") {
        provider.dispose();
      }
    });
    this._ownedDecorationProviders.clear();

    this._core.dispose();

    if (this._contextMenu) {
      this._contextMenu.remove();
      this._contextMenu = null;
    }

    if (this._completionPopupController) {
      this._completionPopupController.dispose();
      this._completionPopupController = null;
    }

    if (this._performanceOverlay) {
      this._performanceOverlay.remove();
      this._performanceOverlay = null;
    }

    this._listeners.clear();
    this._newLineActionProviders = [];

    this._canvas.remove();
    this._input.remove();
  }

  registerTextStyle(styleId, color, backgroundColor = 0, fontStyle = 0) {
    this._core.registerTextStyle(styleId, color, backgroundColor, fontStyle);
  }

  setLineSpans(line, layer, spans) {
    this._core.setLineSpans(line, layer, spans);
  }

  setBatchLineSpans(layer, spansByLine) {
    this._core.setBatchLineSpans(layer, spansByLine);
  }

  clearHighlights(layer = null) {
    this._core.clearHighlights(layer);
  }

  createSweetLineDecorationProvider(options = {}) {
    return new SweetLineIncrementalDecorationProvider({
      ...options,
      fileName: options.fileName ?? options.sourceFileName ?? this._metadata?.fileName,
      text: options.text ?? options.sourceText ?? this.getText(),
      getDocumentText: typeof options.getDocumentText === "function"
        ? options.getDocumentText
        : () => this.getText(),
    });
  }

  addSweetLineDecorationProvider(options = {}) {
    const provider = options instanceof SweetLineIncrementalDecorationProvider
      ? options
      : this.createSweetLineDecorationProvider(options);
    this.addDecorationProvider(provider);
    this._ownedDecorationProviders.add(provider);
    return provider;
  }

  addDecorationProvider(provider) {
    this._decorationProviderManager.addProvider(provider);
  }

  removeDecorationProvider(provider) {
    this._decorationProviderManager.removeProvider(provider);
    if (this._ownedDecorationProviders.has(provider)) {
      this._ownedDecorationProviders.delete(provider);
      if (provider && typeof provider.dispose === "function") {
        provider.dispose();
      }
    }
  }

  requestDecorationRefresh() {
    this._decorationProviderManager.requestRefresh();
  }

  setDecorationProviderOptions(options = {}) {
    this._decorationProviderManager.setOptions(options);
    if ("scrollRefreshMinIntervalMs" in options || "overscanViewportMultiplier" in options) {
      this._settingsFacade = this._createSettingsFacade();
    }
  }

  getDecorationProviderOptions() {
    return this._decorationProviderManager.getOptions();
  }

  setDecorationOptions(options = {}) {
    this.setDecorationProviderOptions(options);
  }

  getDecorationOptions() {
    return this.getDecorationProviderOptions();
  }

  addCompletionProvider(provider) {
    this._completionProviderManager.addProvider(provider);
  }

  removeCompletionProvider(provider) {
    this._completionProviderManager.removeProvider(provider);
  }

  triggerCompletion() {
    this._completionProviderManager.triggerCompletion(CompletionTriggerKind.INVOKED, null);
  }

  showCompletionItems(items) {
    this._completionProviderManager.showItems(items);
  }

  dismissCompletion() {
    this._completionProviderManager.dismiss();
  }

  setCompletionItemRenderer(renderer) {
    this._completionPopupController.setRenderer(renderer);
  }

  getVisibleLineRange(options = {}) {
    const preferFreshModel = Boolean(options?.preferFreshModel ?? false);
    const model = preferFreshModel
      ? (this._refreshRenderModelSnapshot() || this._lastRenderModel)
      : (this._lastRenderModel || this._refreshRenderModelSnapshot());
    if (!model || !model.lines) {
      return { start: 0, end: -1 };
    }

    let start = Number.MAX_SAFE_INTEGER;
    let end = -1;

    forVector(model.lines, (line) => {
      const logicalLine = toInt(line.logical_line, -1);
      if (logicalLine < 0) {
        return;
      }
      if (logicalLine < start) {
        start = logicalLine;
      }
      if (logicalLine > end) {
        end = logicalLine;
      }
    });

    if (end < 0 || start === Number.MAX_SAFE_INTEGER) {
      return { start: 0, end: -1 };
    }

    return { start, end };
  }

  getTotalLineCount() {
    if (!this._document) {
      return 0;
    }
    return toInt(this._document.getLineCount(), 0);
  }

  _createSettingsFacade() {
    return {
      setScale: (scale) => this.setScale(scale),
      getScale: () => {
        const view = this._core.getViewState() || {};
        const value = Number(view.scale);
        return Number.isFinite(value) ? value : 1;
      },
      setWrapMode: (mode) => this.setWrapMode(mode),
      getWrapMode: () => this._settingsState.wrapMode,
      setReadOnly: (readOnly) => this.setReadOnly(readOnly),
      isReadOnly: () => this.isReadOnly(),
      setAutoIndentMode: (mode) => this.setAutoIndentMode(mode),
      getAutoIndentMode: () => this.getAutoIndentMode(),
      setMaxGutterIcons: (count) => this.setMaxGutterIcons(count),
      getMaxGutterIcons: () => this._settingsState.maxGutterIcons,
      setLineSpacing: (add, mult) => this.setLineSpacing(add, mult),
      getLineSpacing: () => ({
        add: this._settingsState.lineSpacingAdd,
        mult: this._settingsState.lineSpacingMult,
      }),
      setDecorationScrollRefreshMinIntervalMs: (intervalMs) =>
        this.setDecorationScrollRefreshMinIntervalMs(intervalMs),
      getDecorationScrollRefreshMinIntervalMs: () =>
        this.getDecorationScrollRefreshMinIntervalMs(),
      setDecorationOverscanViewportMultiplier: (multiplier) =>
        this.setDecorationOverscanViewportMultiplier(multiplier),
      getDecorationOverscanViewportMultiplier: () =>
        this.getDecorationOverscanViewportMultiplier(),
    };
  }

  _applySettingsObject(settings) {
    if (!settings || typeof settings !== "object") {
      return;
    }
    if ("scale" in settings) {
      this.setScale(settings.scale);
    }
    if ("wrapMode" in settings) {
      this.setWrapMode(settings.wrapMode);
    }
    if ("readOnly" in settings) {
      this.setReadOnly(settings.readOnly);
    }
    if ("autoIndentMode" in settings) {
      this.setAutoIndentMode(settings.autoIndentMode);
    }
    if ("maxGutterIcons" in settings) {
      this.setMaxGutterIcons(settings.maxGutterIcons);
    }
    if ("lineSpacingAdd" in settings || "lineSpacingMult" in settings) {
      const add = "lineSpacingAdd" in settings ? settings.lineSpacingAdd : this._settingsState.lineSpacingAdd;
      const mult = "lineSpacingMult" in settings ? settings.lineSpacingMult : this._settingsState.lineSpacingMult;
      this.setLineSpacing(add, mult);
    }
    if ("scrollRefreshMinIntervalMs" in settings) {
      this.setDecorationScrollRefreshMinIntervalMs(settings.scrollRefreshMinIntervalMs);
    }
    if ("overscanViewportMultiplier" in settings) {
      this.setDecorationOverscanViewportMultiplier(settings.overscanViewportMultiplier);
    }
  }

  _emitEvent(eventType, payload = {}) {
    const key = String(eventType || "");
    if (!key) {
      return;
    }
    const listeners = this._listeners.get(key);
    if (!listeners || listeners.size === 0) {
      return;
    }
    const event = {
      type: key,
      editor: this,
      timestamp: Date.now(),
      ...payload,
    };
    listeners.forEach((listener) => {
      try {
        listener(event);
      } catch (error) {
        console.error(`SweetEditorWidget listener error (${key}):`, error);
      }
    });
  }

  _emitTextChanged(action, range, text) {
    this._emitEvent(EditorEventType.TEXT_CHANGED, {
      action: String(action || TextChangeAction.INSERT),
      changeRange: cloneRange(range),
      range: cloneRange(range),
      text: text == null ? null : String(text),
      newText: text == null ? null : String(text),
    });
  }

  _emitContextMenuEvent(cursorPosition, screenPoint, nativeEvent) {
    const x = Number(screenPoint?.x) || 0;
    const y = Number(screenPoint?.y) || 0;
    const now = Date.now();
    const last = this._lastContextMenuEvent || { time: 0, x: 0, y: 0 };
    if (now - last.time < 40 && Math.abs(x - last.x) < 1 && Math.abs(y - last.y) < 1) {
      return;
    }
    this._lastContextMenuEvent = { time: now, x, y };
    this._emitEvent(EditorEventType.CONTEXT_MENU, {
      cursorPosition: clonePosition(cursorPosition),
      screenPoint: { x, y },
      nativeEvent,
    });
  }

  _safeGetScrollMetrics() {
    try {
      return this._core.getScrollMetrics();
    } catch (_) {
      return null;
    }
  }

  _syncEventStateFromCore() {
    this._lastCursorPosition = clonePosition(this._core.getCursorPosition());
    let hasSelection = false;
    let selection = null;
    try {
      hasSelection = !!this._core.hasSelection();
      selection = hasSelection ? cloneRange(this._core.getSelection()) : null;
    } catch (_) {
      hasSelection = false;
      selection = null;
    }
    this._lastHasSelection = hasSelection;
    this._lastSelection = selection;
    const metrics = this._safeGetScrollMetrics();
    this._lastScrollX = Number(metrics?.scroll_x ?? metrics?.scrollX ?? 0) || 0;
    this._lastScrollY = Number(metrics?.scroll_y ?? metrics?.scrollY ?? 0) || 0;
    this._lastScale = Number(metrics?.scale ?? 1) || 1;
  }

  _emitCursorChanged(cursorPosition, force = false) {
    const cursor = clonePosition(cursorPosition);
    if (!force && equalPosition(cursor, this._lastCursorPosition)) {
      return;
    }
    this._lastCursorPosition = cursor;
    this._emitEvent(EditorEventType.CURSOR_CHANGED, {
      cursorPosition: clonePosition(cursor),
    });
  }

  _emitSelectionChanged(hasSelection, selection, cursorPosition, force = false) {
    const normalizedHasSelection = !!hasSelection;
    const normalizedSelection = normalizedHasSelection ? cloneRange(selection) : null;
    if (
      !force
      && normalizedHasSelection === this._lastHasSelection
      && equalRange(normalizedSelection, this._lastSelection)
    ) {
      return;
    }
    this._lastHasSelection = normalizedHasSelection;
    this._lastSelection = normalizedSelection;
    this._lastCursorPosition = clonePosition(cursorPosition);
    this._emitEvent(EditorEventType.SELECTION_CHANGED, {
      hasSelection: normalizedHasSelection,
      selection: cloneRange(normalizedSelection),
      cursorPosition: clonePosition(cursorPosition),
    });
  }

  _emitScrollScaleValues(scrollX, scrollY, scale, forceScroll = false, forceScale = false) {
    const nextScrollX = Number.isFinite(scrollX) ? scrollX : this._lastScrollX;
    const nextScrollY = Number.isFinite(scrollY) ? scrollY : this._lastScrollY;
    const nextScale = Number.isFinite(scale) ? scale : this._lastScale;

    const scrollChanged = forceScroll
      || Math.abs(nextScrollX - this._lastScrollX) > 0.01
      || Math.abs(nextScrollY - this._lastScrollY) > 0.01;
    const scaleChanged = forceScale || Math.abs(nextScale - this._lastScale) > 1e-5;

    this._lastScrollX = nextScrollX;
    this._lastScrollY = nextScrollY;
    this._lastScale = nextScale;

    if (scrollChanged) {
      this._emitEvent(EditorEventType.SCROLL_CHANGED, {
        scrollX: nextScrollX,
        scrollY: nextScrollY,
      });
    }
    if (scaleChanged) {
      this._emitEvent(EditorEventType.SCALE_CHANGED, {
        scale: nextScale,
      });
    }
  }

  _emitScrollScaleFromCore(forceScroll = false, forceScale = false) {
    const metrics = this._safeGetScrollMetrics();
    if (!metrics) {
      return;
    }
    this._emitScrollScaleValues(
      Number(metrics.scroll_x ?? metrics.scrollX),
      Number(metrics.scroll_y ?? metrics.scrollY),
      Number(metrics.scale),
      forceScroll,
      forceScale,
    );
  }

  _emitScrollScaleFromGestureResult(result, emitScroll = true, emitScale = false) {
    if (!result) {
      return;
    }
    const scrollX = Number(result.view_scroll_x ?? result.viewScrollX ?? this._lastScrollX);
    const scrollY = Number(result.view_scroll_y ?? result.viewScrollY ?? this._lastScrollY);
    const scale = Number(result.view_scale ?? result.viewScale ?? this._lastScale);
    this._emitScrollScaleValues(scrollX, scrollY, scale, emitScroll, emitScale);
  }

  _emitStateEventsFromCore(options = {}) {
    const forceCursor = !!options.forceCursor;
    const forceSelection = !!options.forceSelection;
    const includeScrollScale = !!options.includeScrollScale;

    const cursor = clonePosition(this._core.getCursorPosition());
    this._emitCursorChanged(cursor, forceCursor);

    let hasSelection = false;
    let selection = null;
    try {
      hasSelection = !!this._core.hasSelection();
      selection = hasSelection ? this._core.getSelection() : null;
    } catch (_) {
      hasSelection = false;
      selection = null;
    }
    this._emitSelectionChanged(hasSelection, selection, cursor, forceSelection);

    if (includeScrollScale) {
      this._emitScrollScaleFromCore();
    }
  }

  _dispatchHitTargetEvents(hitTarget, screenPoint, nativeEvent) {
    if (!hitTarget) {
      return;
    }
    const hitType = toInt(hitTarget.type, this._hitTargetType.NONE);
    if (hitType === this._hitTargetType.NONE) {
      return;
    }

    const line = toInt(hitTarget.line, 0);
    const column = toInt(hitTarget.column, 0);
    const iconId = toInt(hitTarget.icon_id ?? hitTarget.iconId, 0);
    const colorValue = toInt(hitTarget.color_value ?? hitTarget.colorValue, 0);

    if (hitType === this._hitTargetType.INLAY_HINT_TEXT || hitType === this._hitTargetType.INLAY_HINT_ICON) {
      this._emitEvent(EditorEventType.INLAY_HINT_CLICK, {
        line,
        column,
        iconId,
        isIcon: hitType === this._hitTargetType.INLAY_HINT_ICON,
        screenPoint,
        nativeEvent,
      });
      return;
    }

    if (hitType === this._hitTargetType.INLAY_HINT_COLOR) {
      this._emitEvent(EditorEventType.INLAY_HINT_CLICK, {
        line,
        column,
        colorValue,
        isColor: true,
        screenPoint,
        nativeEvent,
      });
      return;
    }

    if (hitType === this._hitTargetType.GUTTER_ICON) {
      this._emitEvent(EditorEventType.GUTTER_ICON_CLICK, {
        line,
        iconId,
        screenPoint,
        nativeEvent,
      });
      return;
    }

    if (hitType === this._hitTargetType.FOLD_PLACEHOLDER || hitType === this._hitTargetType.FOLD_GUTTER) {
      this._emitEvent(EditorEventType.FOLD_TOGGLE, {
        line,
        fromGutter: hitType === this._hitTargetType.FOLD_GUTTER,
        screenPoint,
        nativeEvent,
      });
    }
  }

  _fireGestureEvents(result, screenPoint, nativeEvent = null) {
    if (!result) {
      return;
    }
    const point = {
      x: Number(screenPoint?.x) || 0,
      y: Number(screenPoint?.y) || 0,
    };
    const cursor = clonePosition(result.cursor_position ?? result.cursorPosition ?? this._core.getCursorPosition());
    const hasSelection = !!(result.has_selection ?? result.hasSelection ?? false);
    const selection = cloneRange(result.selection);
    const gestureType = toInt(result.type, this._gestureType.UNDEFINED);

    switch (gestureType) {
      case this._gestureType.LONG_PRESS:
        this._emitEvent(EditorEventType.LONG_PRESS, {
          cursorPosition: clonePosition(cursor),
          screenPoint: point,
          nativeEvent,
        });
        this._emitCursorChanged(cursor, true);
        this._lastHasSelection = hasSelection;
        this._lastSelection = hasSelection ? cloneRange(selection) : null;
        break;
      case this._gestureType.DOUBLE_TAP:
        this._emitEvent(EditorEventType.DOUBLE_TAP, {
          cursorPosition: clonePosition(cursor),
          hasSelection,
          selection: cloneRange(selection),
          screenPoint: point,
          nativeEvent,
        });
        this._emitCursorChanged(cursor, true);
        if (hasSelection) {
          this._emitSelectionChanged(true, selection, cursor, true);
        } else {
          this._lastHasSelection = false;
          this._lastSelection = null;
        }
        break;
      case this._gestureType.TAP:
        this._emitCursorChanged(cursor, true);
        this._lastHasSelection = hasSelection;
        this._lastSelection = hasSelection ? cloneRange(selection) : null;
        this.dismissCompletion();
        this._dispatchHitTargetEvents(result.hit_target ?? result.hitTarget, point, nativeEvent);
        break;
      case this._gestureType.SCROLL:
      case this._gestureType.FAST_SCROLL:
        this._emitScrollScaleFromGestureResult(result, true, false);
        this._decorationProviderManager.onScrollChanged();
        this.dismissCompletion();
        break;
      case this._gestureType.SCALE:
        this._emitScrollScaleFromGestureResult(result, false, true);
        break;
      case this._gestureType.DRAG_SELECT:
        this._emitSelectionChanged(hasSelection, selection, cursor, true);
        break;
      case this._gestureType.CONTEXT_MENU:
        this._emitContextMenuEvent(cursor, point, nativeEvent);
        this._updateContextMenuState();
        this._showContextMenu(point.x, point.y);
        break;
      default:
        break;
    }
  }

  _provideNewLineAction() {
    if (!Array.isArray(this._newLineActionProviders) || this._newLineActionProviders.length === 0) {
      return null;
    }
    const cursor = clonePosition(this._core.getCursorPosition()) || { line: 0, column: 0 };
    const lineText = this._document
      ? String(this._document.getLineText(cursor.line) ?? "")
      : "";
    const context = {
      lineNumber: cursor.line,
      column: cursor.column,
      lineText,
      languageConfiguration: this._languageConfiguration,
      editorMetadata: this._metadata,
    };
    for (const provider of this._newLineActionProviders) {
      try {
        const action = provider(context);
        if (action == null) {
          continue;
        }
        if (typeof action === "string") {
          return { text: action };
        }
        if (typeof action === "object" && typeof action.text === "string") {
          return action;
        }
      } catch (error) {
        console.error("NewLineActionProvider error:", error);
      }
    }
    return null;
  }

  _setupDom() {
    this.container.style.position = this.container.style.position || "relative";
    this.container.style.overflow = "hidden";

    this._canvas = document.createElement("canvas");
    this._canvas.style.width = "100%";
    this._canvas.style.height = "100%";
    this._canvas.style.display = "block";
    this._canvas.style.touchAction = "none";
    this.container.appendChild(this._canvas);

    this._ctx = this._canvas.getContext("2d");

    this._input = document.createElement("textarea");
    this._input.setAttribute("aria-label", "Editor hidden input");
    this._input.tabIndex = -1;
    this._input.spellcheck = false;
    this._input.autocomplete = "off";
    this._input.style.position = "absolute";
    this._input.style.left = "0";
    this._input.style.top = "0";
    this._input.style.width = "2px";
    this._input.style.height = "18px";
    this._input.style.padding = "0";
    this._input.style.margin = "0";
    this._input.style.border = "0";
    this._input.style.outline = "none";
    this._input.style.color = "transparent";
    this._input.style.caretColor = "transparent";
    this._input.style.background = "transparent";
    this._input.style.opacity = "0.01";
    this._input.style.pointerEvents = "none";
    this.container.appendChild(this._input);
    this._setupPerformanceOverlay();

    this._createContextMenu();

    this._resizeObserver = new ResizeObserver(() => this._resize());
    this._resizeObserver.observe(this.container);
  }

  _bindEvents() {
    this._canvas.addEventListener("pointerdown", (e) => this._onPointerDown(e));
    this._canvas.addEventListener("pointermove", (e) => this._onPointerMove(e));
    this._canvas.addEventListener("pointerup", (e) => this._onPointerUp(e));
    this._canvas.addEventListener("pointercancel", (e) => this._onPointerCancel(e));
    this._canvas.addEventListener("wheel", (e) => this._onWheel(e), { passive: false });
    this._canvas.addEventListener("contextmenu", (e) => this._onContextMenu(e));

    this._input.addEventListener("keydown", (e) => this._onKeyDown(e));
    this._input.addEventListener("beforeinput", (e) => this._onBeforeInput(e));
    this._input.addEventListener("compositionstart", (e) => {
      this._debugInputLog("compositionstart", {
        data: typeof e?.data === "string" ? e.data : "",
        inputValueLength: String(this._input?.value || "").length,
      });
      this._invalidatePrintableFallback();
      if (this._compositionEndTimer) {
        clearTimeout(this._compositionEndTimer);
        this._compositionEndTimer = 0;
      }
      this._isComposing = true;
      this._compositionCommitPending = false;
      this._compositionEndFallbackData = "";
      this._input.value = "";
      this._core.compositionStart();
    });

    this._input.addEventListener("compositionupdate", (e) => {
      this._invalidatePrintableFallback();
      const composingText = typeof e.data === "string" ? e.data : (this._input.value || "");
      this._debugInputLog("compositionupdate", {
        data: typeof e.data === "string" ? e.data : "",
        composingText,
      });
      this._core.compositionUpdate(composingText);
    });

    this._input.addEventListener("compositionend", (e) => {
      this._debugInputLog("compositionend", {
        data: typeof e.data === "string" ? e.data : "",
        inputValueLength: String(this._input?.value || "").length,
      });
      this._invalidatePrintableFallback();
      this._isComposing = false;
      this._compositionCommitPending = true;
      this._compositionEndFallbackData = typeof e.data === "string" ? e.data : "";
      this._input.value = "";
      this._compositionEndTimer = setTimeout(() => {
        this._compositionEndTimer = 0;
        if (!this._compositionCommitPending) {
          this._debugInputLog("compositionend.timer.skip", {
            reason: "commitPendingFalse",
          });
          return;
        }

        this._compositionCommitPending = false;
        const fallbackCommit = this._compositionEndFallbackData;
        this._compositionEndFallbackData = "";

        const result = fallbackCommit
          ? this._core.compositionEnd(fallbackCommit)
          : this._core.compositionCancel();

        this._handleTextEditResult(result, { action: TextChangeAction.COMPOSITION });
        this._debugInputLog("compositionend.timer.commit", {
          fallbackCommit,
          changed: !!result?.changed,
        });
      }, 0);
    });

    this._input.addEventListener("input", (e) => this._onInput(e));
    this._input.addEventListener("copy", (e) => this._handleClipboardCopyCut(e, false));
    this._input.addEventListener("cut", (e) => this._handleClipboardCopyCut(e, true));
    this._input.addEventListener("paste", (e) => this._handleClipboardPaste(e));

    document.addEventListener("pointerdown", this._onDocumentPointerDown, true);
    document.addEventListener("keydown", this._onDocumentKeyDown, true);
    window.addEventListener("blur", this._onWindowBlur);
  }

  _isCompositionInputType(inputType) {
    const type = String(inputType || "");
    return type.startsWith("insertComposition") || type.startsWith("deleteComposition");
  }

  _setupPerformanceOverlay() {
    if (!this._performanceOverlayEnabled) {
      return;
    }
    const panel = document.createElement("pre");
    panel.setAttribute("aria-hidden", "true");
    panel.style.position = "absolute";
    panel.style.top = "8px";
    panel.style.right = "8px";
    panel.style.margin = "0";
    panel.style.padding = "6px 8px";
    panel.style.border = "none";
    panel.style.borderRadius = "0";
    panel.style.background = "rgba(0, 0, 0, 0.62)";
    panel.style.color = "#ffd400";
    panel.style.font = "12px Menlo, Consolas, Monaco, monospace";
    panel.style.lineHeight = "1.35";
    panel.style.whiteSpace = "pre";
    panel.style.pointerEvents = "none";
    panel.style.zIndex = "30";
    panel.textContent = "FPS --\nFrame -- ms\nRenderLag -- ms";
    this.container.appendChild(panel);
    this._performanceOverlay = panel;
  }

  _nowMs() {
    if (typeof performance !== "undefined" && typeof performance.now === "function") {
      return performance.now();
    }
    return Date.now();
  }

  _smoothValue(previous, current, alpha = 0.18) {
    const value = Number(current);
    if (!Number.isFinite(value)) {
      return Number(previous) || 0;
    }
    const prev = Number(previous);
    if (!Number.isFinite(prev) || prev <= 0) {
      return value;
    }
    return prev + (value - prev) * alpha;
  }

  _recordPerformanceSample(sample = {}) {
    if (!this._performanceOverlayEnabled || !this._perfStats) {
      return;
    }

    const stats = this._perfStats;
    const now = this._nowMs();
    stats.frameCount += 1;
    if (stats.fpsWindowStartAt <= 0) {
      stats.fpsWindowStartAt = now;
    }
    const fpsWindowElapsed = now - stats.fpsWindowStartAt;
    if (fpsWindowElapsed >= 1000) {
      stats.fps = (stats.frameCount * 1000) / fpsWindowElapsed;
      stats.frameCount = 0;
      stats.fpsWindowStartAt = now;
    }

    const frameMs = Math.max(0, Number(sample.frameMs) || 0);
    const buildMs = Math.max(0, Number(sample.buildMs) || 0);
    const drawMs = Math.max(0, Number(sample.drawMs) || 0);
    const rafLagMs = Math.max(0, Number(sample.rafLagMs) || 0);

    stats.avgFrameMs = this._smoothValue(stats.avgFrameMs, frameMs, 0.16);
    stats.avgBuildMs = this._smoothValue(stats.avgBuildMs, buildMs, 0.2);
    stats.avgDrawMs = this._smoothValue(stats.avgDrawMs, drawMs, 0.2);
    stats.avgRafLagMs = this._smoothValue(stats.avgRafLagMs, rafLagMs, 0.2);
    stats.maxFrameMs = Math.max(frameMs, stats.maxFrameMs * 0.92);
    stats.lastFrameMs = frameMs;
    if (sample.requeued) {
      stats.requeueCount += 1;
    }

    if (now - stats.lastOverlayUpdatedAt >= this._performanceOverlayUpdateIntervalMs) {
      this._updatePerformanceOverlay(now);
    }
  }

  _updatePerformanceOverlay(now = this._nowMs()) {
    if (!this._performanceOverlayEnabled || !this._performanceOverlay || !this._perfStats) {
      return;
    }

    const stats = this._perfStats;
    let scrollY = this._lastScrollY;
    const metrics = this._safeGetScrollMetrics();
    if (metrics) {
      const nextScrollY = Number(metrics.scroll_y ?? metrics.scrollY);
      if (Number.isFinite(nextScrollY)) {
        scrollY = nextScrollY;
      }
    }

    if (stats.lastScrollSampleAt > 0) {
      const dt = Math.max(1, now - stats.lastScrollSampleAt);
      const instantSpeedY = ((scrollY - stats.lastScrollSampleY) * 1000) / dt;
      stats.scrollSpeedY = this._smoothValue(stats.scrollSpeedY, instantSpeedY, 0.25);
    }
    stats.lastScrollSampleY = scrollY;
    stats.lastScrollSampleAt = now;
    stats.lastOverlayUpdatedAt = now;

    this._performanceOverlay.textContent = [
      `FPS ${stats.fps.toFixed(1)}`,
      `Frame ${stats.avgFrameMs.toFixed(2)} ms`,
      `Build ${stats.avgBuildMs.toFixed(2)} ms`,
      `Draw ${stats.avgDrawMs.toFixed(2)} ms`,
      `RAF Lag ${stats.avgRafLagMs.toFixed(2)} ms`,
      `ScrollV ${stats.scrollSpeedY.toFixed(1)} px/s`,
      `Max ${stats.maxFrameMs.toFixed(2)} ms`,
    ].join("\n");
  }

  _debugInputTargetName(target) {
    if (!target) {
      return "null";
    }
    if (target === document.body) {
      return "BODY";
    }
    if (target === document.documentElement) {
      return "HTML";
    }
    if (!(target instanceof Element)) {
      return typeof target;
    }
    const tag = target.tagName || target.nodeName || "UNKNOWN";
    const id = target.id ? `#${target.id}` : "";
    const cls = target.className && typeof target.className === "string"
      ? `.${target.className.trim().replace(/\s+/g, ".")}`
      : "";
    return `${tag}${id}${cls}`;
  }

  _debugInputLog(eventName, payload = {}) {
    if (!this._debugInputLogsEnabled) {
      return;
    }
    const seq = ++this._debugInputLogSeq;
    try {
      console.log(`[SweetEditorDebug/Input#${seq}] ${eventName}`, payload);
    } catch (_) {
      // ignore
    }
  }

  _hasActiveCompositionFlow() {
    if (this._isComposing || this._compositionCommitPending) {
      return true;
    }
    if (!this._core || typeof this._core.isComposing !== "function") {
      return false;
    }
    try {
      return !!this._core.isComposing();
    } catch (_) {
      return false;
    }
  }

  _invalidatePrintableFallback() {
    this._printableFallbackEpoch += 1;
    if (!this._pendingPrintableFallbackTimers || this._pendingPrintableFallbackTimers.size === 0) {
      return;
    }
    this._pendingPrintableFallbackTimers.forEach((timerId) => clearTimeout(timerId));
    this._pendingPrintableFallbackTimers.clear();
  }

  _suppressNextInputOnce() {
    this._suppressNextInputEvent = true;
    Promise.resolve().then(() => {
      this._suppressNextInputEvent = false;
    });
  }

  _extractInputText(event, allowValueFallback = true) {
    if (typeof event?.data === "string" && event.data.length > 0) {
      return event.data;
    }
    if (!allowValueFallback) {
      return "";
    }
    return String(this._input?.value || "");
  }

  _applyDomTextInput(event, options = {}) {
    const inputType = String(event?.inputType || "");
    const preventDefault = options.preventDefault === true;
    const allowValueFallback = options.allowValueFallback !== false;
    this._debugInputLog("applyDomTextInput.start", {
      inputType,
      data: typeof event?.data === "string" ? event.data : "",
      preventDefault,
      allowValueFallback,
      inputValueLength: String(this._input?.value || "").length,
      isComposing: !!event?.isComposing,
    });

    if (inputType === "deleteContentBackward") {
      if (preventDefault && typeof event.preventDefault === "function") {
        event.preventDefault();
      }
      const result = this._core.backspace();
      this._input.value = "";
      this._handleTextEditResult(result, { action: TextChangeAction.KEY });
      this._debugInputLog("applyDomTextInput.backspace", {
        changed: !!result?.changed,
      });
      return true;
    }

    if (inputType === "deleteContentForward") {
      if (preventDefault && typeof event.preventDefault === "function") {
        event.preventDefault();
      }
      const result = this._core.deleteForward();
      this._input.value = "";
      this._handleTextEditResult(result, { action: TextChangeAction.KEY });
      this._debugInputLog("applyDomTextInput.deleteForward", {
        changed: !!result?.changed,
      });
      return true;
    }

    const text = this._extractInputText(event, allowValueFallback);
    this._input.value = "";
    if (!text) {
      this._debugInputLog("applyDomTextInput.noText", { inputType });
      return false;
    }

    if (preventDefault && typeof event.preventDefault === "function") {
      event.preventDefault();
    }
    const result = this._core.insert(text);
    this._handleTextEditResult(result, { action: TextChangeAction.KEY });
    this._debugInputLog("applyDomTextInput.insert", {
      inputType,
      text,
      changed: !!result?.changed,
    });
    return true;
  }

  _shouldSchedulePrintableFallback(event) {
    if (!event || event.ctrlKey || event.metaKey || event.altKey) {
      return false;
    }
    const key = typeof event.key === "string" ? event.key : "";
    return key.length === 1;
  }

  _schedulePrintableFallback(event) {
    if (!this._shouldSchedulePrintableFallback(event)) {
      this._debugInputLog("fallback.skip", {
        key: event?.key ?? "",
        ctrl: !!event?.ctrlKey,
        alt: !!event?.altKey,
        meta: !!event?.metaKey,
      });
      return false;
    }
    const text = event.key;
    const epoch = this._printableFallbackEpoch;
    this._debugInputLog("fallback.schedule", {
      text,
      epoch,
      keyCode: Number(event?.keyCode ?? 0) || 0,
      which: Number(event?.which ?? 0) || 0,
    });
    const timerId = setTimeout(() => {
      this._pendingPrintableFallbackTimers.delete(timerId);
      if (epoch !== this._printableFallbackEpoch || this._disposed) {
        this._debugInputLog("fallback.cancelled", {
          text,
          scheduledEpoch: epoch,
          currentEpoch: this._printableFallbackEpoch,
          disposed: this._disposed,
        });
        return;
      }
      const result = this._core.insert(text);
      this._handleTextEditResult(result, { action: TextChangeAction.KEY });
      this._debugInputLog("fallback.fire", {
        text,
        changed: !!result?.changed,
      });
    }, 0);
    this._pendingPrintableFallbackTimers.add(timerId);
    return true;
  }

  _onBeforeInput(e) {
    const inputType = e.inputType || "";
    this._debugInputLog("beforeinput.start", {
      inputType,
      data: typeof e.data === "string" ? e.data : "",
      eventIsComposing: !!e.isComposing,
      flowComposing: this._hasActiveCompositionFlow(),
      inputValueLength: String(this._input?.value || "").length,
    });
    if (inputType === "insertFromComposition") {
      this._invalidatePrintableFallback();
      this._debugInputLog("beforeinput.skip.insertFromComposition", {});
      return;
    }

    if (this._hasActiveCompositionFlow() || this._isCompositionInputType(inputType)) {
      this._invalidatePrintableFallback();
      this._debugInputLog("beforeinput.skip.compositionFlow", {
        inputType,
        flowComposing: this._hasActiveCompositionFlow(),
      });
      return;
    }
    if (e.isComposing && inputType !== "insertText") {
      this._debugInputLog("beforeinput.skip.eventComposing", { inputType });
      return;
    }

    const handled = this._applyDomTextInput(e, { preventDefault: true, allowValueFallback: false });
    this._debugInputLog("beforeinput.handled", { inputType, handled });
    if (handled) {
      this._invalidatePrintableFallback();
      this._suppressNextInputOnce();
    }
  }

  _onInput(e) {
    this._debugInputLog("input.start", {
      inputType: e.inputType || "",
      data: typeof e.data === "string" ? e.data : "",
      eventIsComposing: !!e.isComposing,
      flowComposing: this._hasActiveCompositionFlow(),
      suppressNext: this._suppressNextInputEvent,
      commitPending: this._compositionCommitPending,
      inputValueLength: String(this._input?.value || "").length,
    });
    if (this._suppressNextInputEvent) {
      this._invalidatePrintableFallback();
      this._suppressNextInputEvent = false;
      this._input.value = "";
      this._debugInputLog("input.skip.suppressed", {});
      return;
    }

    const inputType = e.inputType || "";

    if (inputType === "insertFromComposition") {
      this._invalidatePrintableFallback();
      if (this._compositionCommitPending) {
        if (this._compositionEndTimer) {
          clearTimeout(this._compositionEndTimer);
          this._compositionEndTimer = 0;
        }
        this._compositionCommitPending = false;
        const committedText = (typeof e.data === "string" && e.data.length > 0)
          ? e.data
          : (this._input.value || this._compositionEndFallbackData || "");
        this._compositionEndFallbackData = "";
        const result = this._core.compositionEnd(committedText);
        this._handleTextEditResult(result, { action: TextChangeAction.COMPOSITION });
        this._debugInputLog("input.compositionCommit", {
          committedText,
          changed: !!result?.changed,
        });
      }
      this._input.value = "";
      this._debugInputLog("input.skip.insertFromComposition", {});
      return;
    }

    if (this._hasActiveCompositionFlow() || this._isCompositionInputType(inputType)) {
      this._invalidatePrintableFallback();
      this._debugInputLog("input.skip.compositionFlow", { inputType });
      return;
    }
    if (e.isComposing && inputType === "") {
      this._debugInputLog("input.skip.emptyComposingEvent", {});
      return;
    }
    const handled = this._applyDomTextInput(e, { preventDefault: false, allowValueFallback: true });
    this._debugInputLog("input.handled", { inputType, handled });
    if (handled) {
      this._invalidatePrintableFallback();
    }
  }

  _onPointerDown(event) {
    this._hideContextMenu();
    this._documentKeyRouteActive = true;
    this._input.focus();

    if (typeof this._canvas.setPointerCapture === "function") {
      try {
        this._canvas.setPointerCapture(event.pointerId);
      } catch (_) {
        // ignore
      }
    }

    const point = this._eventPoint(event);
    if (event.pointerType === "mouse") {
      const type = event.button === 2 ? this._eventType.MOUSE_RIGHT_DOWN : this._eventType.MOUSE_DOWN;
      this._dispatchGesture(type, [point], event);
      event.preventDefault();
      return;
    }

    this._activeTouches.set(event.pointerId, point);
    const type = this._activeTouches.size === 1 ? this._eventType.TOUCH_DOWN : this._eventType.TOUCH_POINTER_DOWN;
    this._dispatchGesture(type, Array.from(this._activeTouches.values()), event);
    event.preventDefault();
  }

  _onPointerMove(event) {
    const point = this._eventPoint(event);
    if (event.pointerType === "mouse") {
      if ((event.buttons & 1) !== 0) {
        this._dispatchGesture(this._eventType.MOUSE_MOVE, [point], event);
      }
      return;
    }

    if (!this._activeTouches.has(event.pointerId)) return;
    this._activeTouches.set(event.pointerId, point);
    this._dispatchGesture(this._eventType.TOUCH_MOVE, Array.from(this._activeTouches.values()), event);
    event.preventDefault();
  }

  _onPointerUp(event) {
    const point = this._eventPoint(event);
    if (typeof this._canvas.releasePointerCapture === "function") {
      try {
        this._canvas.releasePointerCapture(event.pointerId);
      } catch (_) {
        // ignore
      }
    }

    if (event.pointerType === "mouse") {
      this._dispatchGesture(this._eventType.MOUSE_UP, [point], event);
      return;
    }

    if (!this._activeTouches.has(event.pointerId)) return;
    const type = this._activeTouches.size > 1 ? this._eventType.TOUCH_POINTER_UP : this._eventType.TOUCH_UP;
    this._dispatchGesture(type, Array.from(this._activeTouches.values()), event);
    this._activeTouches.delete(event.pointerId);
    event.preventDefault();
  }

  _onPointerCancel(event) {
    if (event.pointerType !== "mouse") {
      this._dispatchGesture(this._eventType.TOUCH_CANCEL, Array.from(this._activeTouches.values()), event);
      this._activeTouches.delete(event.pointerId);
      event.preventDefault();
    }
  }

  _onWheel(event) {
    this._hideContextMenu();
    const point = this._eventPoint(event);
    this._dispatchGesture(this._eventType.MOUSE_WHEEL, [point], event, event.deltaX, -event.deltaY, 1.0);
    event.preventDefault();
  }

  _onContextMenu(event) {
    event.preventDefault();
    this._documentKeyRouteActive = true;
    this._input.focus();

    const rect = this.container.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    this._updateContextMenuState();
    this._showContextMenu(x, y);
    this._emitContextMenuEvent(this._core.getCursorPosition(), { x, y }, event);
  }

  _handleDocumentPointerDown(event) {
    const target = event?.target ?? null;
    this._documentKeyRouteActive = !!(target && this.container.contains(target));
    if (this._contextMenuVisible && this._contextMenu && !this._contextMenu.contains(event.target)) {
      this._hideContextMenu();
    }
  }

  _isBodyLikeElement(target) {
    return target === document.body || target === document.documentElement;
  }

  _isTextEntryElement(target) {
    if (!target || !(target instanceof Element)) {
      return false;
    }
    const tagName = target.tagName;
    return tagName === "INPUT" || tagName === "TEXTAREA" || tagName === "SELECT" || target.isContentEditable;
  }

  _shouldRouteDocumentKeyEvent(event) {
    if (!event || this._disposed || !this._input) {
      return false;
    }

    const target = event.target ?? null;
    if (target === this._input) {
      return false;
    }

    if (target && this._contextMenu && this._contextMenu.contains(target)) {
      return false;
    }

    if (this._isTextEntryElement(target)) {
      return false;
    }

    if (target && this.container.contains(target)) {
      return true;
    }

    const activeElement = document.activeElement;
    if (activeElement === this._input) {
      if (target && !this._isBodyLikeElement(target) && !this.container.contains(target)) {
        return false;
      }
      return this._documentKeyRouteActive;
    }
    if (activeElement && this.container.contains(activeElement)) {
      return true;
    }

    if (!this._documentKeyRouteActive) {
      return false;
    }

    if (!target || this._isBodyLikeElement(target)) {
      return true;
    }

    return false;
  }

  _handleDocumentKeyDown(event) {
    const targetName = this._debugInputTargetName(event?.target ?? null);
    const shouldRoute = !event.defaultPrevented && this._shouldRouteDocumentKeyEvent(event);
    this._debugInputLog("document.keydown", {
      key: event?.key ?? "",
      keyCode: Number(event?.keyCode ?? 0) || 0,
      which: Number(event?.which ?? 0) || 0,
      defaultPrevented: !!event?.defaultPrevented,
      shouldRoute,
      target: targetName,
      routeActive: !!this._documentKeyRouteActive,
      activeElement: this._debugInputTargetName(document.activeElement),
    });

    if (event.key === "Escape") {
      this._hideContextMenu();
      this.dismissCompletion();
      return;
    }

    if (event.defaultPrevented) {
      return;
    }

    if (!shouldRoute) {
      return;
    }

    this._onKeyDown(event);
  }

  _onKeyDown(event) {
    const hasCompositionFlow = this._hasActiveCompositionFlow();
    this._debugInputLog("keydown.start", {
      key: event?.key ?? "",
      keyCode: Number(event?.keyCode ?? 0) || 0,
      which: Number(event?.which ?? 0) || 0,
      ctrl: !!event?.ctrlKey,
      shift: !!event?.shiftKey,
      alt: !!event?.altKey,
      meta: !!event?.metaKey,
      eventIsComposing: !!event?.isComposing,
      flowComposing: hasCompositionFlow,
    });
    this._hideContextMenu();

    if (this._completionPopupController.handleKeyEvent(event)) {
      this._debugInputLog("keydown.handled.completionPopup", {
        key: event?.key ?? "",
      });
      event.preventDefault();
      event.stopPropagation();
      return;
    }

    const cmd = event.ctrlKey || event.metaKey;
    if (cmd && !event.altKey) {
      const key = (event.key || "").toLowerCase();
      if (key === "c") {
        this._debugInputLog("keydown.handled.copy", {});
        void this._copySelectionToClipboard(false);
        event.preventDefault();
        return;
      }
      if (key === "x") {
        this._debugInputLog("keydown.handled.cut", {});
        void this._copySelectionToClipboard(true);
        event.preventDefault();
        return;
      }
      if (key === " ") {
        this._debugInputLog("keydown.handled.triggerCompletion", {});
        this.triggerCompletion();
        event.preventDefault();
        return;
      }
    }

    if (hasCompositionFlow || event.isComposing || event.key === "Process") {
      this._debugInputLog("keydown.skip.composing", {
        flowComposing: hasCompositionFlow,
        eventIsComposing: !!event.isComposing,
        key: event?.key ?? "",
      });
      return;
    }

    const mods = this._modifiers(event);
    let keyCode = this._mapKeyCode(event);
    const mappedKeyCode = keyCode;
    if (!keyCode) {
      keyCode = this._mapLegacyKeyCode(event);
    }
    this._debugInputLog("keydown.map", {
      key: event?.key ?? "",
      mappedKeyCode,
      legacyMappedKeyCode: keyCode,
      mods,
    });
    if (!keyCode) {
      if (this._schedulePrintableFallback(event)) {
        this._debugInputLog("keydown.defer.fallback", {
          key: event?.key ?? "",
        });
        return;
      }
      this._debugInputLog("keydown.noop.unhandledNoKeyCode", {
        key: event?.key ?? "",
      });
    }

    if (keyCode) {
      const result = this._core.handleKeyEvent({ key_code: keyCode, text: "", modifiers: mods });
      this._debugInputLog("keydown.coreResult", {
        keyCode,
        handled: !!(result && (result.handled ?? result.Handled)),
        contentChanged: !!(result && (result.content_changed ?? result.contentChanged)),
        cursorChanged: !!(result && (result.cursor_changed ?? result.cursorChanged)),
        selectionChanged: !!(result && (result.selection_changed ?? result.selectionChanged)),
      });
      if (result && (result.handled ?? result.Handled)) {
        this._handleKeyEventResult(result, { action: TextChangeAction.KEY });
        event.preventDefault();
        return;
      }
    }

    if (event.key === "Backspace") {
      const edit = this._core.backspace();
      this._handleTextEditResult(edit, { action: TextChangeAction.KEY });
      this._debugInputLog("keydown.fallback.backspace", {
        changed: !!edit?.changed,
      });
      event.preventDefault();
      return;
    }

    if (event.key === "Delete") {
      const edit = this._core.deleteForward();
      this._handleTextEditResult(edit, { action: TextChangeAction.KEY });
      this._debugInputLog("keydown.fallback.deleteForward", {
        changed: !!edit?.changed,
      });
      event.preventDefault();
    }
  }

  _dispatchGesture(type, points, domEvent, wheelX = 0, wheelY = 0, directScale = 1.0) {
    const pointVector = new this._wasm.PointFVector();
    points.forEach((p) => pointVector.push_back({ x: p.x, y: p.y }));

    const result = this._core.handleGestureEvent({
      type,
      points: pointVector,
      modifiers: this._modifiers(domEvent),
      wheel_delta_x: wheelX,
      wheel_delta_y: wheelY,
      direct_scale: directScale,
    });

    if (typeof pointVector.delete === "function") {
      pointVector.delete();
    }

    const screenPoint = points && points.length > 0
      ? { x: Number(points[0].x) || 0, y: Number(points[0].y) || 0 }
      : { x: 0, y: 0 };
    this._fireGestureEvents(result, screenPoint, domEvent);

    if (result && result.needs_edge_scroll) {
      this._startEdgeScroll();
    } else {
      this._stopEdgeScroll();
    }
  }

  _startEdgeScroll() {
    if (this._edgeTimer) return;
    this._edgeTimer = setInterval(() => {
      const result = this._core.tickEdgeScroll();
      if (result && result.needs_edge_scroll) {
        this._emitScrollScaleFromGestureResult(result, false);
        this._decorationProviderManager.onScrollChanged();
      } else {
        this._stopEdgeScroll();
      }
    }, 16);
  }

  _stopEdgeScroll() {
    if (!this._edgeTimer) return;
    clearInterval(this._edgeTimer);
    this._edgeTimer = null;
  }

  _modifiers(event) {
    let mods = 0;
    if (event.shiftKey) mods |= this._modifier.SHIFT;
    if (event.ctrlKey) mods |= this._modifier.CTRL;
    if (event.altKey) mods |= this._modifier.ALT;
    if (event.metaKey) mods |= this._modifier.META;
    return mods;
  }

  _mapKeyCode(event) {
    switch (event.key) {
      case "Backspace": return this._keyCode.BACKSPACE;
      case "Tab": return this._keyCode.TAB;
      case "Enter": return this._keyCode.ENTER;
      case "Escape": return this._keyCode.ESCAPE;
      case "Delete": return this._keyCode.DELETE_KEY;
      case "ArrowLeft": return this._keyCode.LEFT;
      case "ArrowUp": return this._keyCode.UP;
      case "ArrowRight": return this._keyCode.RIGHT;
      case "ArrowDown": return this._keyCode.DOWN;
      case "Home": return this._keyCode.HOME;
      case "End": return this._keyCode.END;
      case "PageUp": return this._keyCode.PAGE_UP;
      case "PageDown": return this._keyCode.PAGE_DOWN;
      default:
        break;
    }

    if ((event.ctrlKey || event.metaKey) && event.key.length === 1) {
      const upper = event.key.toUpperCase();
      if (this._keyCode[upper]) {
        return this._keyCode[upper];
      }
    }
    return 0;
  }

  _mapLegacyKeyCode(event) {
    const rawCode = Number(event?.keyCode ?? event?.which);
    if (!Number.isFinite(rawCode)) {
      return 0;
    }
    switch (Math.trunc(rawCode)) {
      case 8: return this._keyCode.BACKSPACE;
      case 9: return this._keyCode.TAB;
      case 13: return this._keyCode.ENTER;
      case 27: return this._keyCode.ESCAPE;
      case 33: return this._keyCode.PAGE_UP;
      case 34: return this._keyCode.PAGE_DOWN;
      case 35: return this._keyCode.END;
      case 36: return this._keyCode.HOME;
      case 37: return this._keyCode.LEFT;
      case 38: return this._keyCode.UP;
      case 39: return this._keyCode.RIGHT;
      case 40: return this._keyCode.DOWN;
      case 46: return this._keyCode.DELETE_KEY;
      default:
        return 0;
    }
  }

  _eventPoint(event) {
    const rect = this._canvas.getBoundingClientRect();
    return {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
    };
  }

  _syncInputAnchor(model, viewportWidth, viewportHeight) {
    if (!this._input) return;

    let cursorX = 0;
    let cursorY = 0;
    let cursorH = 18;
    const nativeCore = typeof this._core.getNative === "function" ? this._core.getNative() : null;
    if (nativeCore && typeof nativeCore.getCursorScreenRect === "function") {
      try {
        const rect = nativeCore.getCursorScreenRect();
        if (rect) {
          cursorX = Number(rect.x) || 0;
          cursorY = Number(rect.y) || 0;
          cursorH = Math.max(12, Number(rect.height) || 18);
        }
      } catch (_) {
        // ignore
      }
    }

    if (model && model.cursor && model.cursor.position) {
      if (cursorX === 0 && cursorY === 0) {
        cursorX = Number(model.cursor.position.x) || 0;
        cursorY = Number(model.cursor.position.y) || 0;
        cursorH = Math.max(12, Number(model.cursor.height) || 18);
      }
    }

    const width = Math.max(2, viewportWidth || 2);
    const height = Math.max(cursorH, viewportHeight || cursorH);
    const clampedX = Math.max(0, Math.min(width - 2, cursorX));
    const clampedY = Math.max(0, Math.min((viewportHeight || height) - cursorH, cursorY));

    this._input.style.left = `${clampedX}px`;
    this._input.style.top = `${clampedY}px`;
    this._input.style.height = `${cursorH}px`;
    this._input.style.lineHeight = `${cursorH}px`;
    this._input.style.fontSize = `${Math.max(12, Math.round(cursorH * 0.8))}px`;

    this._completionPopupController.updateCursorPosition(clampedX, clampedY, cursorH);
  }

  _resize() {
    const rect = this.container.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const targetWidth = Math.max(1, Math.floor(rect.width * dpr));
    const targetHeight = Math.max(1, Math.floor(rect.height * dpr));

    if (
      this._canvas.width === targetWidth
      && this._canvas.height === targetHeight
      && this._viewportWidth === rect.width
      && this._viewportHeight === rect.height
    ) {
      return;
    }

    this._canvas.width = targetWidth;
    this._canvas.height = targetHeight;
    this._ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this._viewportWidth = rect.width;
    this._viewportHeight = rect.height;
    this._syncInputAnchor(null, rect.width, rect.height);
    this._core.setViewport(rect.width, rect.height);
  }
  _markDirty() {
    if (this._disposed) return;
    this._dirty = true;
    this._requestRender();
  }

  _requestRender() {
    if (this._disposed || this._rafHandle) return;
    this._rafScheduledAt = this._nowMs();
    this._rafHandle = requestAnimationFrame(() => {
      const frameStartAt = this._nowMs();
      const rafLagMs = this._rafScheduledAt > 0 ? Math.max(0, frameStartAt - this._rafScheduledAt) : 0;
      this._rafScheduledAt = 0;
      this._rafHandle = 0;
      if (this._disposed || !this._dirty) return;

      this._dirty = false;
      let buildMs = 0;
      let drawMs = 0;
      try {
        const rect = this.container.getBoundingClientRect();
        const buildStartAt = this._nowMs();
        const model = this._core.buildRenderModel();
        buildMs = Math.max(0, this._nowMs() - buildStartAt);
        this._lastRenderModel = model;
        this._syncInputAnchor(model, rect.width, rect.height);
        const drawStartAt = this._nowMs();
        this._renderer.render(this._ctx, model, rect.width, rect.height);
        drawMs = Math.max(0, this._nowMs() - drawStartAt);
      } catch (error) {
        if (!this._renderErrorLogged) {
          console.error("SweetEditorWidget render error:", error);
          this._renderErrorLogged = true;
        }
      }

      const frameMs = Math.max(0, this._nowMs() - frameStartAt);
      this._recordPerformanceSample({
        frameMs,
        buildMs,
        drawMs,
        rafLagMs,
        requeued: this._dirty,
      });

      if (this._dirty) {
        this._requestRender();
      }
    });
  }

  _safeBuildRenderModel() {
    try {
      return this._core.buildRenderModel();
    } catch (_) {
      return null;
    }
  }

  _refreshRenderModelSnapshot() {
    const model = this._safeBuildRenderModel();
    if (model) {
      this._lastRenderModel = model;
    }
    return model;
  }

  _updateCompletionPopupCursorAnchor() {
    const model = this._lastRenderModel || this._safeBuildRenderModel();
    if (!model || !model.cursor || !model.cursor.position) {
      return;
    }

    this._completionPopupController.updateCursorPosition(
      Number(model.cursor.position.x) || 0,
      Number(model.cursor.position.y) || 0,
      Math.max(12, Number(model.cursor.height) || 18),
    );
  }

  _buildCompletionContext(triggerKind, triggerCharacter) {
    const cursor = this._core.getCursorPosition();
    if (!cursor) {
      return null;
    }

    const line = toInt(cursor.line, 0);
    const lineText = this._document ? (this._document.getLineText(line) || "") : "";
    const wordRange = this._core.getWordRangeAtCursor() || {
      start: { line, column: toInt(cursor.column, 0) },
      end: { line, column: toInt(cursor.column, 0) },
    };

    return new CompletionContext({
      triggerKind,
      triggerCharacter,
      cursorPosition: cursor,
      lineText,
      wordRange,
      languageConfiguration: this._languageConfiguration,
      editorMetadata: this._metadata,
    });
  }

  _applyCompletionItem(item) {
    const completionItem = item instanceof CompletionItem ? item : new CompletionItem(item || {});
    let text = completionItem.insertText ?? completionItem.label;
    let replaceRange = null;

    if (completionItem.textEdit) {
      replaceRange = completionItem.textEdit.range;
      text = completionItem.textEdit.newText;
    } else {
      const wr = this._core.getWordRangeAtCursor();
      if (wr && !this._isEmptyRange(wr)) {
        replaceRange = wr;
      }
    }

    if (replaceRange) {
      const deleteResult = this._core.deleteText(replaceRange);
      this._handleTextEditResult(deleteResult, { action: TextChangeAction.INSERT });
    }

    let insertResult = null;
    if (completionItem.insertTextFormat === CompletionItem.INSERT_TEXT_FORMAT_SNIPPET) {
      insertResult = this._core.insertSnippet(text);
    } else {
      insertResult = this._core.insert(text);
    }
    this._handleTextEditResult(insertResult, { action: TextChangeAction.INSERT });
  }

  _isEmptyRange(range) {
    if (!range || !range.start || !range.end) {
      return true;
    }
    return range.start.line === range.end.line && range.start.column === range.end.column;
  }

  _handleKeyEventResult(result, options = {}) {
    if (!result) {
      return;
    }

    const contentChanged = Boolean(result.content_changed ?? result.contentChanged ?? false);
    const action = options.action ?? TextChangeAction.KEY;
    const editResult = result.edit_result ?? result.editResult ?? null;
    this._debugInputLog("keyEventResult.dispatch", {
      action,
      contentChanged,
      cursorChanged: Boolean(result.cursor_changed ?? result.cursorChanged ?? false),
      selectionChanged: Boolean(result.selection_changed ?? result.selectionChanged ?? false),
      hasEditResult: !!editResult,
      editChanged: Boolean(editResult?.changed ?? false),
      editChangesCount: asArray(editResult?.changes).length,
    });
    if (contentChanged) {
      if (editResult) {
        this._handleTextEditResult(editResult, { action, emitStateEvents: false });
      } else {
        this._debugInputLog("keyEventResult.missingEditResult", {
          action,
          contentChanged,
        });
        this._emitTextChanged(action, null, null);
        this._decorationProviderManager.onTextChanged([]);
        if (this._completionPopupController.isShowing) {
          this._completionProviderManager.triggerCompletion(CompletionTriggerKind.RETRIGGER, null);
        }
      }
    }

    const cursorChanged = Boolean(result.cursor_changed ?? result.cursorChanged ?? false);
    const selectionChanged = Boolean(result.selection_changed ?? result.selectionChanged ?? false);
    if (cursorChanged || selectionChanged) {
      this._emitStateEventsFromCore({
        forceCursor: cursorChanged,
        forceSelection: selectionChanged,
      });
    }
    this.requestDecorationRefresh();
  }

  _handleTextEditResult(editResult, options = {}) {
    if (!editResult) {
      return;
    }

    const action = options.action ?? TextChangeAction.INSERT;
    const emitStateEvents = options.emitStateEvents !== false;
    const changed = Boolean(editResult.changed ?? false);
    const changes = asArray(editResult.changes).map((change) => ({
      range: cloneRange(change?.range),
      oldText: String(change?.oldText ?? change?.old_text ?? ""),
      newText: String(change?.newText ?? change?.new_text ?? ""),
    }));
    const firstChange = changes[0] || null;
    this._debugInputLog("textEdit.apply", {
      action,
      changed,
      emitStateEvents,
      changesCount: changes.length,
      firstRange: firstChange?.range ?? null,
      firstOldLen: firstChange ? firstChange.oldText.length : 0,
      firstNewLen: firstChange ? firstChange.newText.length : 0,
      firstHasNewline: firstChange ? (firstChange.oldText.includes("\n") || firstChange.newText.includes("\n")) : false,
    });

    if (!changed && changes.length === 0) {
      return;
    }

    if (changes.length > 0) {
      changes.forEach((change) => {
        this._emitTextChanged(action, change.range, change.newText);
      });
    } else {
      this._emitTextChanged(action, null, null);
    }

    this._decorationProviderManager.onTextChanged(changes);
    this._triggerCompletionFromTextChanges(changes);
    if (emitStateEvents) {
      this._emitStateEventsFromCore();
    }
  }

  _triggerCompletionFromTextChanges(changes) {
    if (!this._completionProviderManager) {
      return;
    }

    if (this._core.isInLinkedEditing()) {
      return;
    }

    if (!changes || changes.length === 0) {
      if (this._completionPopupController.isShowing) {
        this._completionProviderManager.triggerCompletion(CompletionTriggerKind.RETRIGGER, null);
      }
      return;
    }

    const primary = changes[0] || {};
    const newText = String(primary.newText ?? primary.new_text ?? "");

    if (newText.length === 1) {
      const ch = newText;
      if (this._completionProviderManager.isTriggerCharacter(ch)) {
        this._completionProviderManager.triggerCompletion(CompletionTriggerKind.CHARACTER, ch);
      } else if (this._completionPopupController.isShowing) {
        this._completionProviderManager.triggerCompletion(CompletionTriggerKind.RETRIGGER, null);
      } else if (/^[A-Za-z0-9_]$/.test(ch)) {
        this._completionProviderManager.triggerCompletion(CompletionTriggerKind.INVOKED, null);
      }
      return;
    }

    if (this._completionPopupController.isShowing) {
      this._completionProviderManager.triggerCompletion(CompletionTriggerKind.RETRIGGER, null);
    }
  }

  _applyMergedDecorations(merged, visibleRange) {
    const startLine = toInt(visibleRange?.startLine, 0);
    const endLine = toInt(visibleRange?.endLine, -1);

    this._core.beginBatch();
    try {
      this._applySpanMode(this._spanLayer.SYNTAX, merged.syntaxSpansMode, startLine, endLine);
      this._applySpanMode(this._spanLayer.SEMANTIC, merged.semanticSpansMode, startLine, endLine);
      this._core.setBatchLineSpans(this._spanLayer.SYNTAX, merged.syntaxSpans);
      this._core.setBatchLineSpans(this._spanLayer.SEMANTIC, merged.semanticSpans);

      this._applyInlayMode(merged.inlayHintsMode, startLine, endLine);
      this._core.setBatchLineInlayHints(merged.inlayHints);

      this._applyDiagnosticMode(merged.diagnosticsMode, startLine, endLine);
      this._core.setBatchLineDiagnostics(merged.diagnostics);

      this._applyGutterMode(merged.gutterIconsMode, startLine, endLine);
      this._core.setBatchLineGutterIcons(merged.gutterIcons);

      this._applyPhantomMode(merged.phantomTextsMode, startLine, endLine);
      this._core.setBatchLinePhantomTexts(merged.phantomTexts);

      if (merged.indentGuidesMode === DecorationApplyMode.REPLACE_ALL || merged.indentGuidesMode === DecorationApplyMode.REPLACE_RANGE) {
        this._core.setIndentGuides(merged.indentGuides || []);
      } else if (merged.indentGuides) {
        this._core.setIndentGuides(merged.indentGuides);
      }

      if (merged.bracketGuidesMode === DecorationApplyMode.REPLACE_ALL || merged.bracketGuidesMode === DecorationApplyMode.REPLACE_RANGE) {
        this._core.setBracketGuides(merged.bracketGuides || []);
      } else if (merged.bracketGuides) {
        this._core.setBracketGuides(merged.bracketGuides);
      }

      if (merged.flowGuidesMode === DecorationApplyMode.REPLACE_ALL || merged.flowGuidesMode === DecorationApplyMode.REPLACE_RANGE) {
        this._core.setFlowGuides(merged.flowGuides || []);
      } else if (merged.flowGuides) {
        this._core.setFlowGuides(merged.flowGuides);
      }

      if (merged.separatorGuidesMode === DecorationApplyMode.REPLACE_ALL || merged.separatorGuidesMode === DecorationApplyMode.REPLACE_RANGE) {
        this._core.setSeparatorGuides(merged.separatorGuides || []);
      } else if (merged.separatorGuides) {
        this._core.setSeparatorGuides(merged.separatorGuides);
      }

      if (merged.foldRegionsMode === DecorationApplyMode.REPLACE_ALL || merged.foldRegionsMode === DecorationApplyMode.REPLACE_RANGE) {
        this._core.setFoldRegions(merged.foldRegions || []);
      } else if (merged.foldRegions && merged.foldRegions.length > 0) {
        this._core.setFoldRegions(merged.foldRegions);
      }
    } finally {
      this._core.endBatch();
    }
  }

  _applySpanMode(layer, mode, startLine, endLine) {
    if (mode === DecorationApplyMode.REPLACE_ALL) {
      this._core.clearHighlights(layer);
      return;
    }
    if (mode === DecorationApplyMode.REPLACE_RANGE) {
      this._core.setBatchLineSpans(layer, this._buildEmptyLineMap(startLine, endLine));
    }
  }

  _applyInlayMode(mode, startLine, endLine) {
    if (mode === DecorationApplyMode.REPLACE_ALL) {
      this._core.clearInlayHints();
      return;
    }
    if (mode === DecorationApplyMode.REPLACE_RANGE) {
      this._core.setBatchLineInlayHints(this._buildEmptyLineMap(startLine, endLine));
    }
  }

  _applyDiagnosticMode(mode, startLine, endLine) {
    if (mode === DecorationApplyMode.REPLACE_ALL) {
      this._core.clearDiagnostics();
      return;
    }
    if (mode === DecorationApplyMode.REPLACE_RANGE) {
      this._core.setBatchLineDiagnostics(this._buildEmptyLineMap(startLine, endLine));
    }
  }

  _applyGutterMode(mode, startLine, endLine) {
    if (mode === DecorationApplyMode.REPLACE_ALL) {
      this._core.clearGutterIcons();
      return;
    }
    if (mode === DecorationApplyMode.REPLACE_RANGE) {
      this._core.setBatchLineGutterIcons(this._buildEmptyLineMap(startLine, endLine));
    }
  }

  _applyPhantomMode(mode, startLine, endLine) {
    if (mode === DecorationApplyMode.REPLACE_ALL) {
      this._core.clearPhantomTexts();
      return;
    }
    if (mode === DecorationApplyMode.REPLACE_RANGE) {
      this._core.setBatchLinePhantomTexts(this._buildEmptyLineMap(startLine, endLine));
    }
  }

  _buildEmptyLineMap(startLine, endLine) {
    const out = new Map();
    if (endLine < startLine) {
      return out;
    }
    for (let line = startLine; line <= endLine; line += 1) {
      out.set(line, []);
    }
    return out;
  }

  _applyLanguageBracketPairs() {
    const rawPairs = asArray(this._languageConfiguration?.bracketPairs);
    if (rawPairs.length === 0) {
      return;
    }

    const pairs = [];
    rawPairs.forEach((pair) => {
      const openText = String(pair.open ?? "");
      const closeText = String(pair.close ?? "");
      if (!openText || !closeText) {
        return;
      }

      const open = openText.codePointAt(0);
      const close = closeText.codePointAt(0);
      if (!Number.isFinite(open) || !Number.isFinite(close)) {
        return;
      }

      pairs.push({
        open,
        close,
        autoClose: pair.autoClose ?? pair.auto_close ?? true,
        surround: pair.surround ?? true,
      });
    });

    if (pairs.length > 0) {
      try {
        this._core.setBracketPairs(pairs);
      } catch (error) {
        if (!this._bracketPairsUnsupportedLogged) {
          this._bracketPairsUnsupportedLogged = true;
          console.warn("setBracketPairs unavailable in current wasm runtime; continuing without language bracket pairs.", error);
        }
      }
    }
  }

  _createContextMenu() {
    const menu = document.createElement("div");
    menu.style.position = "absolute";
    menu.style.display = "none";
    menu.style.zIndex = "32";
    menu.style.minWidth = "156px";
    menu.style.padding = "4px";
    menu.style.borderRadius = "8px";
    menu.style.border = "1px solid rgba(255,255,255,0.12)";
    menu.style.background = "#1f2937";
    menu.style.boxShadow = "0 12px 28px rgba(0,0,0,0.35)";
    menu.style.userSelect = "none";
    menu.style.fontFamily = "ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif";
    menu.style.fontSize = "13px";
    menu.style.pointerEvents = "auto";

    const entries = ["undo", "redo", "-", "cut", "copy", "paste", "-", "selectAll"];
    entries.forEach((entry) => {
      if (entry === "-") {
        const separator = document.createElement("div");
        separator.style.height = "1px";
        separator.style.margin = "4px 6px";
        separator.style.background = "rgba(255,255,255,0.16)";
        menu.appendChild(separator);
        return;
      }

      const button = document.createElement("button");
      button.type = "button";
      button.dataset.action = entry;
      button.style.display = "block";
      button.style.width = "100%";
      button.style.textAlign = "left";
      button.style.border = "none";
      button.style.background = "transparent";
      button.style.color = "#f3f4f6";
      button.style.padding = "7px 10px";
      button.style.borderRadius = "6px";
      button.style.cursor = "pointer";
      button.style.font = "inherit";
      button.addEventListener("mouseenter", () => {
        if (!button.disabled) {
          button.style.background = "rgba(255,255,255,0.12)";
        }
      });
      button.addEventListener("mouseleave", () => {
        button.style.background = "transparent";
      });
      button.addEventListener("click", async (evt) => {
        evt.preventDefault();
        evt.stopPropagation();
        await this._runContextAction(entry);
        this._hideContextMenu();
        this._input.focus();
      });
      menu.appendChild(button);
      this._contextMenuButtons[entry] = button;
    });

    this._contextMenu = menu;
    this.container.appendChild(menu);
    this._refreshContextMenuLabels();
  }

  _refreshContextMenuLabels() {
    if (!this._contextMenuButtons) return;
    const labels = this._i18n || CONTEXT_MENU_I18N.en;
    Object.entries(this._contextMenuButtons).forEach(([key, button]) => {
      button.textContent = labels[key] || key;
    });
  }

  _setContextMenuItemDisabled(action, disabled) {
    const button = this._contextMenuButtons[action];
    if (!button) return;
    button.disabled = !!disabled;
    button.style.opacity = disabled ? "0.45" : "1";
    button.style.cursor = disabled ? "not-allowed" : "pointer";
  }

  _updateContextMenuState() {
    let canUndo = false;
    let canRedo = false;
    let hasSelection = false;
    try {
      canUndo = !!this._core.canUndo();
      canRedo = !!this._core.canRedo();
      hasSelection = !!this._core.hasSelection();
    } catch (_) {
      // ignore
    }

    this._setContextMenuItemDisabled("undo", !canUndo);
    this._setContextMenuItemDisabled("redo", !canRedo);
    this._setContextMenuItemDisabled("cut", !hasSelection);
    this._setContextMenuItemDisabled("copy", !hasSelection);
    const canReadClipboard = typeof navigator !== "undefined" && navigator.clipboard && navigator.clipboard.readText;
    this._setContextMenuItemDisabled("paste", !canReadClipboard);
  }

  _showContextMenu(x, y) {
    if (!this._contextMenu) return;
    const containerRect = this.container.getBoundingClientRect();
    const menu = this._contextMenu;
    menu.style.display = "block";
    menu.style.visibility = "hidden";

    const menuWidth = menu.offsetWidth || 160;
    const menuHeight = menu.offsetHeight || 180;
    const clampedX = Math.max(4, Math.min(x, containerRect.width - menuWidth - 4));
    const clampedY = Math.max(4, Math.min(y, containerRect.height - menuHeight - 4));

    menu.style.left = `${clampedX}px`;
    menu.style.top = `${clampedY}px`;
    menu.style.visibility = "visible";
    this._contextMenuVisible = true;
  }

  _hideContextMenu() {
    if (!this._contextMenu) return;
    this._contextMenu.style.display = "none";
    this._contextMenuVisible = false;
  }

  async _runContextAction(action) {
    switch (action) {
      case "undo": {
        const result = this._core.undo();
        this._handleTextEditResult(result, { action: TextChangeAction.UNDO });
        break;
      }
      case "redo": {
        const result = this._core.redo();
        this._handleTextEditResult(result, { action: TextChangeAction.REDO });
        break;
      }
      case "selectAll":
        this._core.selectAll();
        this._emitStateEventsFromCore({ forceSelection: true, forceCursor: true });
        break;
      case "copy":
        await this._copySelectionToClipboard(false);
        break;
      case "cut":
        await this._copySelectionToClipboard(true);
        break;
      case "paste": {
        const text = await this._readClipboardText();
        if (text) {
          const result = this._core.insert(text);
          this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
        }
        break;
      }
      default:
        break;
    }
  }

  async _copySelectionToClipboard(isCut) {
    if (!this._core.hasSelection()) return;
    const selectedText = this._core.getSelectedText() || "";
    if (!selectedText) return;

    const copied = await this._writeClipboardText(selectedText);
    if (isCut && copied) {
      const selection = this._core.getSelection();
      if (selection) {
        const result = this._core.deleteText(selection);
        this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
      }
    }
  }

  async _writeClipboardText(text) {
    if (typeof navigator !== "undefined" && navigator.clipboard && navigator.clipboard.writeText) {
      try {
        await navigator.clipboard.writeText(text);
        return true;
      } catch (_) {
        // fall through
      }
    }

    try {
      const previous = this._input.value;
      this._input.value = text;
      this._input.focus();
      this._input.select();
      const ok = document.execCommand("copy");
      this._input.value = previous || "";
      return !!ok;
    } catch (_) {
      return false;
    }
  }

  async _readClipboardText() {
    if (!(typeof navigator !== "undefined" && navigator.clipboard && navigator.clipboard.readText)) {
      return "";
    }
    try {
      return await navigator.clipboard.readText();
    } catch (_) {
      return "";
    }
  }

  _handleClipboardCopyCut(event, isCut) {
    if (!this._core.hasSelection()) {
      return;
    }

    const selectedText = this._core.getSelectedText() || "";
    if (!selectedText) {
      return;
    }

    if (event.clipboardData && event.clipboardData.setData) {
      event.clipboardData.setData("text/plain", selectedText);
      event.preventDefault();
      if (isCut) {
        const selection = this._core.getSelection();
        if (selection) {
          const result = this._core.deleteText(selection);
          this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
        }
      }
      return;
    }

    void this._copySelectionToClipboard(isCut);
    event.preventDefault();
  }

  _handleClipboardPaste(event) {
    this._invalidatePrintableFallback();
    if (!event.clipboardData || !event.clipboardData.getData) {
      return;
    }
    const text = event.clipboardData.getData("text/plain") || "";
    if (!text) {
      return;
    }

    const result = this._core.insert(text);
    this._handleTextEditResult(result, { action: TextChangeAction.INSERT });
    this._suppressNextInputOnce();
    event.preventDefault();
  }
}
