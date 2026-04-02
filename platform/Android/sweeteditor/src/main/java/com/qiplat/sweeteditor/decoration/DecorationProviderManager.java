package com.qiplat.sweeteditor.decoration;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.util.SparseArray;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.EditorSettings;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.adornment.PhantomText;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

public final class DecorationProviderManager {
    private static final String TAG = "DecorationProviderMgr";

    private final SweetEditor editor;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final CopyOnWriteArrayList<DecorationProvider> providers = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<DecorationProvider, ProviderState> providerStates = new ConcurrentHashMap<>();

    private final Runnable refreshRunnable = this::doRefresh;
    private final Runnable applyRunnable = this::applyMerged;
    private volatile boolean pendingScrollRefresh;
    private final Runnable scrollRefreshRunnable = () -> {
        scrollRefreshScheduled = false;
        mainHandler.removeCallbacks(refreshRunnable);
        doRefresh();
        lastScrollRefreshUptimeMs = SystemClock.uptimeMillis();
        if (pendingScrollRefresh) {
            pendingScrollRefresh = false;
            scheduleScrollRefresh();
        }
    };

    private final List<EditorCore.TextChange> pendingTextChanges = new ArrayList<>();
    private volatile boolean applyScheduled;
    private volatile int generation;
    private volatile int lastVisibleStartLine;
    private volatile int lastVisibleEndLine = -1;
    private volatile boolean scrollRefreshScheduled;
    private volatile long lastScrollRefreshUptimeMs;

    public DecorationProviderManager(@NonNull SweetEditor editor) {
        this.editor = editor;
    }

    public void addProvider(@NonNull DecorationProvider provider) {
        if (!providers.contains(provider)) {
            providers.add(provider);
            providerStates.put(provider, new ProviderState());
            requestRefresh();
        }
    }

    public void removeProvider(@NonNull DecorationProvider provider) {
        providers.remove(provider);
        ProviderState state = providerStates.remove(provider);
        if (state != null && state.activeReceiver != null) {
            state.activeReceiver.cancel();
        }
        scheduleApply();
    }

    public void requestRefresh() {
        scheduleRefresh(0, null);
    }

    public void onDocumentLoaded() {
        scheduleRefresh(0, null);
    }

    public void onTextChanged(@NonNull List<EditorCore.TextChange> changes) {
        scheduleRefresh(50, changes);
    }

    public void onScrollChanged() {
        scheduleScrollRefresh();
    }

    private void scheduleRefresh(long delayMs, @Nullable List<EditorCore.TextChange> changes) {
        if (changes != null) {
            pendingTextChanges.addAll(changes);
        }
        mainHandler.removeCallbacks(refreshRunnable);
        mainHandler.postDelayed(refreshRunnable, delayMs);
    }

    private void scheduleScrollRefresh() {
        long now = SystemClock.uptimeMillis();
        long elapsed = now - lastScrollRefreshUptimeMs;
        long minInterval = getScrollRefreshMinIntervalMs();
        long delay = elapsed >= minInterval
                ? 0L
                : (minInterval - elapsed);
        if (scrollRefreshScheduled) {
            pendingScrollRefresh = true;
            return;
        }
        scrollRefreshScheduled = true;
        mainHandler.postDelayed(scrollRefreshRunnable, delay);
    }

    private void doRefresh() {
        generation++;
        int currentGeneration = generation;

        int[] visible = editor.getVisibleLineRange();
        lastVisibleStartLine = visible[0];
        lastVisibleEndLine = visible[1];
        int total = editor.getTotalLineCount();
        List<EditorCore.TextChange> changes = new ArrayList<>(pendingTextChanges);
        pendingTextChanges.clear();
        int contextStart = visible[0];
        int contextEnd = visible[1];
        if (total > 0 && visible[1] >= visible[0]) {
            int overscanLines = calculateOverscanLines(visible[0], visible[1]);
            contextStart = Math.max(0, visible[0] - overscanLines);
            contextEnd = Math.min(total - 1, visible[1] + overscanLines);
        }
        DecorationContext context = new DecorationContext(
                contextStart,
                contextEnd,
                total,
                changes,
                editor.getLanguageConfiguration(),
                editor.getMetadata());

        for (DecorationProvider provider : providers) {
            ProviderState state = providerStates.get(provider);
            if (state == null) {
                state = new ProviderState();
                providerStates.put(provider, state);
            }
            if (state.activeReceiver != null) {
                state.activeReceiver.cancel();
            }
            ManagedReceiver receiver = new ManagedReceiver(provider, currentGeneration);
            state.activeReceiver = receiver;
            try {
                provider.provideDecorations(context, receiver);
            } catch (Throwable t) {
                Log.e(TAG, "provider failed", t);
            }
        }
    }

