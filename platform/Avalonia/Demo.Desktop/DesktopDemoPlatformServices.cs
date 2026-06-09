using System;
using Avalonia;
using Avalonia.Controls;
using SweetEditor.Avalonia.Demo;

namespace SweetEditor.Avalonia.Demo.Desktop;

/// <summary>
/// Desktop platform services implementation.
/// Provides common functionality for Windows, Linux, and macOS.
/// </summary>
internal sealed class DesktopDemoPlatformServices : IDemoPlatformServices, IDisposable
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
