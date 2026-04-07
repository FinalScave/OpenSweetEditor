using System;
using Avalonia;
using Avalonia.Controls;
using SweetEditor.Avalonia.Demo.Host;

namespace SweetEditor.Avalonia.Demo.Android.Platform;

/// <summary>
/// Android platform services implementation.
/// Provides Android-specific functionality for the demo application.
/// </summary>
internal sealed class AndroidDemoPlatformServices : IDemoPlatformServices
{
    public bool IsAndroid => true;

    public bool TryGetImeTopInEditorHostDip(Visual visual, Control editorHost, out double imeTopInHostDip)
    {
        imeTopInHostDip = double.PositiveInfinity;

        if (!MainActivity.TryGetVisibleFrameAndImeTop(out global::Android.Graphics.Rect visibleFrame, out int imeTopOnScreen))
            return false;

        TopLevel? topLevel = TopLevel.GetTopLevel(visual) ?? TopLevel.GetTopLevel(editorHost);
        double scale = topLevel?.RenderScaling ?? 1.0;
        if (scale <= 0)
            scale = 1.0;

        if (imeTopOnScreen <= visibleFrame.Top)
            return false;

        double imeTopInWindowDip = (imeTopOnScreen - visibleFrame.Top) / scale;

        double hostTopDip = 0;
        if (topLevel != null)
        {
            Point? hostOrigin = editorHost.TranslatePoint(new Point(0, 0), topLevel);
            if (hostOrigin.HasValue)
                hostTopDip = hostOrigin.Value.Y;
        }

        imeTopInHostDip = imeTopInWindowDip - hostTopDip;
        return imeTopInHostDip > 0;
    }

    public void Dispose()
    {
    }
}
