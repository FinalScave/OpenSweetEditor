import { EditorEventType } from "../index.js?v=20260326_27";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
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

function waitFrame() {
  return new Promise((resolve) => requestAnimationFrame(() => resolve()));
}

function waitTimerTick() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function makeKeyEvent(key, overrides = {}) {
  const event = {
    key,
    keyCode: 0,
    ctrlKey: false,
    metaKey: false,
    altKey: false,
    shiftKey: false,
    isComposing: false,
    preventDefault() {},
    stopPropagation() {},
  };
  return { ...event, ...overrides };
}

function makeInputEvent(inputType, data, overrides = {}) {
  const event = {
    inputType,
    data,
    isComposing: false,
    preventDefault() {},
  };
  return { ...event, ...overrides };
}

function resetInputPipelineState(editor) {
  editor._isComposing = false;
  editor._compositionCommitPending = false;
  editor._compositionEndFallbackData = "";
  editor._input.value = "";
  if (typeof editor._invalidatePrintableFallback === "function") {
    editor._invalidatePrintableFallback();
  }
}

function getPixel(ctx, x, y) {
  const canvas = ctx.canvas;
  const cssWidth = Math.max(1, Number(canvas.clientWidth) || Number(canvas.width) || 1);
  const cssHeight = Math.max(1, Number(canvas.clientHeight) || Number(canvas.height) || 1);
  const dprX = (Number(canvas.width) || cssWidth) / cssWidth;
  const dprY = (Number(canvas.height) || cssHeight) / cssHeight;
  const maxX = Math.max(0, (Number(canvas.width) || 1) - 1);
  const maxY = Math.max(0, (Number(canvas.height) || 1) - 1);
  const sampleX = Math.max(0, Math.min(maxX, Math.floor(x * dprX)));
  const sampleY = Math.max(0, Math.min(maxY, Math.floor(y * dprY)));
  const data = ctx.getImageData(sampleX, sampleY, 1, 1).data;
  return {
    r: data[0],
    g: data[1],
    b: data[2],
    a: data[3],
  };
}

function pixelNotBackground(pixel, threshold = 12) {
  return pixel.a > 0 && (pixel.r > threshold || pixel.g > threshold || pixel.b > threshold);
}

function unpackArgb(color) {
  const value = Number(color) >>> 0;
  return {
    r: (value >>> 16) & 0xff,
    g: (value >>> 8) & 0xff,
    b: value & 0xff,
  };
}

function pixelNearColor(pixel, rgb, tolerance = 96) {
  const dr = Math.abs(pixel.r - rgb.r);
  const dg = Math.abs(pixel.g - rgb.g);
  const db = Math.abs(pixel.b - rgb.b);
  return pixel.a > 0 && dr <= tolerance && dg <= tolerance && db <= tolerance;
}

