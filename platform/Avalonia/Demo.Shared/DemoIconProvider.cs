using System.Collections.Generic;
using System.IO;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

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
