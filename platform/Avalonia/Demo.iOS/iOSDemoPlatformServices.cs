using System;
using Avalonia;
using Avalonia.Controls;
using CoreGraphics;
using Foundation;
using SweetEditor.Avalonia.Demo;
using UIKit;

namespace SweetEditor.Avalonia.Demo.iOS;

internal sealed class iOSDemoPlatformServices : IDemoPlatformServices
{
    private readonly NSObject keyboardWillChangeFrameObserver;
    private readonly NSObject keyboardWillHideObserver;
    private CGRect keyboardFrameInScreen;
    private bool isKeyboardVisible;

    public iOSDemoPlatformServices()
    {
        keyboardWillChangeFrameObserver = UIKeyboard.Notifications.ObserveWillChangeFrame((_, args) =>
        {
            keyboardFrameInScreen = args.FrameEnd;
            isKeyboardVisible = args.FrameEnd.Height > 0;
        });
        keyboardWillHideObserver = UIKeyboard.Notifications.ObserveWillHide((_, _) =>
        {
            keyboardFrameInScreen = CGRect.Empty;
            isKeyboardVisible = false;
        });
    }

    public bool IsAndroid => false;

    public bool TryGetImeTopInEditorHostDip(Visual visual, Control editorHost, out double imeTopInHostDip)
    {
        imeTopInHostDip = double.PositiveInfinity;

        if (!isKeyboardVisible || keyboardFrameInScreen.Height <= 0)
            return false;

        UIWindow? window = UIApplication.SharedApplication.KeyWindow;
        if (window == null)
            return false;

        CGRect keyboardFrameInWindow = window.ConvertRectFromCoordinateSpace(keyboardFrameInScreen, window.Screen.CoordinateSpace);
        double keyboardTop = keyboardFrameInWindow.Top;

        TopLevel? topLevel = TopLevel.GetTopLevel(visual) ?? TopLevel.GetTopLevel(editorHost);
        if (topLevel == null)
            return false;

        Point? hostOrigin = editorHost.TranslatePoint(new Point(0, 0), topLevel);
        double hostTop = hostOrigin?.Y ?? 0;

        imeTopInHostDip = keyboardTop - hostTop;
        return imeTopInHostDip > 0;
    }

    public void Dispose()
    {
        keyboardWillChangeFrameObserver.Dispose();
        keyboardWillHideObserver.Dispose();
    }
}
