package com.qiplat.sweeteditor.decoration;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.adornment.DiagnosticItem;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
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

public final class DecorationProviderManager {
    private final SweetEditor editor;
    private final CopyOnWriteArrayList<DecorationProvider> providers = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<DecorationProvider, ProviderState> providerStates = new ConcurrentHashMap<>();

    private final Timer debounceTimer;

    private final List<TextChange> pendingTextChanges = new ArrayList<>();
    private volatile boolean applyScheduled;
    private volatile int generation;

    public DecorationProviderManager(SweetEditor editor) {
        this.editor = editor;
        this.debounceTimer = new Timer(50, e -> doRefresh());
        this.debounceTimer.setRepeats(false);
    }

    public void addProvider(DecorationProvider provider) {
        runOnEdt(() -> {
            if (!providers.contains(provider)) {
                providers.add(provider);
                providerStates.put(provider, new ProviderState());
                requestRefresh();
            }
        });
    }

    public void removeProvider(DecorationProvider provider) {
        runOnEdt(() -> {
            providers.remove(provider);
            ProviderState state = providerStates.remove(provider);
            if (state != null && state.activeReceiver != null) {
                state.activeReceiver.cancel();
            }
            scheduleApply();
        });
    }

    public void requestRefresh() {
        scheduleRefresh(0, null);
    }

    public void onDocumentLoaded() {
        scheduleRefresh(0, null);
    }

    public void onTextChanged(List<TextChange> changes) {
        scheduleRefresh(50, changes);
    }

    public void onScrollChanged() {
        scheduleRefresh(50, null);
    }

    private void scheduleRefresh(int delayMs, List<TextChange> changes) {
        runOnEdt(() -> {
            if (changes != null) {
                pendingTextChanges.addAll(changes);
            }
            debounceTimer.stop();
            debounceTimer.setInitialDelay(Math.max(0, delayMs));
            debounceTimer.start();
        });
    }

    private void doRefresh() {
        generation++;
        int currentGeneration = generation;

        int[] visible = editor.getVisibleLineRange();
        int total = editor.getTotalLineCount();
        List<TextChange> changes = new ArrayList<>(pendingTextChanges);
        pendingTextChanges.clear();
        DecorationContext context = new DecorationContext(visible[0], visible[1], total, changes, editor.getLanguageConfiguration());

        for (DecorationProvider provider : providers) {
            ProviderState state = providerStates.computeIfAbsent(provider, p -> new ProviderState());
            if (state.activeReceiver != null) {
                state.activeReceiver.cancel();
            }
            ManagedReceiver receiver = new ManagedReceiver(provider, currentGeneration);
            state.activeReceiver = receiver;
            try {
                provider.provideDecorations(context, receiver);
            } catch (Throwable ignored) {
            }
        }
    }

    private void scheduleApply() {
        if (applyScheduled) return;
        applyScheduled = true;
        runOnEdt(this::applyMerged);
    }

    private void applyMerged() {
        applyScheduled = false;

        Map<Integer, List<StyleSpan>> syntaxSpans = new HashMap<>();
        Map<Integer, List<StyleSpan>> semanticSpans = new HashMap<>();
        Map<Integer, List<InlayHint>> inlayHints = new HashMap<>();
        Map<Integer, List<DiagnosticItem>> diagnostics = new HashMap<>();
        List<IndentGuide> indentGuides = null;
        List<BracketGuide> bracketGuides = null;
        List<FlowGuide> flowGuides = null;
        List<SeparatorGuide> separatorGuides = null;
        List<FoldRegion> foldRegions = new ArrayList<>();
        Map<Integer, List<GutterIcon>> gutterIcons = new HashMap<>();
        Map<Integer, List<PhantomText>> phantomTexts = new HashMap<>();

        for (DecorationProvider provider : providers) {
            ProviderState state = providerStates.get(provider);
            if (state == null || state.snapshot == null) continue;
            DecorationResult r = state.snapshot;

            appendMapOfList(syntaxSpans, r.getSyntaxSpans());
            appendMapOfList(semanticSpans, r.getSemanticSpans());
            appendMapOfList(inlayHints, r.getInlayHints());
            appendMapOfList(diagnostics, r.getDiagnostics());
            appendMapOfList(gutterIcons, r.getGutterIcons());
            appendMapOfList(phantomTexts, r.getPhantomTexts());

            if (r.getIndentGuides() != null) indentGuides = new ArrayList<>(r.getIndentGuides());
            if (r.getBracketGuides() != null) bracketGuides = new ArrayList<>(r.getBracketGuides());
            if (r.getFlowGuides() != null) flowGuides = new ArrayList<>(r.getFlowGuides());
            if (r.getSeparatorGuides() != null) separatorGuides = new ArrayList<>(r.getSeparatorGuides());
            if (r.getFoldRegions() != null) foldRegions.addAll(r.getFoldRegions());
        }

        // Highlight Spans: Use batch model API
        editor.clearHighlights(SpanLayer.SYNTAX);
        editor.clearHighlights(SpanLayer.SEMANTIC);
        editor.setBatchLineSpans(SpanLayer.SYNTAX.value, syntaxSpans);
        editor.setBatchLineSpans(SpanLayer.SEMANTIC.value, semanticSpans);

        // InlayHints: Use batch model API
        editor.clearInlayHints();
        editor.setBatchLineInlayHints(inlayHints);

        // Diagnostics: Use batch model API
        editor.clearDiagnostics();
        editor.setBatchLineDiagnostics(diagnostics);

        // Guides: Use batch replacement model API
        editor.setIndentGuides(indentGuides != null ? indentGuides : Collections.emptyList());
        editor.setBracketGuides(bracketGuides != null ? bracketGuides : Collections.emptyList());
        editor.setFlowGuides(flowGuides != null ? flowGuides : Collections.emptyList());
        editor.setSeparatorGuides(separatorGuides != null ? separatorGuides : Collections.emptyList());

        // Fold regions
        if (!foldRegions.isEmpty()) {
            editor.setFoldRegions(foldRegions);
        }

        // GutterIcons: Use batch model API
        editor.setBatchLineGutterIcons(gutterIcons);

        // PhantomTexts: Use batch model API
        editor.setBatchLinePhantomTexts(phantomTexts);

        editor.flush();
    }

