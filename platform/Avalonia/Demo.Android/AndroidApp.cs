using System;
using Android.App;
using Android.Runtime;
using Avalonia;
using Avalonia.Android;
using SweetEditor.Avalonia.Demo;

namespace SweetEditor.Avalonia.Demo.Android;

[Application]
public sealed class AndroidApp : AvaloniaAndroidApplication<App>
{
    public AndroidApp(IntPtr javaReference, JniHandleOwnership transfer)
        : base(javaReference, transfer)
    {
    }

    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        DemoHostDiagnostics.WriteLine("AndroidApp.CustomizeAppBuilder");
        return base.CustomizeAppBuilder(builder)
            .With(new AndroidPlatformOptions
            {
                RenderingMode =
                [
                    AndroidRenderingMode.Egl,
                    AndroidRenderingMode.Software,
                ],
            });
    }
}
