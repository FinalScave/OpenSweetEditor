package com.qiplat.sweeteditor.decoration;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.DocumentHighlight;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.adornment.CodeLensItem;
import com.qiplat.sweeteditor.core.adornment.LinkSpan;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.TextChange;

import javax.swing.SwingUtilities;
import javax.swing.Timer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

public final class DecorationProviderManager {
    private static final AtomicInteger PROVIDER_THREAD_ID = new AtomicInteger(1);

    private final SweetEditor editor;
    private final CopyOnWriteArrayList<DecorationProvider> providers = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<DecorationProvider, ProviderState> providerStates = new ConcurrentHashMap<>();

    private final Timer debounceTimer;
    private final Timer scrollRefreshTimer;

    private final List<TextChange> pendingTextChanges = new ArrayList<>();
    private volatile boolean applyScheduled;
    private volatile int generation;
    private volatile boolean disposed;
    private volatile IntRange lastVisibleLineRange = new IntRange(0, -1);
    private volatile IntRange lastContextLineRange = new IntRange(0, -1);
    private volatile boolean scrollRefreshScheduled;
    private volatile boolean pendingScrollRefresh;
    private volatile long lastScrollRefreshUptimeMs;

    public DecorationProviderManager(SweetEditor editor) {
        this.editor = editor;
        this.debounceTimer = new Timer(50, e -> doRefresh());
        this.debounceTimer.setRepeats(false);
        this.scrollRefreshTimer = new Timer(1, e -> {
            ((Timer) e.getSource()).stop();
            scrollRefreshScheduled = false;
            debounceTimer.stop();
            doRefresh();
            lastScrollRefreshUptimeMs = System.currentTimeMillis();
            if (pendingScrollRefresh) {
                pendingScrollRefresh = false;
                scheduleScrollRefresh();
            }
        });
        this.scrollRefreshTimer.setRepeats(false);
    }

    public void addProvider(DecorationProvider provider) {
        if (disposed) return;
        runOnEdt(() -> {
            if (disposed) return;
            if (!providers.contains(provider)) {
                providers.add(provider);
                providerStates.put(provider, new ProviderState());
                requestRefresh();
            }
        });
    }

    public void removeProvider(DecorationProvider provider) {
        if (disposed) return;
        runOnEdt(() -> {
            if (disposed) return;
            providers.remove(provider);
            ProviderState state = providerStates.remove(provider);
            if (state != null) {
                if (state.activeReceiver != null) {
                    state.activeReceiver.cancel();
                }
                state.executor.shutdownNow();
            }
            scheduleApply();
        });
    }

    public void requestRefresh() {
        if (disposed) return;
        scheduleRefresh(0, null);
    }

    public void onDocumentLoaded() {
        if (disposed) return;
        scheduleRefresh(0, null);
    }

    public void onTextChanged(List<TextChange> changes) {
        if (disposed) return;
        scheduleRefresh(50, changes);
    }

    public void onScrollChanged() {
        if (disposed) return;
        runOnEdt(this::scheduleScrollRefresh);
    }

    public void close() {
        runOnEdt(() -> {
            if (disposed) return;
            disposed = true;
            generation++;
            debounceTimer.stop();
            scrollRefreshTimer.stop();
            scrollRefreshScheduled = false;
            pendingScrollRefresh = false;
            applyScheduled = false;
            pendingTextChanges.clear();
            lastVisibleLineRange = new IntRange(0, -1);
            lastContextLineRange = new IntRange(0, -1);
            for (ProviderState state : providerStates.values()) {
                if (state.activeReceiver != null) {
                    state.activeReceiver.cancel();
                }
                state.executor.shutdownNow();
            }
            providers.clear();
            providerStates.clear();
        });
    }

    private void scheduleRefresh(int delayMs, List<TextChange> changes) {
        runOnEdt(() -> {
            if (disposed) return;
            if (changes != null) {
                pendingTextChanges.addAll(changes);
            }
            if (scrollRefreshScheduled) {
                scrollRefreshTimer.stop();
                scrollRefreshScheduled = false;
            }
            pendingScrollRefresh = false;
            debounceTimer.stop();
            debounceTimer.setInitialDelay(Math.max(0, delayMs));
            debounceTimer.start();
        });
    }

