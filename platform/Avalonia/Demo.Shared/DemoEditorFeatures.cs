using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoCompletionProvider : ICompletionProvider
{
    private static readonly HashSet<string> TriggerChars = new(StringComparer.Ordinal)
    {
        ".",
        ":",
        "#",
    };

    public bool IsTriggerCharacter(string ch) => TriggerChars.Contains(ch);

    public void ProvideCompletions(CompletionContext context, ICompletionReceiver receiver)
    {
        if (receiver.IsCancelled)
            return;

        TextRange? replacementRange = GetIdentifierRange(context);
        string word = replacementRange is TextRange wordRange
            ? context.LineText.Substring(
                wordRange.Start.Column,
                Math.Max(0, wordRange.End.Column - wordRange.Start.Column))
            : string.Empty;
        string normalized = word.Trim();

        if (context.TriggerKind == CompletionTriggerKind.Character &&
            string.Equals(context.TriggerCharacter, ".", StringComparison.Ordinal))
        {
            receiver.Accept(new CompletionResult(BuildMemberItems(), false));
            return;
        }

        _ = Task.Run(async () =>
        {
            await Task.Delay(120).ConfigureAwait(false);
            if (receiver.IsCancelled)
                return;

            List<CompletionItem> items = BuildGlobalItems();
            ApplyReplacementEdits(items, replacementRange);
            if (!string.IsNullOrWhiteSpace(normalized))
            {
                items = items.FindAll(item =>
                    item.Label.Contains(normalized, StringComparison.OrdinalIgnoreCase) ||
                    (item.FilterText?.Contains(normalized, StringComparison.OrdinalIgnoreCase) ?? false));
                if (items.Count == 0)
                    items = BuildGlobalItems();
            }

            receiver.Accept(new CompletionResult(items, false));
        });
    }

    private static void ApplyReplacementEdits(List<CompletionItem> items, TextRange? range)
    {
        if (range == null)
            return;

        foreach (CompletionItem item in items)
            item.TextEdit = new TextEdit(range, item.InsertText ?? item.Label);
    }

    private static TextRange? GetIdentifierRange(CompletionContext context)
    {
        if (context.WordRange is not TextRange range)
            return null;

        int line = context.CursorPosition.Line;
        int cursorColumn = context.CursorPosition.Column;
        int startColumn = range.Start.Column;
        int endColumn = range.End.Column;
        if (range.Start.Line != line || range.End.Line != line ||
            startColumn < 0 || startColumn >= endColumn ||
            cursorColumn < startColumn || cursorColumn > endColumn ||
            endColumn > context.LineText.Length)
        {
            return null;
        }

        for (int column = startColumn; column < endColumn; column++)
        {
            if (!IsWordChar(context.LineText[column]))
                return null;
        }
        return range;
    }

    private static bool IsWordChar(char ch) =>
        (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') ||
        ch == '_' ||
        ch > 0x7F;

    private static List<CompletionItem> BuildMemberItems() => new()
    {
        new CompletionItem { Label = "size", Detail = "size_t", InsertText = "size()", Kind = CompletionItem.KIND_FUNCTION, SortKey = "a_size" },
        new CompletionItem { Label = "empty", Detail = "bool", InsertText = "empty()", Kind = CompletionItem.KIND_FUNCTION, SortKey = "b_empty" },
        new CompletionItem { Label = "begin", Detail = "iterator", InsertText = "begin()", Kind = CompletionItem.KIND_FUNCTION, SortKey = "c_begin" },
        new CompletionItem { Label = "end", Detail = "iterator", InsertText = "end()", Kind = CompletionItem.KIND_FUNCTION, SortKey = "d_end" },
        new CompletionItem { Label = "length", Detail = "int", InsertText = "length()", Kind = CompletionItem.KIND_PROPERTY, SortKey = "e_length" },
    };

    private static List<CompletionItem> BuildGlobalItems() => new()
    {
        new CompletionItem
        {
            Label = "std::vector",
            Detail = "template class",
            InsertText = "std::vector<${1:int}> ${2:name};",
            InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
            Kind = CompletionItem.KIND_CLASS,
            SortKey = "a_vector",
        },
        new CompletionItem
        {
            Label = "std::string",
            Detail = "class",
            InsertText = "std::string",
            Kind = CompletionItem.KIND_CLASS,
            SortKey = "b_string",
        },
        new CompletionItem
        {
            Label = "if",
            Detail = "snippet",
            InsertText = "if (${1:condition})\n{\n    $0\n}",
            InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
            Kind = CompletionItem.KIND_SNIPPET,
            SortKey = "c_if",
        },
        new CompletionItem
        {
            Label = "for",
            Detail = "snippet",
            InsertText = "for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i})\n{\n    $0\n}",
            InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
            Kind = CompletionItem.KIND_SNIPPET,
            SortKey = "d_for",
        },
        new CompletionItem
        {
            Label = "class",
            Detail = "snippet",
            InsertText = "class ${1:TypeName}\n{\npublic:\n    ${1:TypeName}();\n    ~$1();\n\nprivate:\n    $0\n};",
            InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
            Kind = CompletionItem.KIND_SNIPPET,
            SortKey = "e_class",
        },
        new CompletionItem
        {
            Label = "TODO",
            Detail = "comment",
            InsertText = "TODO: ",
            Kind = CompletionItem.KIND_TEXT,
            SortKey = "f_todo",
        },
        new CompletionItem
        {
            Label = "#region",
            Detail = "fold marker",
            InsertText = "#region ${1:name}\n$0\n#endregion",
            InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
            Kind = CompletionItem.KIND_SNIPPET,
            SortKey = "g_region",
        },
    };
}

internal sealed class DemoNewLineActionProvider : INewLineActionProvider
{
    public NewLineAction? ProvideNewLineAction(NewLineContext context)
    {
        string line = context.LineText ?? string.Empty;
        int safeColumn = Math.Clamp(context.Column, 0, line.Length);
        string beforeCursor = line[..safeColumn];
        string trimmed = beforeCursor.TrimEnd();
        string indent = ExtractIndentation(line);
        string unit = (context.LanguageConfiguration?.InsertSpaces ?? true)
            ? new string(' ', context.LanguageConfiguration?.TabSize ?? 4)
            : "\t";

        if (trimmed.EndsWith("{", StringComparison.Ordinal))
            return new NewLineAction(Environment.NewLine + indent + unit + Environment.NewLine + indent);

        if (trimmed.EndsWith("(", StringComparison.Ordinal) || trimmed.EndsWith("[", StringComparison.Ordinal))
            return new NewLineAction(Environment.NewLine + indent + unit);

        if (trimmed.EndsWith(":", StringComparison.Ordinal) &&
            (context.LanguageConfiguration?.LanguageId?.Contains("lua", StringComparison.OrdinalIgnoreCase) ?? false))
        {
            return new NewLineAction(Environment.NewLine + indent + unit);
        }

        return null;
    }

    private static string ExtractIndentation(string line)
    {
        if (string.IsNullOrEmpty(line))
            return string.Empty;

        int length = 0;
        while (length < line.Length && (line[length] == ' ' || line[length] == '\t'))
            length++;

        return length == 0 ? string.Empty : line[..length];
    }
}

internal sealed class DemoSelectionMenuItemProvider : ISelectionMenuItemProvider
{
    public const string ActionTriggerCompletion = "trigger_completion";
    public const string ActionShowInlineSuggestion = "show_inline_suggestion";
    public const string ActionAcceptInlineSuggestion = "accept_inline_suggestion";
    public const string ActionDismissInlineSuggestion = "dismiss_inline_suggestion";
    public const string ActionToggleInlineSuggestionAuto = "toggle_inline_suggestion_auto";
    public const string ActionInsertSnippet = "insert_snippet";
    public const string ActionFoldAll = "fold_all";
    public const string ActionUnfoldAll = "unfold_all";
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
            items.Add(new SelectionMenuItem(SelectionMenuItem.ACTION_DELETE, "Delete", true));

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
        return items;
    }
}

