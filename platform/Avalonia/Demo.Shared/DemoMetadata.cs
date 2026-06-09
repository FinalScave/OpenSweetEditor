using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoMetadata : IEditorMetadata
{
    public string FilePath { get; }
    public string? InitialText { get; }

    public DemoMetadata(string filePath, string? initialText = null)
    {
        FilePath = filePath;
        InitialText = initialText;
    }
}
