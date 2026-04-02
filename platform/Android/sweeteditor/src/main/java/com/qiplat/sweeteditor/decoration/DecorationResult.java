package com.qiplat.sweeteditor.decoration;

import android.util.SparseArray;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;

import java.util.ArrayList;
import java.util.List;

public class DecorationResult {
    public enum ApplyMode {
        MERGE,
        REPLACE_ALL,
        REPLACE_RANGE
    }

    @Nullable private SparseArray<List<StyleSpan>> syntaxSpans;
    @Nullable private SparseArray<List<StyleSpan>> semanticSpans;
    @Nullable private SparseArray<List<InlayHint>> inlayHints;
    @Nullable private SparseArray<List<Diagnostic>> diagnostics;
    @Nullable private List<IndentGuide> indentGuides;
    @Nullable private List<BracketGuide> bracketGuides;
    @Nullable private List<FlowGuide> flowGuides;
    @Nullable private List<SeparatorGuide> separatorGuides;
    @Nullable private List<FoldRegion> foldRegions;
    @Nullable private SparseArray<List<GutterIcon>> gutterIcons;
    @Nullable private SparseArray<List<PhantomText>> phantomTexts;

    @NonNull private ApplyMode syntaxSpansMode = ApplyMode.MERGE;
    @NonNull private ApplyMode semanticSpansMode = ApplyMode.MERGE;
    @NonNull private ApplyMode inlayHintsMode = ApplyMode.MERGE;
    @NonNull private ApplyMode diagnosticsMode = ApplyMode.MERGE;
    @NonNull private ApplyMode indentGuidesMode = ApplyMode.MERGE;
    @NonNull private ApplyMode bracketGuidesMode = ApplyMode.MERGE;
    @NonNull private ApplyMode flowGuidesMode = ApplyMode.MERGE;
    @NonNull private ApplyMode separatorGuidesMode = ApplyMode.MERGE;
    @NonNull private ApplyMode foldRegionsMode = ApplyMode.MERGE;
    @NonNull private ApplyMode gutterIconsMode = ApplyMode.MERGE;
    @NonNull private ApplyMode phantomTextsMode = ApplyMode.MERGE;

    @Nullable public SparseArray<List<StyleSpan>> getSyntaxSpans() { return syntaxSpans; }
    @Nullable public SparseArray<List<StyleSpan>> getSemanticSpans() { return semanticSpans; }
    @Nullable public SparseArray<List<InlayHint>> getInlayHints() { return inlayHints; }
    @Nullable public SparseArray<List<Diagnostic>> getDiagnostics() { return diagnostics; }
    @Nullable public List<IndentGuide> getIndentGuides() { return indentGuides; }
    @Nullable public List<BracketGuide> getBracketGuides() { return bracketGuides; }
    @Nullable public List<FlowGuide> getFlowGuides() { return flowGuides; }
    @Nullable public List<SeparatorGuide> getSeparatorGuides() { return separatorGuides; }
    @Nullable public List<FoldRegion> getFoldRegions() { return foldRegions; }
    @Nullable public SparseArray<List<GutterIcon>> getGutterIcons() { return gutterIcons; }
    @Nullable public SparseArray<List<PhantomText>> getPhantomTexts() { return phantomTexts; }
    @NonNull public ApplyMode getSyntaxSpansMode() { return syntaxSpansMode; }
    @NonNull public ApplyMode getSemanticSpansMode() { return semanticSpansMode; }
    @NonNull public ApplyMode getInlayHintsMode() { return inlayHintsMode; }
    @NonNull public ApplyMode getDiagnosticsMode() { return diagnosticsMode; }
    @NonNull public ApplyMode getIndentGuidesMode() { return indentGuidesMode; }
    @NonNull public ApplyMode getBracketGuidesMode() { return bracketGuidesMode; }
    @NonNull public ApplyMode getFlowGuidesMode() { return flowGuidesMode; }
    @NonNull public ApplyMode getSeparatorGuidesMode() { return separatorGuidesMode; }
    @NonNull public ApplyMode getFoldRegionsMode() { return foldRegionsMode; }
    @NonNull public ApplyMode getGutterIconsMode() { return gutterIconsMode; }
    @NonNull public ApplyMode getPhantomTextsMode() { return phantomTextsMode; }

    void setSyntaxSpans(@Nullable SparseArray<List<StyleSpan>> v) { this.syntaxSpans = v; }
    void setSemanticSpans(@Nullable SparseArray<List<StyleSpan>> v) { this.semanticSpans = v; }
    void setInlayHints(@Nullable SparseArray<List<InlayHint>> v) { this.inlayHints = v; }
    void setDiagnostics(@Nullable SparseArray<List<Diagnostic>> v) { this.diagnostics = v; }
    void setIndentGuides(@Nullable List<IndentGuide> v) { this.indentGuides = v; }
    void setBracketGuides(@Nullable List<BracketGuide> v) { this.bracketGuides = v; }
    void setFlowGuides(@Nullable List<FlowGuide> v) { this.flowGuides = v; }
    void setSeparatorGuides(@Nullable List<SeparatorGuide> v) { this.separatorGuides = v; }
    void setFoldRegions(@Nullable List<FoldRegion> v) { this.foldRegions = v; }
    void setGutterIcons(@Nullable SparseArray<List<GutterIcon>> v) { this.gutterIcons = v; }
    void setPhantomTexts(@Nullable SparseArray<List<PhantomText>> v) { this.phantomTexts = v; }
    void setSyntaxSpansMode(@NonNull ApplyMode mode) { this.syntaxSpansMode = mode; }
    void setSemanticSpansMode(@NonNull ApplyMode mode) { this.semanticSpansMode = mode; }
    void setInlayHintsMode(@NonNull ApplyMode mode) { this.inlayHintsMode = mode; }
    void setDiagnosticsMode(@NonNull ApplyMode mode) { this.diagnosticsMode = mode; }
    void setIndentGuidesMode(@NonNull ApplyMode mode) { this.indentGuidesMode = mode; }
    void setBracketGuidesMode(@NonNull ApplyMode mode) { this.bracketGuidesMode = mode; }
    void setFlowGuidesMode(@NonNull ApplyMode mode) { this.flowGuidesMode = mode; }
    void setSeparatorGuidesMode(@NonNull ApplyMode mode) { this.separatorGuidesMode = mode; }
    void setFoldRegionsMode(@NonNull ApplyMode mode) { this.foldRegionsMode = mode; }
    void setGutterIconsMode(@NonNull ApplyMode mode) { this.gutterIconsMode = mode; }
    void setPhantomTextsMode(@NonNull ApplyMode mode) { this.phantomTextsMode = mode; }

