using System;
using Avalonia;
using Avalonia.Controls;
using SweetEditor.Avalonia.Demo.Host;

namespace SweetEditor.Avalonia.Demo.Mac.Platform;

/// <summary>
/// macOS platform services implementation.
/// </summary>
internal sealed class MacDemoPlatformServices : IDemoPlatformServices, IDisposable
{
    public bool IsAndroid => false;

    public bool TryGetImeTopInEditorHostDip(Visual visual, Control editorHost, out double imeTopInHostDip)
    {
        imeTopInHostDip = double.PositiveInfinity;
        return false;
    }

    public void Dispose()
    {
    }
}
