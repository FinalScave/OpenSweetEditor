using Foundation;

[assembly: ExportAssembly]

namespace SweetEditor.Avalonia.Demo.iOS;

public static class Program
{
    private static void Main(string[] args)
    {
        UIApplication.Main(args, null, typeof(AppDelegate));
    }
}