    private void scheduleScrollRefresh() {
        if (disposed) return;
        long now = System.currentTimeMillis();
        long elapsed = now - lastScrollRefreshUptimeMs;
        int minInterval = getScrollRefreshMinIntervalMs();
        int delay = elapsed >= minInterval
                ? 0
                : (int) (minInterval - elapsed);
        if (scrollRefreshScheduled) {
            pendingScrollRefresh = true;
            return;
        }
        scrollRefreshScheduled = true;
        scrollRefreshTimer.stop();
        scrollRefreshTimer.setInitialDelay(Math.max(0, delay));
        scrollRefreshTimer.start();
    }

    private void doRefresh() {
        if (disposed) return;
        generation++;
        int currentGeneration = generation;

        IntRange visible = editor.getVisibleLineRange();
        lastVisibleLineRange = visible;
        int total = editor.getTotalLineCount();
        List<TextChange> changes = new ArrayList<>(pendingTextChanges);
        pendingTextChanges.clear();
        int contextStart = visible.start;
        int contextEnd = visible.end;
        if (total > 0 && visible.end >= visible.start) {
            int overscanLines = calculateOverscanLines(visible.start, visible.end);
            contextStart = Math.max(0, visible.start - overscanLines);
            contextEnd = Math.min(total - 1, visible.end + overscanLines);
        }
        DecorationContext context = new DecorationContext(
                new IntRange(contextStart, contextEnd),
                total,
                changes,
                editor.getLanguageConfiguration(),
                editor.getMetadata());
        lastContextLineRange = context.visibleLineRange;

        for (DecorationProvider provider : providers) {
            ProviderState state = providerStates.computeIfAbsent(provider, p -> new ProviderState());
            if (state.activeReceiver != null) {
                state.activeReceiver.cancel();
            }
            ManagedReceiver receiver = new ManagedReceiver(provider, currentGeneration);
            state.activeReceiver = receiver;
            try {
                state.executor.execute(() -> {
                    if (receiver.isCancelled()) {
                        return;
                    }
                    try {
                        provider.provideDecorations(context, receiver);
                    } catch (Throwable ignored) {
                    }
                });
            } catch (Throwable ignored) {
            }
        }
    }

    private void scheduleApply() {
        if (disposed) return;
        if (applyScheduled) return;
        applyScheduled = true;
        runOnEdt(this::applyMerged);
    }