    public DecorationResult copy() {
        DecorationResult out = new DecorationResult();
        out.syntaxSpans = copySparseArrayOfLists(syntaxSpans);
        out.semanticSpans = copySparseArrayOfLists(semanticSpans);
        out.inlayHints = copySparseArrayOfLists(inlayHints);
        out.diagnostics = copySparseArrayOfLists(diagnostics);
        out.indentGuides = copyList(indentGuides);
        out.bracketGuides = copyList(bracketGuides);
        out.flowGuides = copyList(flowGuides);
        out.separatorGuides = copyList(separatorGuides);
        out.foldRegions = copyList(foldRegions);
        out.gutterIcons = copySparseArrayOfLists(gutterIcons);
        out.phantomTexts = copySparseArrayOfLists(phantomTexts);
        out.syntaxSpansMode = syntaxSpansMode;
        out.semanticSpansMode = semanticSpansMode;
        out.inlayHintsMode = inlayHintsMode;
        out.diagnosticsMode = diagnosticsMode;
        out.indentGuidesMode = indentGuidesMode;
        out.bracketGuidesMode = bracketGuidesMode;
        out.flowGuidesMode = flowGuidesMode;
        out.separatorGuidesMode = separatorGuidesMode;
        out.foldRegionsMode = foldRegionsMode;
        out.gutterIconsMode = gutterIconsMode;
        out.phantomTextsMode = phantomTextsMode;
        return out;
    }

    private static <T> SparseArray<List<T>> copySparseArrayOfLists(@Nullable SparseArray<List<T>> source) {
        if (source == null) return null;
        SparseArray<List<T>> out = new SparseArray<>(source.size());
        for (int i = 0, size = source.size(); i < size; i++) {
            int key = source.keyAt(i);
            List<T> value = source.valueAt(i);
            out.put(key, value == null ? new ArrayList<>() : new ArrayList<>(value));
        }
        return out;
    }

    private static <T> List<T> copyList(@Nullable List<T> source) {
        if (source == null) return null;
        return new ArrayList<>(source);
    }

    public static class Builder {
        private final DecorationResult result = new DecorationResult();

        public Builder syntaxSpans(@Nullable SparseArray<List<StyleSpan>> value, @NonNull ApplyMode mode) { result.syntaxSpans = value; result.syntaxSpansMode = mode; return this; }
        public Builder semanticSpans(@Nullable SparseArray<List<StyleSpan>> value, @NonNull ApplyMode mode) { result.semanticSpans = value; result.semanticSpansMode = mode; return this; }
        public Builder inlayHints(@Nullable SparseArray<List<InlayHint>> value, @NonNull ApplyMode mode) { result.inlayHints = value; result.inlayHintsMode = mode; return this; }
        public Builder diagnostics(@Nullable SparseArray<List<Diagnostic>> value, @NonNull ApplyMode mode) { result.diagnostics = value; result.diagnosticsMode = mode; return this; }
        public Builder indentGuides(@Nullable List<IndentGuide> value, @NonNull ApplyMode mode) { result.indentGuides = value; result.indentGuidesMode = mode; return this; }
        public Builder bracketGuides(@Nullable List<BracketGuide> value, @NonNull ApplyMode mode) { result.bracketGuides = value; result.bracketGuidesMode = mode; return this; }
        public Builder flowGuides(@Nullable List<FlowGuide> value, @NonNull ApplyMode mode) { result.flowGuides = value; result.flowGuidesMode = mode; return this; }
        public Builder separatorGuides(@Nullable List<SeparatorGuide> value, @NonNull ApplyMode mode) { result.separatorGuides = value; result.separatorGuidesMode = mode; return this; }
        public Builder foldRegions(@Nullable List<FoldRegion> value, @NonNull ApplyMode mode) { result.foldRegions = value; result.foldRegionsMode = mode; return this; }
        public Builder gutterIcons(@Nullable SparseArray<List<GutterIcon>> value, @NonNull ApplyMode mode) { result.gutterIcons = value; result.gutterIconsMode = mode; return this; }
        public Builder phantomTexts(@Nullable SparseArray<List<PhantomText>> value, @NonNull ApplyMode mode) { result.phantomTexts = value; result.phantomTextsMode = mode; return this; }

        public DecorationResult build() { return result; }
    }
}