    private void scheduleApply() {
        if (applyScheduled) return;
        applyScheduled = true;
        mainHandler.post(applyRunnable);
    }

    private void applyMerged() {
        applyScheduled = false;

        SparseArray<List<StyleSpan>> syntaxSpans = new SparseArray<>();
        SparseArray<List<StyleSpan>> semanticSpans = new SparseArray<>();
        SparseArray<List<InlayHint>> inlayHints = new SparseArray<>();
        SparseArray<List<Diagnostic>> diagnostics = new SparseArray<>();
        List<IndentGuide> indentGuides = null;
        List<BracketGuide> bracketGuides = null;
        List<FlowGuide> flowGuides = null;
        List<SeparatorGuide> separatorGuides = null;
        List<FoldRegion> foldRegions = new ArrayList<>();
        SparseArray<List<GutterIcon>> gutterIcons = new SparseArray<>();
        SparseArray<List<PhantomText>> phantomTexts = new SparseArray<>();
        DecorationResult.ApplyMode syntaxMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode semanticMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode inlayMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode diagnosticMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode indentMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode bracketMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode flowMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode separatorMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode foldMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode gutterMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode phantomMode = DecorationResult.ApplyMode.MERGE;

        for (DecorationProvider provider : providers) {
            ProviderState state = providerStates.get(provider);
            if (state == null || state.snapshot == null) continue;
            DecorationResult r = state.snapshot;

            syntaxMode = mergeMode(syntaxMode, r.getSyntaxSpansMode());
            if (r.getSyntaxSpans() != null) {
                appendSparseArrayOfList(syntaxSpans, r.getSyntaxSpans());
            }
            semanticMode = mergeMode(semanticMode, r.getSemanticSpansMode());
            if (r.getSemanticSpans() != null) {
                appendSparseArrayOfList(semanticSpans, r.getSemanticSpans());
            }
            inlayMode = mergeMode(inlayMode, r.getInlayHintsMode());
            if (r.getInlayHints() != null) {
                appendSparseArrayOfList(inlayHints, r.getInlayHints());
            }
            diagnosticMode = mergeMode(diagnosticMode, r.getDiagnosticsMode());
            if (r.getDiagnostics() != null) {
                appendSparseArrayOfList(diagnostics, r.getDiagnostics());
            }
            gutterMode = mergeMode(gutterMode, r.getGutterIconsMode());
            if (r.getGutterIcons() != null) {
                appendSparseArrayOfList(gutterIcons, r.getGutterIcons());
            }
            phantomMode = mergeMode(phantomMode, r.getPhantomTextsMode());
            if (r.getPhantomTexts() != null) {
                appendSparseArrayOfList(phantomTexts, r.getPhantomTexts());
            }

            indentMode = mergeMode(indentMode, r.getIndentGuidesMode());
            if (r.getIndentGuides() != null) {
                indentGuides = new ArrayList<>(r.getIndentGuides());
            }
            bracketMode = mergeMode(bracketMode, r.getBracketGuidesMode());
            if (r.getBracketGuides() != null) {
                bracketGuides = new ArrayList<>(r.getBracketGuides());
            }
            flowMode = mergeMode(flowMode, r.getFlowGuidesMode());
            if (r.getFlowGuides() != null) {
                flowGuides = new ArrayList<>(r.getFlowGuides());
            }
            separatorMode = mergeMode(separatorMode, r.getSeparatorGuidesMode());
            if (r.getSeparatorGuides() != null) {
                separatorGuides = new ArrayList<>(r.getSeparatorGuides());
            }
            foldMode = mergeMode(foldMode, r.getFoldRegionsMode());
            if (r.getFoldRegions() != null) {
                foldRegions.addAll(r.getFoldRegions());
            }
        }

        applySpanMode(SpanLayer.SYNTAX, syntaxMode);
        applySpanMode(SpanLayer.SEMANTIC, semanticMode);
        editor.setBatchLineSpans(SpanLayer.SYNTAX, syntaxSpans);
        editor.setBatchLineSpans(SpanLayer.SEMANTIC, semanticSpans);

        applyInlayMode(inlayMode);
        editor.setBatchLineInlayHints(inlayHints);

        applyDiagnosticMode(diagnosticMode);
        editor.setBatchLineDiagnostics(diagnostics);

        applyGuidesMode(indentMode, indentGuides, 0);
        applyGuidesMode(bracketMode, bracketGuides, 1);
        applyGuidesMode(flowMode, flowGuides, 2);
        applyGuidesMode(separatorMode, separatorGuides, 3);

        if (foldMode == DecorationResult.ApplyMode.REPLACE_ALL || foldMode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            editor.setFoldRegions(foldRegions);
        } else if (!foldRegions.isEmpty()) {
            editor.setFoldRegions(foldRegions);
        }

        applyGutterMode(gutterMode);
        editor.setBatchLineGutterIcons(gutterIcons);

        applyPhantomMode(phantomMode);
        editor.setBatchLinePhantomTexts(phantomTexts);

        editor.flush();
    }