    private static <T> void appendMapOfList(Map<Integer, List<T>> out, Map<Integer, List<T>> patch) {
        if (patch == null) return;
        for (Map.Entry<Integer, List<T>> e : patch.entrySet()) {
            List<T> src = e.getValue() == null ? Collections.emptyList() : e.getValue();
            List<T> target = out.computeIfAbsent(e.getKey(), k -> new ArrayList<>());
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
        public boolean accept(DecorationResult result) {
            if (cancelled || receiverGeneration != generation) return false;
            DecorationResult snapshot = result.copy();
            runOnEdt(() -> {
                if (cancelled || receiverGeneration != generation) return;
                ProviderState state = providerStates.computeIfAbsent(provider, p -> new ProviderState());
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

    private void mergePatch(ProviderState state, DecorationResult patch) {
        if (state.snapshot == null) {
            state.snapshot = new DecorationResult();
        }
        DecorationResult target = state.snapshot;

        if (patch.getSyntaxSpans() != null) target.setSyntaxSpans(copyMap(patch.getSyntaxSpans()));
        if (patch.getSemanticSpans() != null) target.setSemanticSpans(copyMap(patch.getSemanticSpans()));
        if (patch.getInlayHints() != null) target.setInlayHints(copyMap(patch.getInlayHints()));
        if (patch.getDiagnostics() != null) target.setDiagnostics(copyMap(patch.getDiagnostics()));
        if (patch.getIndentGuides() != null) target.setIndentGuides(new ArrayList<>(patch.getIndentGuides()));
        if (patch.getBracketGuides() != null) target.setBracketGuides(new ArrayList<>(patch.getBracketGuides()));
        if (patch.getFlowGuides() != null) target.setFlowGuides(new ArrayList<>(patch.getFlowGuides()));
        if (patch.getSeparatorGuides() != null) target.setSeparatorGuides(new ArrayList<>(patch.getSeparatorGuides()));
        if (patch.getFoldRegions() != null) target.setFoldRegions(new ArrayList<>(patch.getFoldRegions()));
        if (patch.getGutterIcons() != null) target.setGutterIcons(copyMap(patch.getGutterIcons()));
        if (patch.getPhantomTexts() != null) target.setPhantomTexts(copyMap(patch.getPhantomTexts()));
    }

    private static <T> Map<Integer, List<T>> copyMap(Map<Integer, List<T>> source) {
        Map<Integer, List<T>> out = new HashMap<>();
        for (Map.Entry<Integer, List<T>> e : source.entrySet()) {
            out.put(e.getKey(), e.getValue() == null ? new ArrayList<>() : new ArrayList<>(e.getValue()));
        }
        return out;
    }

    private static final class ProviderState {
        DecorationResult snapshot;
        ManagedReceiver activeReceiver;
    }

    private void runOnEdt(Runnable runnable) {
        if (SwingUtilities.isEventDispatchThread()) {
            runnable.run();
        } else {
            SwingUtilities.invokeLater(runnable);
        }
    }
}
