namespace SweetEditor.Avalonia.Demo;

/// <summary>
/// Shared platform probes used by the demo.
/// </summary>
public static class DemoPlatformServices
{
    /// <summary>
    /// Indicates whether the current platform is Android.
    /// </summary>
    public static bool IsAndroid => OperatingSystem.IsAndroid();
}