    private void applySpanMode(@NonNull SpanLayer layer, @NonNull DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearHighlights(layer);
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearSpanRange(layer, lastVisibleStartLine, lastVisibleEndLine);
        }
    }

    private void applyInlayMode(@NonNull DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearInlayHints();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearInlayRange(lastVisibleStartLine, lastVisibleEndLine);
        }
    }

    private void applyDiagnosticMode(@NonNull DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearDiagnostics();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearDiagnosticRange(lastVisibleStartLine, lastVisibleEndLine);
        }
    }

    private void applyGutterMode(@NonNull DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearGutterIcons();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearGutterRange(lastVisibleStartLine, lastVisibleEndLine);
        }
    }

    private void applyPhantomMode(@NonNull DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearPhantomTexts();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearPhantomRange(lastVisibleStartLine, lastVisibleEndLine);
        }
    }

    @SuppressWarnings("unchecked")
    private void applyGuidesMode(@NonNull DecorationResult.ApplyMode mode, @Nullable List<?> data, int guideType) {
        switch (guideType) {
            case 0:
                if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
                    editor.setIndentGuides(data == null ? Collections.emptyList() : (List<IndentGuide>) data);
                } else if (data != null) {
                    editor.setIndentGuides((List<IndentGuide>) data);
                }
                break;
            case 1:
                if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
                    editor.setBracketGuides(data == null ? Collections.emptyList() : (List<BracketGuide>) data);
                } else if (data != null) {
                    editor.setBracketGuides((List<BracketGuide>) data);
                }
                break;
            case 2:
                if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
                    editor.setFlowGuides(data == null ? Collections.emptyList() : (List<FlowGuide>) data);
                } else if (data != null) {
                    editor.setFlowGuides((List<FlowGuide>) data);
                }
                break;
            case 3:
                if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
                    editor.setSeparatorGuides(data == null ? Collections.emptyList() : (List<SeparatorGuide>) data);
                } else if (data != null) {
                    editor.setSeparatorGuides((List<SeparatorGuide>) data);
                }
                break;
            default:
                break;
        }
    }

    private static DecorationResult.ApplyMode mergeMode(@NonNull DecorationResult.ApplyMode current, @NonNull DecorationResult.ApplyMode next) {
        if (priority(next) > priority(current)) return next;
        return current;
    }

    private static int priority(@NonNull DecorationResult.ApplyMode mode) {
        switch (mode) {
            case MERGE:
                return 0;
            case REPLACE_RANGE:
                return 1;
            case REPLACE_ALL:
                return 2;
            default:
                return 0;
        }
    }

    private long getScrollRefreshMinIntervalMs() {
        EditorSettings settings = editor.getSettings();
        return Math.max(0L, settings.getDecorationScrollRefreshMinIntervalMs());
    }

    private int calculateOverscanLines(int visibleStart, int visibleEnd) {
        int viewportLineCount = visibleEnd >= visibleStart ? (visibleEnd - visibleStart + 1) : 0;
        if (viewportLineCount <= 0) return 0;
        EditorSettings settings = editor.getSettings();
        float multiplier = Math.max(0f, settings.getDecorationOverscanViewportMultiplier());
        return Math.max(0, (int) Math.ceil(viewportLineCount * multiplier));
    }

    private void clearSpanRange(@NonNull SpanLayer layer, int startLine, int endLine) {
        SparseArray<List<StyleSpan>> empty = buildEmptySparseRange(startLine, endLine);
        if (empty.size() == 0) return;
        editor.setBatchLineSpans(layer, empty);
    }

    private void clearInlayRange(int startLine, int endLine) {
        SparseArray<List<InlayHint>> empty = buildEmptySparseRange(startLine, endLine);
        if (empty.size() == 0) return;
        editor.setBatchLineInlayHints(empty);
    }

    private void clearDiagnosticRange(int startLine, int endLine) {
        SparseArray<List<Diagnostic>> empty = buildEmptySparseRange(startLine, endLine);
        if (empty.size() == 0) return;
        editor.setBatchLineDiagnostics(empty);
    }

    private void clearGutterRange(int startLine, int endLine) {
        SparseArray<List<GutterIcon>> empty = buildEmptySparseRange(startLine, endLine);
        if (empty.size() == 0) return;
        editor.setBatchLineGutterIcons(empty);
    }

    private void clearPhantomRange(int startLine, int endLine) {
        SparseArray<List<PhantomText>> empty = buildEmptySparseRange(startLine, endLine);
        if (empty.size() == 0) return;
        editor.setBatchLinePhantomTexts(empty);
    }

    @NonNull
    private static <T> SparseArray<List<T>> buildEmptySparseRange(int startLine, int endLine) {
        SparseArray<List<T>> out = new SparseArray<>();
        if (endLine < startLine) return out;
        for (int line = startLine; line <= endLine; line++) {
            out.put(line, Collections.<T>emptyList());
        }
        return out;
    }

    private static <T> void appendSparseArrayOfList(SparseArray<List<T>> out, @Nullable SparseArray<List<T>> patch) {
        if (patch == null) return;
        for (int i = 0, size = patch.size(); i < size; i++) {
            int key = patch.keyAt(i);
            List<T> src = patch.valueAt(i);
            if (src == null) src = Collections.emptyList();
            List<T> target = out.get(key);
            if (target == null) {
                target = new ArrayList<>();
                out.put(key, target);
            }
            target.addAll(src);
        }
    }

    private final class ManagedReceiver implements DecorationReceiver {
        private final DecorationProvider provider;
        private final int receiverGeneration;
        private volatile boolean cancelled;

        private ManagedReceiver(DecorationProvider provider, int receiverGeneration) {
            this.provider = provider;
            this.receiverGeneration = receiverGeneration;
        }

        @Override
        public boolean accept(@NonNull DecorationResult result) {
            if (cancelled || receiverGeneration != generation) return false;
            DecorationResult snapshot = result.copy();
            mainHandler.post(() -> {
                if (cancelled || receiverGeneration != generation) return;
                ProviderState state = providerStates.get(provider);
                if (state == null) {
                    state = new ProviderState();
                    providerStates.put(provider, state);
                }
                mergePatch(state, snapshot);
                scheduleApply();
            });
            return true;
        }

        @Override
        public boolean isCancelled() {
            return cancelled || receiverGeneration != generation;
        }

        void cancel() {
            cancelled = true;
        }
    }

    private void mergePatch(@NonNull ProviderState state, @NonNull DecorationResult patch) {
        if (state.snapshot == null) {
            state.snapshot = new DecorationResult();
        }
        DecorationResult target = state.snapshot;

        if (patch.getSyntaxSpans() != null) {
            target.setSyntaxSpans(patch.getSyntaxSpans());
            target.setSyntaxSpansMode(patch.getSyntaxSpansMode());
        } else if (patch.getSyntaxSpansMode() != DecorationResult.ApplyMode.MERGE) {
            target.setSyntaxSpans(null);
            target.setSyntaxSpansMode(patch.getSyntaxSpansMode());
        }
        if (patch.getSemanticSpans() != null) {
            target.setSemanticSpans(patch.getSemanticSpans());
            target.setSemanticSpansMode(patch.getSemanticSpansMode());
        } else if (patch.getSemanticSpansMode() != DecorationResult.ApplyMode.MERGE) {
            target.setSemanticSpans(null);
            target.setSemanticSpansMode(patch.getSemanticSpansMode());
        }
        if (patch.getInlayHints() != null) {
            target.setInlayHints(patch.getInlayHints());
            target.setInlayHintsMode(patch.getInlayHintsMode());
        } else if (patch.getInlayHintsMode() != DecorationResult.ApplyMode.MERGE) {
            target.setInlayHints(null);
            target.setInlayHintsMode(patch.getInlayHintsMode());
        }
        if (patch.getDiagnostics() != null) {
            target.setDiagnostics(patch.getDiagnostics());
            target.setDiagnosticsMode(patch.getDiagnosticsMode());
        } else if (patch.getDiagnosticsMode() != DecorationResult.ApplyMode.MERGE) {
            target.setDiagnostics(null);
            target.setDiagnosticsMode(patch.getDiagnosticsMode());
        }
        if (patch.getIndentGuides() != null) {
            target.setIndentGuides(patch.getIndentGuides());
            target.setIndentGuidesMode(patch.getIndentGuidesMode());
        } else if (patch.getIndentGuidesMode() != DecorationResult.ApplyMode.MERGE) {
            target.setIndentGuides(null);
            target.setIndentGuidesMode(patch.getIndentGuidesMode());
        }
        if (patch.getBracketGuides() != null) {
            target.setBracketGuides(patch.getBracketGuides());
            target.setBracketGuidesMode(patch.getBracketGuidesMode());
        } else if (patch.getBracketGuidesMode() != DecorationResult.ApplyMode.MERGE) {
            target.setBracketGuides(null);
            target.setBracketGuidesMode(patch.getBracketGuidesMode());
        }
        if (patch.getFlowGuides() != null) {
            target.setFlowGuides(patch.getFlowGuides());
            target.setFlowGuidesMode(patch.getFlowGuidesMode());
        } else if (patch.getFlowGuidesMode() != DecorationResult.ApplyMode.MERGE) {
            target.setFlowGuides(null);
            target.setFlowGuidesMode(patch.getFlowGuidesMode());
        }
        if (patch.getSeparatorGuides() != null) {
            target.setSeparatorGuides(patch.getSeparatorGuides());
            target.setSeparatorGuidesMode(patch.getSeparatorGuidesMode());
        } else if (patch.getSeparatorGuidesMode() != DecorationResult.ApplyMode.MERGE) {
            target.setSeparatorGuides(null);
            target.setSeparatorGuidesMode(patch.getSeparatorGuidesMode());
        }
        if (patch.getFoldRegions() != null) {
            target.setFoldRegions(patch.getFoldRegions());
            target.setFoldRegionsMode(patch.getFoldRegionsMode());
        } else if (patch.getFoldRegionsMode() != DecorationResult.ApplyMode.MERGE) {
            target.setFoldRegions(null);
            target.setFoldRegionsMode(patch.getFoldRegionsMode());
        }
        if (patch.getGutterIcons() != null) {
            target.setGutterIcons(patch.getGutterIcons());
            target.setGutterIconsMode(patch.getGutterIconsMode());
        } else if (patch.getGutterIconsMode() != DecorationResult.ApplyMode.MERGE) {
            target.setGutterIcons(null);
            target.setGutterIconsMode(patch.getGutterIconsMode());
        }
        if (patch.getPhantomTexts() != null) {
            target.setPhantomTexts(patch.getPhantomTexts());
            target.setPhantomTextsMode(patch.getPhantomTextsMode());
        } else if (patch.getPhantomTextsMode() != DecorationResult.ApplyMode.MERGE) {
            target.setPhantomTexts(null);
            target.setPhantomTextsMode(patch.getPhantomTextsMode());
        }
    }

    private static final class ProviderState {
        DecorationResult snapshot;
        ManagedReceiver activeReceiver;
    }
}