    private void applyMerged() {
        if (disposed) return;
        applyScheduled = false;

        Map<Integer, List<StyleSpan>> syntaxSpans = new HashMap<>();
        Map<Integer, List<StyleSpan>> semanticSpans = new HashMap<>();
        Map<Integer, List<StyleSpan>> overlaySpans = new HashMap<>();
        Map<Integer, List<InlayHint>> inlayHints = new HashMap<>();
        Map<Integer, List<Diagnostic>> diagnostics = new HashMap<>();
        Map<Integer, List<DocumentHighlight>> documentHighlights = new HashMap<>();
        List<IndentGuide> indentGuides = null;
        List<BracketGuide> bracketGuides = null;
        List<FlowGuide> flowGuides = null;
        List<SeparatorGuide> separatorGuides = null;
        List<FoldRegion> foldRegions = new ArrayList<>();
        Map<Integer, List<GutterIcon>> gutterIcons = new HashMap<>();
        Map<Integer, List<PhantomText>> phantomTexts = new HashMap<>();
        Map<Integer, List<CodeLensItem>> codeLensItems = new HashMap<>();
        Map<Integer, List<LinkSpan>> links = new HashMap<>();
        DecorationResult.ApplyMode syntaxMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode semanticMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode overlayMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode inlayMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode diagnosticMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode documentHighlightMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode indentMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode bracketMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode flowMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode separatorMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode foldMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode gutterMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode phantomMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode codeLensMode = DecorationResult.ApplyMode.MERGE;
        DecorationResult.ApplyMode linksMode = DecorationResult.ApplyMode.MERGE;

        for (DecorationProvider provider : providers) {
            ProviderState state = providerStates.get(provider);
            if (state == null || state.snapshot == null) continue;
            DecorationResult r = state.snapshot;

            syntaxMode = mergeMode(syntaxMode, r.getSyntaxSpansMode());
            if (r.getSyntaxSpans() != null) {
                appendMapOfList(syntaxSpans, r.getSyntaxSpans());
            }
            semanticMode = mergeMode(semanticMode, r.getSemanticSpansMode());
            if (r.getSemanticSpans() != null) {
                appendMapOfList(semanticSpans, r.getSemanticSpans());
            }
            overlayMode = mergeMode(overlayMode, r.getOverlaySpansMode());
            if (r.getOverlaySpans() != null) {
                appendMapOfList(overlaySpans, r.getOverlaySpans());
            }
            inlayMode = mergeMode(inlayMode, r.getInlayHintsMode());
            if (r.getInlayHints() != null) {
                appendMapOfList(inlayHints, r.getInlayHints());
            }
            diagnosticMode = mergeMode(diagnosticMode, r.getDiagnosticsMode());
            if (r.getDiagnostics() != null) {
                appendMapOfList(diagnostics, r.getDiagnostics());
            }
            documentHighlightMode = mergeMode(documentHighlightMode, r.getDocumentHighlightsMode());
            if (r.getDocumentHighlights() != null) {
                appendMapOfList(documentHighlights, r.getDocumentHighlights());
            }
            gutterMode = mergeMode(gutterMode, r.getGutterIconsMode());
            if (r.getGutterIcons() != null) {
                appendMapOfList(gutterIcons, r.getGutterIcons());
            }
            phantomMode = mergeMode(phantomMode, r.getPhantomTextsMode());
            if (r.getPhantomTexts() != null) {
                appendMapOfList(phantomTexts, r.getPhantomTexts());
            }
            codeLensMode = mergeMode(codeLensMode, r.getCodeLensItemsMode());
            if (r.getCodeLensItems() != null) {
                appendMapOfList(codeLensItems, r.getCodeLensItems());
            }
            linksMode = mergeMode(linksMode, r.getLinksMode());
            if (r.getLinks() != null) {
                appendMapOfList(links, r.getLinks());
            }

            indentMode = mergeMode(indentMode, r.getIndentGuidesMode());
            if (r.getIndentGuides() != null) {
                indentGuides = appendList(indentGuides, r.getIndentGuides());
            }
            bracketMode = mergeMode(bracketMode, r.getBracketGuidesMode());
            if (r.getBracketGuides() != null) {
                bracketGuides = appendList(bracketGuides, r.getBracketGuides());
            }
            flowMode = mergeMode(flowMode, r.getFlowGuidesMode());
            if (r.getFlowGuides() != null) {
                flowGuides = appendList(flowGuides, r.getFlowGuides());
            }
            separatorMode = mergeMode(separatorMode, r.getSeparatorGuidesMode());
            if (r.getSeparatorGuides() != null) {
                separatorGuides = appendList(separatorGuides, r.getSeparatorGuides());
            }
            foldMode = mergeMode(foldMode, r.getFoldRegionsMode());
            if (r.getFoldRegions() != null) {
                foldRegions.addAll(r.getFoldRegions());
            }
        }

        applySpanMode(SpanLayer.SYNTAX, syntaxMode);
        applySpanMode(SpanLayer.SEMANTIC, semanticMode);
        applySpanMode(SpanLayer.OVERLAY, overlayMode);
        editor.setBatchLineSpans(SpanLayer.SYNTAX, syntaxSpans);
        editor.setBatchLineSpans(SpanLayer.SEMANTIC, semanticSpans);
        editor.setBatchLineSpans(SpanLayer.OVERLAY, overlaySpans);

        applyInlayMode(inlayMode);
        editor.setBatchLineInlayHints(inlayHints);

        applyDiagnosticMode(diagnosticMode);
        editor.setBatchLineDiagnostics(diagnostics);

        applyDocumentHighlightMode(documentHighlightMode);
        editor.setBatchLineDocumentHighlights(documentHighlights);

        applyIndentGuidesMode(indentMode, indentGuides);
        applyBracketGuidesMode(bracketMode, bracketGuides);
        applyFlowGuidesMode(flowMode, flowGuides);
        applySeparatorGuidesMode(separatorMode, separatorGuides);

        if (foldMode == DecorationResult.ApplyMode.REPLACE_ALL || foldMode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            editor.setFoldRegions(foldRegions);
        } else if (!foldRegions.isEmpty()) {
            editor.setFoldRegions(foldRegions);
        }

        applyGutterMode(gutterMode);
        editor.setBatchLineGutterIcons(gutterIcons);

        applyPhantomMode(phantomMode);
        editor.setBatchLinePhantomTexts(phantomTexts);

        applyCodeLensMode(codeLensMode);
        editor.setBatchLineCodeLens(codeLensItems);

        applyLinksMode(linksMode);
        editor.setBatchLineLinks(links);
    }

