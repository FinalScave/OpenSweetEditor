package com.qiplat.sweeteditor.decoration;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.util.SparseArray;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

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

    private final List<EditorCore.TextChange> pendingTextChanges = new ArrayList<>();
    private volatile boolean applyScheduled;
    private volatile int generation;

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
        scheduleRefresh(50, null);
    }

    private void scheduleRefresh(long delayMs, @Nullable List<EditorCore.TextChange> changes) {
        if (changes != null) {
            pendingTextChanges.addAll(changes);
        }
        mainHandler.removeCallbacks(refreshRunnable);
        mainHandler.postDelayed(refreshRunnable, delayMs);
    }

    private void doRefresh() {
        generation++;
        int currentGeneration = generation;

        int[] visible = editor.getVisibleLineRange();
        int total = editor.getTotalLineCount();
        List<EditorCore.TextChange> changes = new ArrayList<>(pendingTextChanges);
        pendingTextChanges.clear();
        DecorationContext context = new DecorationContext(visible[0], visible[1], total, changes, editor.getLanguageConfiguration());

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
        SparseArray<List<DiagnosticItem>> diagnostics = new SparseArray<>();
        List<IndentGuide> indentGuides = null;
        List<BracketGuide> bracketGuides = null;
        List<FlowGuide> flowGuides = null;
        List<SeparatorGuide> separatorGuides = null;
        List<FoldRegion> foldRegions = new ArrayList<>();
        SparseArray<List<GutterIcon>> gutterIcons = new SparseArray<>();
        SparseArray<List<PhantomText>> phantomTexts = new SparseArray<>();

        for (DecorationProvider provider : providers) {
            ProviderState state = providerStates.get(provider);
            if (state == null || state.snapshot == null) continue;
            DecorationResult r = state.snapshot;

            appendSparseArrayOfList(syntaxSpans, r.getSyntaxSpans());
            appendSparseArrayOfList(semanticSpans, r.getSemanticSpans());
            appendSparseArrayOfList(inlayHints, r.getInlayHints());
            appendSparseArrayOfList(diagnostics, r.getDiagnostics());
            appendSparseArrayOfList(gutterIcons, r.getGutterIcons());
            appendSparseArrayOfList(phantomTexts, r.getPhantomTexts());

            if (r.getIndentGuides() != null) indentGuides = new ArrayList<>(r.getIndentGuides());
            if (r.getBracketGuides() != null) bracketGuides = new ArrayList<>(r.getBracketGuides());
            if (r.getFlowGuides() != null) flowGuides = new ArrayList<>(r.getFlowGuides());
            if (r.getSeparatorGuides() != null) separatorGuides = new ArrayList<>(r.getSeparatorGuides());
            if (r.getFoldRegions() != null) foldRegions.addAll(r.getFoldRegions());
        }

        editor.clearHighlights(SpanLayer.SYNTAX);
        editor.clearHighlights(SpanLayer.SEMANTIC);
        editor.setBatchLineSpans(SpanLayer.SYNTAX, syntaxSpans);
        editor.setBatchLineSpans(SpanLayer.SEMANTIC, semanticSpans);

        editor.clearInlayHints();
        editor.setBatchLineInlayHints(inlayHints);

        editor.clearDiagnostics();
        editor.setBatchLineDiagnostics(diagnostics);

        if (indentGuides != null) {
            editor.setIndentGuides(indentGuides);
        } else {
            editor.setIndentGuides(Collections.emptyList());
        }
        if (bracketGuides != null) {
            editor.setBracketGuides(bracketGuides);
        } else {
            editor.setBracketGuides(Collections.emptyList());
        }
        if (flowGuides != null) {
            editor.setFlowGuides(flowGuides);
        } else {
            editor.setFlowGuides(Collections.emptyList());
        }
        if (separatorGuides != null) {
            editor.setSeparatorGuides(separatorGuides);
        } else {
            editor.setSeparatorGuides(Collections.emptyList());
        }

        if (!foldRegions.isEmpty()) {
            editor.setFoldRegions(foldRegions);
        }

        editor.clearGutterIcons();
        editor.setBatchLineGutterIcons(gutterIcons);

        editor.clearPhantomTexts();
        editor.setBatchLinePhantomTexts(phantomTexts);

        editor.flush();
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

        if (patch.getSyntaxSpans() != null) target.setSyntaxSpans(copySparseArray(patch.getSyntaxSpans()));
        if (patch.getSemanticSpans() != null) target.setSemanticSpans(copySparseArray(patch.getSemanticSpans()));
        if (patch.getInlayHints() != null) target.setInlayHints(copySparseArray(patch.getInlayHints()));
        if (patch.getDiagnostics() != null) target.setDiagnostics(copySparseArray(patch.getDiagnostics()));
        if (patch.getIndentGuides() != null) target.setIndentGuides(new ArrayList<>(patch.getIndentGuides()));
        if (patch.getBracketGuides() != null) target.setBracketGuides(new ArrayList<>(patch.getBracketGuides()));
        if (patch.getFlowGuides() != null) target.setFlowGuides(new ArrayList<>(patch.getFlowGuides()));
        if (patch.getSeparatorGuides() != null) target.setSeparatorGuides(new ArrayList<>(patch.getSeparatorGuides()));
        if (patch.getFoldRegions() != null) target.setFoldRegions(new ArrayList<>(patch.getFoldRegions()));
        if (patch.getGutterIcons() != null) target.setGutterIcons(copySparseArray(patch.getGutterIcons()));
        if (patch.getPhantomTexts() != null) target.setPhantomTexts(copySparseArray(patch.getPhantomTexts()));
    }

    private static <T> SparseArray<List<T>> copySparseArray(SparseArray<List<T>> source) {
        SparseArray<List<T>> out = new SparseArray<>(source.size());
        for (int i = 0, size = source.size(); i < size; i++) {
            int key = source.keyAt(i);
            List<T> value = source.valueAt(i);
            out.put(key, value == null ? new ArrayList<>() : new ArrayList<>(value));
        }
        return out;
    }

    private static final class ProviderState {
        DecorationResult snapshot;
        ManagedReceiver activeReceiver;
    }
}