export async function runWebApiSmoke(editor) {
  assert(editor && typeof editor === "object", "editor instance is required");

  const requiredMethods = [
    "insert",
    "replace",
    "delete",
    "undo",
    "redo",
    "setSelection",
    "setCursorPosition",
    "gotoPosition",
    "setScroll",
    "toggleFoldAt",
    "insertSnippet",
    "clearAllDecorations",
    "setLineInlayHints",
    "setBatchLineInlayHints",
    "setLineGutterIcons",
    "setBatchLineGutterIcons",
    "setLineDiagnostics",
    "setBatchLineDiagnostics",
    "setIndentGuides",
    "setFoldRegions",
    "subscribe",
    "unsubscribe",
    "getSettings",
    "applyTheme",
    "getTheme",
    "setEditorIconProvider",
  ];
  requiredMethods.forEach((name) => {
    assert(typeof editor[name] === "function", `missing method: ${name}`);
  });

  assert(!!editor._performanceOverlay, "performance overlay not mounted");
  assert(editor._performanceOverlay.style.pointerEvents === "none", "performance overlay should not block input");

  const eventCounters = Object.create(null);
  const subs = [];
  Object.values(EditorEventType).forEach((eventType) => {
    eventCounters[eventType] = 0;
    subs.push(editor.subscribe(eventType, () => {
      eventCounters[eventType] += 1;
    }));
  });

  editor.loadText("alpha\nbeta\ngamma");
  editor.insert("!");
  editor.undo();
  editor.redo();
  editor.setSelection(0, 0, 0, 2);
  editor.clearSelection();
  editor.setScroll(0, 60);
  editor.setScale(1.1);
  editor.setFoldRegions([{ startLine: 0, endLine: 1, collapsed: false }]);
  editor.toggleFoldAt(0);
  editor.toggleFoldAt(0);

  // Input regression A: insertText should still commit even when isComposing=true.
  editor.loadText("");
  resetInputPipelineState(editor);
  editor._onInput(makeInputEvent("insertText", "a", { isComposing: true }));
  assert(editor.getText() === "a", "regression A failed: insertText with isComposing=true should insert english");

  // Input regression B: composition input must not pre-commit, insertFromComposition commits final text.
  editor.loadText("");
  resetInputPipelineState(editor);
  editor.getCore().compositionStart();
  editor._isComposing = true;
  editor.getCore().compositionUpdate("ce");
  const beforeCompositionInput = editor.getText();
  editor._onInput(makeInputEvent("insertCompositionText", "ce", { isComposing: true }));
  assert(editor.getText() === beforeCompositionInput, "regression B failed: composition update should stay transient");
  editor._isComposing = false;
  editor._compositionCommitPending = true;
  editor._compositionEndFallbackData = "\u6D4B";
  editor._onInput(makeInputEvent("insertFromComposition", "\u6D4B"));
  assert(editor.getText() === "\u6D4B", "regression B failed: insertFromComposition should commit final text");

  // Input regression C: printable key fallback should insert when no input event arrives.
  editor.loadText("");
  resetInputPipelineState(editor);
  editor._onKeyDown(makeKeyEvent("b", { keyCode: 229 }));
  await waitTimerTick();
  assert(editor.getText() === "b", "regression C failed: keydown fallback should insert printable english");

  // Input regression D: keydown fallback + input must not double-insert.
  editor.loadText("");
  resetInputPipelineState(editor);
  editor._onKeyDown(makeKeyEvent("c", { keyCode: 229 }));
  editor._onInput(makeInputEvent("insertText", "c"));
  await waitTimerTick();
  assert(editor.getText() === "c", "regression D failed: fallback path should dedupe with input event");

  // Input regression E: document keydown should forward Enter to _onKeyDown when textarea is focused.
  let enterForwarded = false;
  const originalOnKeyDown = editor._onKeyDown.bind(editor);
  editor._onKeyDown = (event) => {
    enterForwarded = true;
    return originalOnKeyDown(event);
  };
  editor._input.focus();
  editor._documentKeyRouteActive = true;
  editor._handleDocumentKeyDown(makeKeyEvent("Enter", { keyCode: 13, target: document.body }));
  editor._onKeyDown = originalOnKeyDown;
  assert(enterForwarded, "regression E failed: Enter in document handler should forward to _onKeyDown");

  // Input regression F: spurious empty composing input must not cancel printable fallback insertion.
  editor.loadText("");
  resetInputPipelineState(editor);
  editor._onKeyDown(makeKeyEvent("d", { keyCode: 229 }));
  editor._onInput(makeInputEvent("", "", { isComposing: true }));
  await waitTimerTick();
  assert(editor.getText() === "d", "regression F failed: empty composing input should not cancel printable fallback");

  // Input regression G: Enter must not race ahead while composition commit is pending.
  editor.loadText("");
  resetInputPipelineState(editor);
  editor.getCore().compositionStart();
  editor.getCore().compositionUpdate("shi");
  editor._isComposing = false;
  editor._compositionCommitPending = true;
  editor._compositionEndFallbackData = "\u8BD5";
  editor._onKeyDown(makeKeyEvent("Enter", { keyCode: 13 }));
  assert(editor.getText() === "", "regression G failed: Enter should not insert newline while composition commit is pending");
  editor._onInput(makeInputEvent("insertFromComposition", "\u8BD5"));
  assert(editor.getText() === "\u8BD5", "regression G failed: pending composition should commit normally");

  // Input regression H: legacy keyCode Enter should still work when key is unrecognized.
  editor.loadText("");
  resetInputPipelineState(editor);
  editor._onKeyDown(makeKeyEvent("Unidentified", { keyCode: 13, which: 13 }));
  assert(editor.getText() === "\n", "regression H failed: legacy Enter keyCode should insert newline");

  editor.loadText("alpha\nbeta\ngamma");

  editor.setEditorIconProvider((iconId) => {
    if (iconId === 2001) return { color: 0xFFFFD166 };
    if (iconId === 3001) return { color: 0xFFFF5A5F };
    return { color: 0xFF9CA3AF };
  });
  editor.setLineGutterIcons(0, [{ iconId: 2001 }]);
  editor.setLineInlayHints(0, [
    { type: 1, column: 1, iconId: 3001 },
    { type: 2, column: 2, color: 0xFF34D399 },
  ]);
  editor.setLineDiagnostics(0, [{ column: 0, length: 2, severity: 0, color: 0 }]);

  // Ensure sampling happens with the decorated line in viewport.
  editor.setScroll(0, 0);
  editor.gotoPosition(0, 0);

  await waitFrame();
  await waitFrame();

  const container = editor.container;
  const canvas = container.querySelector("canvas");
  assert(!!canvas, "canvas not found");
  const ctx = canvas.getContext("2d");
  assert(!!ctx, "2d context not found");

  const model = editor.getCore().buildRenderModel();
  assert(!!model, "render model unavailable");

  let gutterSampleOk = false;
  const gutterIcons = model.gutter_icons;
  if (gutterIcons && typeof gutterIcons.size === "function" && gutterIcons.size() > 0) {
    const first = gutterIcons.get(0);
    const px = getPixel(
      ctx,
      (Number(first.origin?.x) || 0) + (Number(first.width) || 0) * 0.5,
      (Number(first.origin?.y) || 0) + (Number(first.height) || 0) * 0.5,
    );
    gutterSampleOk = pixelNotBackground(px);
  }

  let inlayColorSampleOk = false;
  let inlayColorRunCount = 0;
  const inlayDebugSamples = [];
  const lines = model.lines;
  if (lines && typeof lines.size === "function" && lines.size() > 0) {
    for (let i = 0; i < lines.size() && !inlayColorSampleOk; i += 1) {
      const line = lines.get(i);
      const runs = line?.runs;
      if (!runs || typeof runs.size !== "function") continue;
      for (let j = 0; j < runs.size(); j += 1) {
        const run = runs.get(j);
        if (toInt(run?.type, -1) === 3 && toInt(run?.color_value, 0) !== 0) {
          inlayColorRunCount += 1;
          const target = unpackArgb(run.color_value);
          const margin = Math.max(0, Number(run.margin) || 0);
          const left = (Number(run.x) || 0) + margin;
          const right = left + Math.max(4, (Number(run.width) || 0) - margin * 2);
          const top = (Number(run.y) || 0) - 20;
          const bottom = (Number(run.y) || 0) + 2;

          for (let sx = 0; sx < 7 && !inlayColorSampleOk; sx += 1) {
            for (let sy = 0; sy < 7 && !inlayColorSampleOk; sy += 1) {
              const sampleX = left + ((right - left) * sx) / 6;
              const sampleY = top + ((bottom - top) * sy) / 6;
              const px = getPixel(ctx, sampleX, sampleY);
              if (inlayDebugSamples.length < 8) {
                inlayDebugSamples.push({
                  x: Math.round(sampleX),
                  y: Math.round(sampleY),
                  pixel: px,
                });
              }
              if (pixelNearColor(px, target) || pixelNotBackground(px, 20)) {
                inlayColorSampleOk = true;
              }
            }
          }
        }
      }
    }
  }

  subs.forEach((dispose) => dispose());

  assert(eventCounters[EditorEventType.TEXT_CHANGED] > 0, "TextChanged not fired");
  assert(eventCounters[EditorEventType.CURSOR_CHANGED] > 0, "CursorChanged not fired");
  assert(eventCounters[EditorEventType.SELECTION_CHANGED] > 0, "SelectionChanged not fired");
  assert(eventCounters[EditorEventType.SCROLL_CHANGED] > 0, "ScrollChanged not fired");
  assert(eventCounters[EditorEventType.SCALE_CHANGED] > 0, "ScaleChanged not fired");
  assert(gutterSampleOk, "gutter icon render sample failed");
  assert(
    inlayColorSampleOk,
    `inlay color render sample failed (runs=${inlayColorRunCount}, samples=${JSON.stringify(inlayDebugSamples)})`,
  );

  return {
    ok: true,
    events: eventCounters,
    render: {
      gutterSampleOk,
      inlayColorSampleOk,
    },
  };
}