internal sealed class DemoInlineSuggestionListener : IInlineSuggestionListener
{
    private readonly Action<string> updateStatus;

    public DemoInlineSuggestionListener(Action<string> updateStatus)
    {
        this.updateStatus = updateStatus;
    }

    public void OnSuggestionAccepted(InlineSuggestion suggestion)
        => updateStatus($"Accepted inline suggestion at {suggestion.Line}:{suggestion.Column}");

    public void OnSuggestionDismissed(InlineSuggestion suggestion)
        => updateStatus($"Dismissed inline suggestion at {suggestion.Line}:{suggestion.Column}");
}

internal sealed class DemoSelectionMenuListener : ISelectionMenuListener
{
    private readonly Action<string> onSelected;

    public DemoSelectionMenuListener(Action<string> onSelected)
    {
        this.onSelected = onSelected;
    }

    public void OnSelectionMenuItemSelected(string itemId)
    {
        onSelected(itemId);
    }
}

internal sealed class DemoIconProvider : EditorIconProvider
{
    private readonly Dictionary<int, IImage> icons = new();

    public DemoIconProvider()
    {
        TryLoadIcon(DemoDecorationProvider.IconType, "SweetEditor.Demo.Icons.ic_gutter_type.png");
        TryLoadIcon(DemoDecorationProvider.IconNote, "SweetEditor.Demo.Icons.ic_gutter_note.png");
    }

    public object? GetIcon(int iconId)
        => icons.TryGetValue(iconId, out IImage? icon) ? icon : null;

    private void TryLoadIcon(int iconId, string resourceName)
    {
        using Stream? stream = typeof(DemoIconProvider).Assembly.GetManifestResourceStream(resourceName);
        if (stream == null)
            return;

        icons[iconId] = new Bitmap(stream);
    }
}
