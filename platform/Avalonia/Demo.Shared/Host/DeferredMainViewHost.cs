using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;

namespace SweetEditor.Avalonia.Demo.Host;

public sealed class DeferredMainViewHost : UserControl
{
    private bool loadScheduled;

    public DeferredMainViewHost()
    {
        Content = BuildPlaceholder();
        AttachedToVisualTree += OnAttachedToVisualTree;
    }

    private void OnAttachedToVisualTree(object? sender, VisualTreeAttachmentEventArgs e)
    {
        if (loadScheduled)
            return;

        loadScheduled = true;
        Dispatcher.UIThread.Post(LoadMainView, DispatcherPriority.Background);
    }

    private void LoadMainView()
    {
        if (Content is MainView)
            return;

        DemoHostDiagnostics.WriteLine("DeferredMainViewHost.LoadMainView enter");
        try
        {
            Content = new MainView();
            DemoHostDiagnostics.WriteLine("DeferredMainViewHost.LoadMainView completed");
        }
        catch (Exception ex)
        {
            DemoHostDiagnostics.WriteException("DeferredMainViewHost.LoadMainView failed", ex);
            Content = BuildErrorPlaceholder(ex);
        }
    }

    private static Control BuildPlaceholder()
    {
        SolidColorBrush background = new(Color.FromUInt32(0xFF1B1E24));
        SolidColorBrush surface = new(Color.FromUInt32(0xFF242A33));
        SolidColorBrush border = new(Color.FromUInt32(0xFF313844));
        SolidColorBrush foreground = new(Color.FromUInt32(0xFFD7DEE9));
        SolidColorBrush secondary = new(Color.FromUInt32(0xFF7A8494));
        SolidColorBrush accent = new(Color.FromUInt32(0xFF4C9DFF));

        Border progressTrack = new()
        {
            Height = 4,
            Width = 168,
            Background = border,
            CornerRadius = new CornerRadius(999),
            Child = new Border
            {
                Width = 72,
                Height = 4,
                Background = accent,
                CornerRadius = new CornerRadius(999),
                HorizontalAlignment = HorizontalAlignment.Left,
            },
        };

        return new Border
        {
            Background = background,
            Child = new Grid
            {
                Children =
                {
                    new Border
                    {
                        Width = 232,
                        Padding = new Thickness(18, 16),
                        CornerRadius = new CornerRadius(18),
                        Background = surface,
                        BorderBrush = border,
                        BorderThickness = new Thickness(1),
                        HorizontalAlignment = HorizontalAlignment.Center,
                        VerticalAlignment = VerticalAlignment.Center,
                        Child = new StackPanel
                        {
                            Spacing = 8,
                            Children =
                            {
                                new TextBlock
                                {
                                    Text = "OpenSweetEditor",
                                    Foreground = foreground,
                                    FontSize = 17,
                                    FontWeight = FontWeight.SemiBold,
                                },
                                new TextBlock
                                {
                                    Text = "Initializing Avalonia host...",
                                    Foreground = secondary,
                                    FontSize = 12.5,
                                },
                                progressTrack,
                            },
                        },
                    },
                },
            },
        };
    }

    private static Control BuildErrorPlaceholder(Exception ex)
    {
        return new Border
        {
            Background = new SolidColorBrush(Color.FromUInt32(0xFF1B1E24)),
            Padding = new Thickness(20),
            Child = new StackPanel
            {
                Spacing = 10,
                Children =
                {
                    new TextBlock
                    {
                        Text = "OpenSweetEditor failed to initialize",
                        Foreground = new SolidColorBrush(Color.FromUInt32(0xFFF7768E)),
                        FontSize = 18,
                        FontWeight = FontWeight.SemiBold,
                    },
                    new TextBlock
                    {
                        Text = ex.GetType().Name,
                        Foreground = new SolidColorBrush(Color.FromUInt32(0xFFD7DEE9)),
                        FontSize = 14,
                    },
                    new TextBlock
                    {
                        Text = ex.Message,
                        Foreground = new SolidColorBrush(Color.FromUInt32(0xFF9AA4B2)),
                        TextWrapping = TextWrapping.Wrap,
                    },
                    new TextBlock
                    {
                        Text = $"Log: {DemoHostDiagnostics.GetLogFilePath()}",
                        Foreground = new SolidColorBrush(Color.FromUInt32(0xFF7A8494)),
                        FontSize = 12,
                        TextWrapping = TextWrapping.Wrap,
                    },
                },
            },
        };
    }
}
