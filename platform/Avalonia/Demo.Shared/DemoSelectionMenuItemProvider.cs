using System;
using System.Collections.Generic;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoSelectionMenuItemProvider : ISelectionMenuItemProvider
{
    public const string ActionDeleteSelection = "delete_selection";
    public const string ActionTriggerCompletion = "trigger_completion";
    public const string ActionShowInlineSuggestion = "show_inline_suggestion";
    public const string ActionAcceptInlineSuggestion = "accept_inline_suggestion";
    public const string ActionDismissInlineSuggestion = "dismiss_inline_suggestion";
    public const string ActionToggleInlineSuggestionAuto = "toggle_inline_suggestion_auto";
    public const string ActionInsertSnippet = "insert_snippet";
    public const string ActionFoldAll = "fold_all";
    public const string ActionUnfoldAll = "unfold_all";
    public const string ActionLoadLargeSample = "load_large_sample";
    public const string ActionTogglePerfOverlay = "toggle_perf_overlay";
    public const string ActionToggleKeyMap = "toggle_keymap";

    private readonly Func<bool> inlineSuggestionAutoEnabled;
    private readonly Func<bool> perfOverlayEnabled;
    private readonly Func<bool> useVsCodeKeyMap;

    public DemoSelectionMenuItemProvider(
        Func<bool> inlineSuggestionAutoEnabled,
        Func<bool> perfOverlayEnabled,
        Func<bool> useVsCodeKeyMap)
    {
        this.inlineSuggestionAutoEnabled = inlineSuggestionAutoEnabled;
        this.perfOverlayEnabled = perfOverlayEnabled;
        this.useVsCodeKeyMap = useVsCodeKeyMap;
    }

    public IReadOnlyList<SelectionMenuItem> ProvideMenuItems(SweetEditorControl editor)
    {
        bool hasSelection = editor.GetSelection().hasSelection;
        bool inlineAuto = inlineSuggestionAutoEnabled();
        bool inlineShowing = editor.IsInlineSuggestionShowing();

        List<SelectionMenuItem> items = new();
        if (hasSelection)
        {
            items.Add(new SelectionMenuItem(ActionDeleteSelection, "Delete", true));
        }

        items.Add(new SelectionMenuItem(ActionTriggerCompletion, "Complete"));

        if (inlineShowing)
        {
            items.Add(new SelectionMenuItem(ActionAcceptInlineSuggestion, "Accept"));
            items.Add(new SelectionMenuItem(ActionDismissInlineSuggestion, "Dismiss"));
        }
        else
        {
            items.Add(new SelectionMenuItem(ActionShowInlineSuggestion, "Ghost text"));
        }

        items.Add(new SelectionMenuItem(ActionInsertSnippet, "Snippet"));
        items.Add(new SelectionMenuItem(ActionToggleInlineSuggestionAuto, inlineAuto ? "Ghost auto: ON" : "Ghost auto: OFF"));
        items.Add(new SelectionMenuItem(ActionFoldAll, "Fold all"));
        items.Add(new SelectionMenuItem(ActionUnfoldAll, "Unfold all"));
        items.Add(new SelectionMenuItem(ActionTogglePerfOverlay, perfOverlayEnabled() ? "Perf: ON" : "Perf: OFF"));
        items.Add(new SelectionMenuItem(ActionToggleKeyMap, useVsCodeKeyMap() ? "Keymap: VS Code" : "Keymap: Default"));
        items.Add(new SelectionMenuItem(ActionLoadLargeSample, "Large doc"));
        return items;
    }
}
