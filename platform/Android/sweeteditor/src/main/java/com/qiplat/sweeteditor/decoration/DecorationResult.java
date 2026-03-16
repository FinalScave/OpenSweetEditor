package com.qiplat.sweeteditor.decoration;

import android.util.SparseArray;

import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.adornment.DiagnosticItem;
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
    @Nullable private SparseArray<List<StyleSpan>> syntaxSpans;
    @Nullable private SparseArray<List<StyleSpan>> semanticSpans;
    @Nullable private SparseArray<List<InlayHint>> inlayHints;
    @Nullable private SparseArray<List<DiagnosticItem>> diagnostics;
    @Nullable private List<IndentGuide> indentGuides;
    @Nullable private List<BracketGuide> bracketGuides;
    @Nullable private List<FlowGuide> flowGuides;
    @Nullable private List<SeparatorGuide> separatorGuides;
    @Nullable private List<FoldRegion> foldRegions;
    @Nullable private SparseArray<List<GutterIcon>> gutterIcons;
    @Nullable private SparseArray<List<PhantomText>> phantomTexts;

    @Nullable public SparseArray<List<StyleSpan>> getSyntaxSpans() { return syntaxSpans; }
    @Nullable public SparseArray<List<StyleSpan>> getSemanticSpans() { return semanticSpans; }
    @Nullable public SparseArray<List<InlayHint>> getInlayHints() { return inlayHints; }
    @Nullable public SparseArray<List<DiagnosticItem>> getDiagnostics() { return diagnostics; }
    @Nullable public List<IndentGuide> getIndentGuides() { return indentGuides; }
    @Nullable public List<BracketGuide> getBracketGuides() { return bracketGuides; }
    @Nullable public List<FlowGuide> getFlowGuides() { return flowGuides; }
    @Nullable public List<SeparatorGuide> getSeparatorGuides() { return separatorGuides; }
    @Nullable public List<FoldRegion> getFoldRegions() { return foldRegions; }
    @Nullable public SparseArray<List<GutterIcon>> getGutterIcons() { return gutterIcons; }
    @Nullable public SparseArray<List<PhantomText>> getPhantomTexts() { return phantomTexts; }

    void setSyntaxSpans(@Nullable SparseArray<List<StyleSpan>> v) { this.syntaxSpans = v; }
    void setSemanticSpans(@Nullable SparseArray<List<StyleSpan>> v) { this.semanticSpans = v; }
    void setInlayHints(@Nullable SparseArray<List<InlayHint>> v) { this.inlayHints = v; }
    void setDiagnostics(@Nullable SparseArray<List<DiagnosticItem>> v) { this.diagnostics = v; }
    void setIndentGuides(@Nullable List<IndentGuide> v) { this.indentGuides = v; }
    void setBracketGuides(@Nullable List<BracketGuide> v) { this.bracketGuides = v; }
    void setFlowGuides(@Nullable List<FlowGuide> v) { this.flowGuides = v; }
    void setSeparatorGuides(@Nullable List<SeparatorGuide> v) { this.separatorGuides = v; }
    void setFoldRegions(@Nullable List<FoldRegion> v) { this.foldRegions = v; }
    void setGutterIcons(@Nullable SparseArray<List<GutterIcon>> v) { this.gutterIcons = v; }
    void setPhantomTexts(@Nullable SparseArray<List<PhantomText>> v) { this.phantomTexts = v; }

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

        public Builder syntaxSpans(SparseArray<List<StyleSpan>> value) { result.syntaxSpans = value; return this; }
        public Builder semanticSpans(SparseArray<List<StyleSpan>> value) { result.semanticSpans = value; return this; }
        public Builder inlayHints(SparseArray<List<InlayHint>> value) { result.inlayHints = value; return this; }
        public Builder diagnostics(SparseArray<List<DiagnosticItem>> value) { result.diagnostics = value; return this; }
        public Builder indentGuides(List<IndentGuide> value) { result.indentGuides = value; return this; }
        public Builder bracketGuides(List<BracketGuide> value) { result.bracketGuides = value; return this; }
        public Builder flowGuides(List<FlowGuide> value) { result.flowGuides = value; return this; }
        public Builder separatorGuides(List<SeparatorGuide> value) { result.separatorGuides = value; return this; }
        public Builder foldRegions(List<FoldRegion> value) { result.foldRegions = value; return this; }
        public Builder gutterIcons(SparseArray<List<GutterIcon>> value) { result.gutterIcons = value; return this; }
        public Builder phantomTexts(SparseArray<List<PhantomText>> value) { result.phantomTexts = value; return this; }

        public DecorationResult build() { return result; }
    }
}
