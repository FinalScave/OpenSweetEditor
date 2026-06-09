using System;
using System.Collections.Generic;
using System.Threading.Tasks;
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

        string word = context.WordRange is TextRange wordRange
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
        SortKey = "a_vector"
    },
    new CompletionItem
    {
        Label = "std::string",
        Detail = "class",
        InsertText = "std::string",
        Kind = CompletionItem.KIND_CLASS,
        SortKey = "b_string"
    },
    new CompletionItem
    {
        Label = "if",
        Detail = "snippet",
        InsertText = "if (${1:condition})\n{\n    $0\n}",
        InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
        Kind = CompletionItem.KIND_SNIPPET,
        SortKey = "c_if"
    },
    new CompletionItem
    {
        Label = "for",
        Detail = "snippet",
        InsertText = "for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i})\n{\n    $0\n}",
        InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
        Kind = CompletionItem.KIND_SNIPPET,
        SortKey = "d_for"
    },
    new CompletionItem
    {
        Label = "class",
        Detail = "snippet",
        InsertText = "class ${1:TypeName}\n{\npublic:\n    ${1:TypeName}();\n    ~$1();\n\nprivate:\n    $0\n};",
        InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
        Kind = CompletionItem.KIND_SNIPPET,
        SortKey = "e_class"
    },
    new CompletionItem
    {
        Label = "TODO",
        Detail = "comment",
        InsertText = "TODO: ",
        Kind = CompletionItem.KIND_TEXT,
        SortKey = "f_todo"
    },
    new CompletionItem
    {
        Label = "#region",
        Detail = "fold marker",
        InsertText = "#region ${1:name}\n$0\n#endregion",
        InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET,
        Kind = CompletionItem.KIND_SNIPPET,
        SortKey = "g_region"
    },
};
}
