using System;
using Avalonia;
using Avalonia.Controls;

namespace SweetEditor.Avalonia.Demo.Host;

/// <summary>
/// Platform-specific services interface.
/// Each platform (Desktop, Android, iOS, Mac) provides its own implementation.
/// </summary>
public interface IDemoPlatformServices : IDisposable
{
    /// <summary>
    /// Indicates whether the current platform is Android.
    /// </summary>
    bool IsAndroid { get; }

    /// <summary>
    /// Tries to get the IME (keyboard) top position in editor host coordinates.
    /// </summary>
    /// <param name="visual">The visual element.</param>
    /// <param name="editorHost">The editor host control.</param>
    /// <param name="imeTopInHostDip">The IME top position in DIPs.</param>
    /// <returns>True if the position was successfully retrieved.</returns>
    bool TryGetImeTopInEditorHostDip(Visual visual, Control editorHost, out double imeTopInHostDip);
}

/// <summary>
/// Global accessor for platform services.
/// </summary>
public static class DemoPlatformServices
{
    /// <summary>
    /// Gets or sets the current platform services implementation.
    /// </summary>
    public static IDemoPlatformServices? Current { get; set; }
}