    private static <T> void appendMapOfList(Map<Integer, List<T>> out, Map<Integer, List<T>> patch) {
        if (patch == null) return;
        for (Map.Entry<Integer, List<T>> e : patch.entrySet()) {
            List<T> src = e.getValue() == null ? Collections.emptyList() : e.getValue();
            List<T> target = out.computeIfAbsent(e.getKey(), k -> new ArrayList<>());
            target.addAll(src);
        }
    }

    private static <T> List<T> appendList(List<T> out, List<T> patch) {
        if (patch == null || patch.isEmpty()) {
            return out;
        }
        List<T> target = out != null ? out : new ArrayList<>();
        target.addAll(patch);
        return target;
    }

    private void applySpanMode(SpanLayer layer, DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearHighlights(layer);
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearSpanRange(layer, lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyInlayMode(DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearInlayHints();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearInlayRange(lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyDiagnosticMode(DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearDiagnostics();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearDiagnosticRange(lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyDocumentHighlightMode(DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearDocumentHighlights();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearDocumentHighlightRange(lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyGutterMode(DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearGutterIcons();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearGutterRange(lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyPhantomMode(DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearPhantomTexts();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearPhantomRange(lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyCodeLensMode(DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearCodeLens();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearCodeLensRange(lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyLinksMode(DecorationResult.ApplyMode mode) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL) {
            editor.clearLinks();
        } else if (mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            clearLinksRange(lastContextLineRange.start, lastContextLineRange.end);
        }
    }

    private void applyIndentGuidesMode(DecorationResult.ApplyMode mode, List<IndentGuide> data) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            editor.setIndentGuides(data != null ? data : Collections.emptyList());
        } else if (data != null) {
            editor.setIndentGuides(data);
        }
    }

    private void applyBracketGuidesMode(DecorationResult.ApplyMode mode, List<BracketGuide> data) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            editor.setBracketGuides(data != null ? data : Collections.emptyList());
        } else if (data != null) {
            editor.setBracketGuides(data);
        }
    }

    private void applyFlowGuidesMode(DecorationResult.ApplyMode mode, List<FlowGuide> data) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            editor.setFlowGuides(data != null ? data : Collections.emptyList());
        } else if (data != null) {
            editor.setFlowGuides(data);
        }
    }

    private void applySeparatorGuidesMode(DecorationResult.ApplyMode mode, List<SeparatorGuide> data) {
        if (mode == DecorationResult.ApplyMode.REPLACE_ALL || mode == DecorationResult.ApplyMode.REPLACE_RANGE) {
            editor.setSeparatorGuides(data != null ? data : Collections.emptyList());
        } else if (data != null) {
            editor.setSeparatorGuides(data);
        }
    }

    private void clearSpanRange(SpanLayer layer, int startLine, int endLine) {
        Map<Integer, List<StyleSpan>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLineSpans(layer, empty);
    }

    private void clearInlayRange(int startLine, int endLine) {
        Map<Integer, List<InlayHint>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLineInlayHints(empty);
    }

    private void clearDiagnosticRange(int startLine, int endLine) {
        Map<Integer, List<Diagnostic>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLineDiagnostics(empty);
    }

    private void clearDocumentHighlightRange(int startLine, int endLine) {
        Map<Integer, List<DocumentHighlight>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLineDocumentHighlights(empty);
    }

    private void clearGutterRange(int startLine, int endLine) {
        Map<Integer, List<GutterIcon>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLineGutterIcons(empty);
    }

    private void clearPhantomRange(int startLine, int endLine) {
        Map<Integer, List<PhantomText>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLinePhantomTexts(empty);
    }

    private void clearCodeLensRange(int startLine, int endLine) {
        Map<Integer, List<CodeLensItem>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLineCodeLens(empty);
    }

    private void clearLinksRange(int startLine, int endLine) {
        Map<Integer, List<LinkSpan>> empty = buildEmptyRangeMap(startLine, endLine);
        if (empty.isEmpty()) return;
        editor.setBatchLineLinks(empty);
    }

    private static <T> Map<Integer, List<T>> buildEmptyRangeMap(int startLine, int endLine) {
        Map<Integer, List<T>> out = new HashMap<>();
        if (endLine < startLine) return out;
        for (int line = startLine; line <= endLine; line++) {
            out.put(line, Collections.<T>emptyList());
        }
        return out;
    }

    private static DecorationResult.ApplyMode mergeMode(DecorationResult.ApplyMode current, DecorationResult.ApplyMode next) {
        if (priority(next) > priority(current)) return next;
        return current;
    }

    private static int priority(DecorationResult.ApplyMode mode) {
        return switch (mode) {
            case MERGE -> 0;
            case REPLACE_RANGE -> 1;
            case REPLACE_ALL -> 2;
        };
    }

    private int getScrollRefreshMinIntervalMs() {
        return Math.max(0, editor.getSettings().getDecorationScrollRefreshMinIntervalMs());
    }

    private int calculateOverscanLines(int visibleStart, int visibleEnd) {
        int viewportLineCount = visibleEnd >= visibleStart ? (visibleEnd - visibleStart + 1) : 0;
        if (viewportLineCount <= 0) return 0;
        float multiplier = Math.max(0f, editor.getSettings().getDecorationOverscanViewportMultiplier());
        return Math.max(0, (int) Math.ceil(viewportLineCount * multiplier));
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
        public boolean accept(DecorationResult result) {
            if (disposed || cancelled || receiverGeneration != generation) return false;
            DecorationResult snapshot = result.copy();
            runOnEdt(() -> {
                if (disposed || cancelled || receiverGeneration != generation) return;
                ProviderState state = providerStates.computeIfAbsent(provider, p -> new ProviderState());
                mergePatch(state, snapshot);
                scheduleApply();
            });
            return true;
        }

        @Override
        public boolean isCancelled() {
            return disposed || cancelled || receiverGeneration != generation;
        }

        void cancel() {
            cancelled = true;
        }
    }

    private void mergePatch(ProviderState state, DecorationResult patch) {
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
        if (patch.getOverlaySpans() != null) {
            target.setOverlaySpans(patch.getOverlaySpans());
            target.setOverlaySpansMode(patch.getOverlaySpansMode());
        } else if (patch.getOverlaySpansMode() != DecorationResult.ApplyMode.MERGE) {
            target.setOverlaySpans(null);
            target.setOverlaySpansMode(patch.getOverlaySpansMode());
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
        if (patch.getDocumentHighlights() != null) {
            target.setDocumentHighlights(patch.getDocumentHighlights());
            target.setDocumentHighlightsMode(patch.getDocumentHighlightsMode());
        } else if (patch.getDocumentHighlightsMode() != DecorationResult.ApplyMode.MERGE) {
            target.setDocumentHighlights(null);
            target.setDocumentHighlightsMode(patch.getDocumentHighlightsMode());
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
        if (patch.getCodeLensItems() != null) {
            target.setCodeLensItems(patch.getCodeLensItems());
            target.setCodeLensItemsMode(patch.getCodeLensItemsMode());
        } else if (patch.getCodeLensItemsMode() != DecorationResult.ApplyMode.MERGE) {
            target.setCodeLensItems(null);
            target.setCodeLensItemsMode(patch.getCodeLensItemsMode());
        }
        if (patch.getLinks() != null) {
            target.setLinks(patch.getLinks());
            target.setLinksMode(patch.getLinksMode());
        } else if (patch.getLinksMode() != DecorationResult.ApplyMode.MERGE) {
            target.setLinks(null);
            target.setLinksMode(patch.getLinksMode());
        }
    }

    private static final class ProviderState {
        DecorationResult snapshot;
        ManagedReceiver activeReceiver;
        final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
            Thread thread = new Thread(r, "SweetEditor-Decoration-" + PROVIDER_THREAD_ID.getAndIncrement());
            thread.setDaemon(true);
            return thread;
        });
    }

    private void runOnEdt(Runnable runnable) {
        if (SwingUtilities.isEventDispatchThread()) {
            runnable.run();
        } else {
            SwingUtilities.invokeLater(runnable);
        }
    }
}
