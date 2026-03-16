package com.qiplat.sweeteditor.decoration;

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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class DecorationResult {
    private Map<Integer, List<StyleSpan>> syntaxSpans;
    private Map<Integer, List<StyleSpan>> semanticSpans;
    private Map<Integer, List<InlayHint>> inlayHints;
    private Map<Integer, List<DiagnosticItem>> diagnostics;
    private List<IndentGuide> indentGuides;
    private List<BracketGuide> bracketGuides;
    private List<FlowGuide> flowGuides;
    private List<SeparatorGuide> separatorGuides;
    private List<FoldRegion> foldRegions;
    private Map<Integer, List<GutterIcon>> gutterIcons;
    private Map<Integer, List<PhantomText>> phantomTexts;

    public Map<Integer, List<StyleSpan>> getSyntaxSpans() { return syntaxSpans; }
    public Map<Integer, List<StyleSpan>> getSemanticSpans() { return semanticSpans; }
    public Map<Integer, List<InlayHint>> getInlayHints() { return inlayHints; }
    public Map<Integer, List<DiagnosticItem>> getDiagnostics() { return diagnostics; }
    public List<IndentGuide> getIndentGuides() { return indentGuides; }
    public List<BracketGuide> getBracketGuides() { return bracketGuides; }
    public List<FlowGuide> getFlowGuides() { return flowGuides; }
    public List<SeparatorGuide> getSeparatorGuides() { return separatorGuides; }
    public List<FoldRegion> getFoldRegions() { return foldRegions; }
    public Map<Integer, List<GutterIcon>> getGutterIcons() { return gutterIcons; }
    public Map<Integer, List<PhantomText>> getPhantomTexts() { return phantomTexts; }

    void setSyntaxSpans(Map<Integer, List<StyleSpan>> v) { this.syntaxSpans = v; }
    void setSemanticSpans(Map<Integer, List<StyleSpan>> v) { this.semanticSpans = v; }
    void setInlayHints(Map<Integer, List<InlayHint>> v) { this.inlayHints = v; }
    void setDiagnostics(Map<Integer, List<DiagnosticItem>> v) { this.diagnostics = v; }
    void setIndentGuides(List<IndentGuide> v) { this.indentGuides = v; }
    void setBracketGuides(List<BracketGuide> v) { this.bracketGuides = v; }
    void setFlowGuides(List<FlowGuide> v) { this.flowGuides = v; }
    void setSeparatorGuides(List<SeparatorGuide> v) { this.separatorGuides = v; }
    void setFoldRegions(List<FoldRegion> v) { this.foldRegions = v; }
    void setGutterIcons(Map<Integer, List<GutterIcon>> v) { this.gutterIcons = v; }
    void setPhantomTexts(Map<Integer, List<PhantomText>> v) { this.phantomTexts = v; }

    public DecorationResult copy() {
        DecorationResult out = new DecorationResult();
        out.syntaxSpans = copyMapOfLists(syntaxSpans);
        out.semanticSpans = copyMapOfLists(semanticSpans);
        out.inlayHints = copyMapOfLists(inlayHints);
        out.diagnostics = copyMapOfLists(diagnostics);
        out.indentGuides = copyList(indentGuides);
        out.bracketGuides = copyList(bracketGuides);
        out.flowGuides = copyList(flowGuides);
        out.separatorGuides = copyList(separatorGuides);
        out.foldRegions = copyList(foldRegions);
        out.gutterIcons = copyMapOfLists(gutterIcons);
        out.phantomTexts = copyMapOfLists(phantomTexts);
        return out;
    }

    private static <T> Map<Integer, List<T>> copyMapOfLists(Map<Integer, List<T>> source) {
        if (source == null) return null;
        Map<Integer, List<T>> out = new HashMap<>();
        for (Map.Entry<Integer, List<T>> e : source.entrySet()) {
            out.put(e.getKey(), e.getValue() == null ? new ArrayList<>() : new ArrayList<>(e.getValue()));
        }
        return out;
    }

    private static <T> List<T> copyList(List<T> source) {
        if (source == null) return null;
        return new ArrayList<>(source);
    }

    public static class Builder {
        private final DecorationResult result = new DecorationResult();

        public Builder syntaxSpans(Map<Integer, List<StyleSpan>> value) { result.syntaxSpans = value; return this; }
        public Builder semanticSpans(Map<Integer, List<StyleSpan>> value) { result.semanticSpans = value; return this; }
        public Builder inlayHints(Map<Integer, List<InlayHint>> value) { result.inlayHints = value; return this; }
        public Builder diagnostics(Map<Integer, List<DiagnosticItem>> value) { result.diagnostics = value; return this; }
        public Builder indentGuides(List<IndentGuide> value) { result.indentGuides = value; return this; }
        public Builder bracketGuides(List<BracketGuide> value) { result.bracketGuides = value; return this; }
        public Builder flowGuides(List<FlowGuide> value) { result.flowGuides = value; return this; }
        public Builder separatorGuides(List<SeparatorGuide> value) { result.separatorGuides = value; return this; }
        public Builder foldRegions(List<FoldRegion> value) { result.foldRegions = value; return this; }
        public Builder gutterIcons(Map<Integer, List<GutterIcon>> value) { result.gutterIcons = value; return this; }
        public Builder phantomTexts(Map<Integer, List<PhantomText>> value) { result.phantomTexts = value; return this; }

        public DecorationResult build() { return result; }
    }
}
