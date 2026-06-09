using System;
using System.Text;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

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
            : "	";

        if (trimmed.EndsWith("{", StringComparison.Ordinal))
        {
            return new NewLineAction(Environment.NewLine + indent + unit + Environment.NewLine + indent);
        }

        if (trimmed.EndsWith("(", StringComparison.Ordinal) || trimmed.EndsWith("[", StringComparison.Ordinal))
        {
            return new NewLineAction(Environment.NewLine + indent + unit);
        }

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
        while (length < line.Length && (line[length] == ' ' || line[length] == '	'))
            length++;

        return length == 0 ? string.Empty : line[..length];
    }
}
