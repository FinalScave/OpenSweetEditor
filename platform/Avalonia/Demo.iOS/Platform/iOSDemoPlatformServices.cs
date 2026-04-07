using Avalonia;
using Avalonia.Controls;
using SweetEditor.Avalonia.Demo.Host;
using UIKit;

namespace SweetEditor.Avalonia.Demo.iOS.Platform;

internal sealed class iOSDemoPlatformServices : IDemoPlatformServices
{
    public bool IsAndroid => false;

    public bool TryGetImeTopInEditorHostDip(Visual visual, Control editorHost, out double imeTopInHostDip)
    {
        imeTopInHostDip = double.PositiveInfinity;
        
        var window = UIApplication.SharedApplication.KeyWindow;
        if (window == null)
            return false;

        var keyboardFrame = UIKeyboard.FrameEndForKeyboard;
        if (keyboardFrame.Height <= 0)
            return false;

        double scale = window.Screen.Scale;
        double keyboardTop = keyboardFrame.Top / scale;

        if (TopLevel.GetTopLevel(visual) is TopLevel topLevel)
        {
            double hostTop = 0;
            Point? hostOrigin = editorHost.TranslatePoint(new Point(0, 0), topLevel);
            if (hostOrigin.HasValue)
                hostTop = hostOrigin.Value.Y;

            imeTopInHostDip = keyboardTop - hostTop;
            return imeTopInHostDip > 0;
        }

        return false;
    }
}
