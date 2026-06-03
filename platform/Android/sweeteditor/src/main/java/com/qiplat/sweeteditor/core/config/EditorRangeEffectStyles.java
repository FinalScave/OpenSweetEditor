package com.qiplat.sweeteditor.core.config;

public final class EditorRangeEffectStyles {
    public RangeEffectStyle selection = new RangeEffectStyle();
    public RangeEffectStyle searchMatch = new RangeEffectStyle();
    public RangeEffectStyle searchCurrent = new RangeEffectStyle();
    public RangeEffectStyle documentHighlightText = new RangeEffectStyle();
    public RangeEffectStyle documentHighlightRead = new RangeEffectStyle();
    public RangeEffectStyle documentHighlightWrite = new RangeEffectStyle();
    public RangeEffectStyle linkedEditingActive = new RangeEffectStyle();
    public RangeEffectStyle linkedEditingInactive = new RangeEffectStyle();
    public RangeEffectStyle imeComposition = new RangeEffectStyle();
    public RangeEffectStyle bracketMatch = new RangeEffectStyle();
    public RangeEffectStyle diagnosticError = new RangeEffectStyle();
    public RangeEffectStyle diagnosticWarning = new RangeEffectStyle();
    public RangeEffectStyle diagnosticInfo = new RangeEffectStyle();
    public RangeEffectStyle diagnosticHint = new RangeEffectStyle();

    public EditorRangeEffectStyles() {
    }

    public EditorRangeEffectStyles(RangeEffectStyle selection, RangeEffectStyle searchMatch, RangeEffectStyle searchCurrent, RangeEffectStyle documentHighlightText, RangeEffectStyle documentHighlightRead, RangeEffectStyle documentHighlightWrite, RangeEffectStyle linkedEditingActive, RangeEffectStyle linkedEditingInactive, RangeEffectStyle imeComposition, RangeEffectStyle bracketMatch, RangeEffectStyle diagnosticError, RangeEffectStyle diagnosticWarning, RangeEffectStyle diagnosticInfo, RangeEffectStyle diagnosticHint) {
        this.selection = selection;
        this.searchMatch = searchMatch;
        this.searchCurrent = searchCurrent;
        this.documentHighlightText = documentHighlightText;
        this.documentHighlightRead = documentHighlightRead;
        this.documentHighlightWrite = documentHighlightWrite;
        this.linkedEditingActive = linkedEditingActive;
        this.linkedEditingInactive = linkedEditingInactive;
        this.imeComposition = imeComposition;
        this.bracketMatch = bracketMatch;
        this.diagnosticError = diagnosticError;
        this.diagnosticWarning = diagnosticWarning;
        this.diagnosticInfo = diagnosticInfo;
        this.diagnosticHint = diagnosticHint;
    }
}
