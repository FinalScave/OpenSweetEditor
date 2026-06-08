package com.qiplat.sweeteditor.decoration;

import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.DocumentHighlight;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.CodeLensItem;
import com.qiplat.sweeteditor.core.adornment.LinkSpan;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class DecorationResult {
    public enum ApplyMode {
        MERGE,
        REPLACE_ALL,
        REPLACE_RANGE
    }

    private Map<Integer, List<StyleSpan>> syntaxSpans;
    private Map<Integer, List<StyleSpan>> semanticSpans;
    private Map<Integer, List<InlayHint>> inlayHints;
    private Map<Integer, List<Diagnostic>> diagnostics;
    private Map<Integer, List<DocumentHighlight>> documentHighlights;
    private List<IndentGuide> indentGuides;
    private List<BracketGuide> bracketGuides;
    private List<FlowGuide> flowGuides;
    private List<SeparatorGuide> separatorGuides;
    private List<FoldRegion> foldRegions;
    private Map<Integer, List<GutterIcon>> gutterIcons;
    private Map<Integer, List<PhantomText>> phantomTexts;
    private Map<Integer, List<CodeLensItem>> codeLensItems;
    private Map<Integer, List<LinkSpan>> links;

    private ApplyMode syntaxSpansMode = ApplyMode.MERGE;
    private ApplyMode semanticSpansMode = ApplyMode.MERGE;
    private ApplyMode inlayHintsMode = ApplyMode.MERGE;
    private ApplyMode diagnosticsMode = ApplyMode.MERGE;
    private ApplyMode documentHighlightsMode = ApplyMode.MERGE;
    private ApplyMode indentGuidesMode = ApplyMode.MERGE;
    private ApplyMode bracketGuidesMode = ApplyMode.MERGE;
    private ApplyMode flowGuidesMode = ApplyMode.MERGE;
    private ApplyMode separatorGuidesMode = ApplyMode.MERGE;
    private ApplyMode foldRegionsMode = ApplyMode.MERGE;
    private ApplyMode gutterIconsMode = ApplyMode.MERGE;
    private ApplyMode phantomTextsMode = ApplyMode.MERGE;
    private ApplyMode codeLensItemsMode = ApplyMode.MERGE;
    private ApplyMode linksMode = ApplyMode.MERGE;

    public Map<Integer, List<StyleSpan>> getSyntaxSpans() { return syntaxSpans; }
    public Map<Integer, List<StyleSpan>> getSemanticSpans() { return semanticSpans; }
    public Map<Integer, List<InlayHint>> getInlayHints() { return inlayHints; }
    public Map<Integer, List<Diagnostic>> getDiagnostics() { return diagnostics; }
    public Map<Integer, List<DocumentHighlight>> getDocumentHighlights() { return documentHighlights; }
    public List<IndentGuide> getIndentGuides() { return indentGuides; }
    public List<BracketGuide> getBracketGuides() { return bracketGuides; }
    public List<FlowGuide> getFlowGuides() { return flowGuides; }
    public List<SeparatorGuide> getSeparatorGuides() { return separatorGuides; }
    public List<FoldRegion> getFoldRegions() { return foldRegions; }
    public Map<Integer, List<GutterIcon>> getGutterIcons() { return gutterIcons; }
    public Map<Integer, List<PhantomText>> getPhantomTexts() { return phantomTexts; }
    public Map<Integer, List<CodeLensItem>> getCodeLensItems() { return codeLensItems; }
    public Map<Integer, List<LinkSpan>> getLinks() { return links; }
    public ApplyMode getSyntaxSpansMode() { return syntaxSpansMode; }
    public ApplyMode getSemanticSpansMode() { return semanticSpansMode; }
    public ApplyMode getInlayHintsMode() { return inlayHintsMode; }
    public ApplyMode getDiagnosticsMode() { return diagnosticsMode; }
    public ApplyMode getDocumentHighlightsMode() { return documentHighlightsMode; }
    public ApplyMode getIndentGuidesMode() { return indentGuidesMode; }
    public ApplyMode getBracketGuidesMode() { return bracketGuidesMode; }
    public ApplyMode getFlowGuidesMode() { return flowGuidesMode; }
    public ApplyMode getSeparatorGuidesMode() { return separatorGuidesMode; }
    public ApplyMode getFoldRegionsMode() { return foldRegionsMode; }
    public ApplyMode getGutterIconsMode() { return gutterIconsMode; }
    public ApplyMode getPhantomTextsMode() { return phantomTextsMode; }
    public ApplyMode getCodeLensItemsMode() { return codeLensItemsMode; }
    public ApplyMode getLinksMode() { return linksMode; }

    void setSyntaxSpans(Map<Integer, List<StyleSpan>> v) { this.syntaxSpans = v; }
    void setSemanticSpans(Map<Integer, List<StyleSpan>> v) { this.semanticSpans = v; }
    void setInlayHints(Map<Integer, List<InlayHint>> v) { this.inlayHints = v; }
    void setDiagnostics(Map<Integer, List<Diagnostic>> v) { this.diagnostics = v; }
    void setDocumentHighlights(Map<Integer, List<DocumentHighlight>> v) { this.documentHighlights = v; }
    void setIndentGuides(List<IndentGuide> v) { this.indentGuides = v; }
    void setBracketGuides(List<BracketGuide> v) { this.bracketGuides = v; }
    void setFlowGuides(List<FlowGuide> v) { this.flowGuides = v; }
    void setSeparatorGuides(List<SeparatorGuide> v) { this.separatorGuides = v; }
    void setFoldRegions(List<FoldRegion> v) { this.foldRegions = v; }
    void setGutterIcons(Map<Integer, List<GutterIcon>> v) { this.gutterIcons = v; }
    void setPhantomTexts(Map<Integer, List<PhantomText>> v) { this.phantomTexts = v; }
    void setCodeLensItems(Map<Integer, List<CodeLensItem>> v) { this.codeLensItems = v; }
    void setLinks(Map<Integer, List<LinkSpan>> v) { this.links = v; }
    void setSyntaxSpansMode(ApplyMode mode) { this.syntaxSpansMode = mode; }
    void setSemanticSpansMode(ApplyMode mode) { this.semanticSpansMode = mode; }
    void setInlayHintsMode(ApplyMode mode) { this.inlayHintsMode = mode; }
    void setDiagnosticsMode(ApplyMode mode) { this.diagnosticsMode = mode; }
    void setDocumentHighlightsMode(ApplyMode mode) { this.documentHighlightsMode = mode; }
    void setIndentGuidesMode(ApplyMode mode) { this.indentGuidesMode = mode; }
    void setBracketGuidesMode(ApplyMode mode) { this.bracketGuidesMode = mode; }
    void setFlowGuidesMode(ApplyMode mode) { this.flowGuidesMode = mode; }
    void setSeparatorGuidesMode(ApplyMode mode) { this.separatorGuidesMode = mode; }
    void setFoldRegionsMode(ApplyMode mode) { this.foldRegionsMode = mode; }
    void setGutterIconsMode(ApplyMode mode) { this.gutterIconsMode = mode; }
    void setPhantomTextsMode(ApplyMode mode) { this.phantomTextsMode = mode; }
    void setCodeLensItemsMode(ApplyMode mode) { this.codeLensItemsMode = mode; }
    void setLinksMode(ApplyMode mode) { this.linksMode = mode; }

    public DecorationResult copy() {
        DecorationResult out = new DecorationResult();
        out.syntaxSpans = copyMapOfLists(syntaxSpans);
        out.semanticSpans = copyMapOfLists(semanticSpans);
        out.inlayHints = copyMapOfLists(inlayHints);
        out.diagnostics = copyMapOfLists(diagnostics);
        out.documentHighlights = copyMapOfLists(documentHighlights);
        out.indentGuides = copyList(indentGuides);
        out.bracketGuides = copyList(bracketGuides);
        out.flowGuides = copyList(flowGuides);
        out.separatorGuides = copyList(separatorGuides);
        out.foldRegions = copyList(foldRegions);
        out.gutterIcons = copyMapOfLists(gutterIcons);
        out.phantomTexts = copyMapOfLists(phantomTexts);
        out.codeLensItems = copyMapOfLists(codeLensItems);
        out.links = copyMapOfLists(links);
        out.syntaxSpansMode = syntaxSpansMode;
        out.semanticSpansMode = semanticSpansMode;
        out.inlayHintsMode = inlayHintsMode;
        out.diagnosticsMode = diagnosticsMode;
        out.documentHighlightsMode = documentHighlightsMode;
        out.indentGuidesMode = indentGuidesMode;
        out.bracketGuidesMode = bracketGuidesMode;
        out.flowGuidesMode = flowGuidesMode;
        out.separatorGuidesMode = separatorGuidesMode;
        out.foldRegionsMode = foldRegionsMode;
        out.gutterIconsMode = gutterIconsMode;
        out.phantomTextsMode = phantomTextsMode;
        out.codeLensItemsMode = codeLensItemsMode;
        out.linksMode = linksMode;
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

        public Builder syntaxSpans(Map<Integer, List<StyleSpan>> value, ApplyMode mode) { result.syntaxSpans = value; result.syntaxSpansMode = mode; return this; }
        public Builder semanticSpans(Map<Integer, List<StyleSpan>> value, ApplyMode mode) { result.semanticSpans = value; result.semanticSpansMode = mode; return this; }
        public Builder inlayHints(Map<Integer, List<InlayHint>> value, ApplyMode mode) { result.inlayHints = value; result.inlayHintsMode = mode; return this; }
        public Builder diagnostics(Map<Integer, List<Diagnostic>> value, ApplyMode mode) { result.diagnostics = value; result.diagnosticsMode = mode; return this; }
        public Builder documentHighlights(Map<Integer, List<DocumentHighlight>> value, ApplyMode mode) { result.documentHighlights = value; result.documentHighlightsMode = mode; return this; }
        public Builder indentGuides(List<IndentGuide> value, ApplyMode mode) { result.indentGuides = value; result.indentGuidesMode = mode; return this; }
        public Builder bracketGuides(List<BracketGuide> value, ApplyMode mode) { result.bracketGuides = value; result.bracketGuidesMode = mode; return this; }
        public Builder flowGuides(List<FlowGuide> value, ApplyMode mode) { result.flowGuides = value; result.flowGuidesMode = mode; return this; }
        public Builder separatorGuides(List<SeparatorGuide> value, ApplyMode mode) { result.separatorGuides = value; result.separatorGuidesMode = mode; return this; }
        public Builder foldRegions(List<FoldRegion> value, ApplyMode mode) { result.foldRegions = value; result.foldRegionsMode = mode; return this; }
        public Builder gutterIcons(Map<Integer, List<GutterIcon>> value, ApplyMode mode) { result.gutterIcons = value; result.gutterIconsMode = mode; return this; }
        public Builder phantomTexts(Map<Integer, List<PhantomText>> value, ApplyMode mode) { result.phantomTexts = value; result.phantomTextsMode = mode; return this; }
        public Builder codeLensItems(Map<Integer, List<CodeLensItem>> value, ApplyMode mode) { result.codeLensItems = value; result.codeLensItemsMode = mode; return this; }
        public Builder links(Map<Integer, List<LinkSpan>> value, ApplyMode mode) { result.links = value; result.linksMode = mode; return this; }

        public DecorationResult build() { return result; }
    }
}
