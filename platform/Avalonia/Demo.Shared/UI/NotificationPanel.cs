using System;
using System.Collections.Generic;
using Avalonia;
using Avalonia.Animation;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;

namespace SweetEditor.Avalonia.Demo.UI;

public enum NotificationType
{
    Info,
    Success,
    Warning,
    Error,
}

public sealed class NotificationPanel : Border
{
    private readonly StackPanel itemsPanel;
    private readonly List<NotificationItem> items = new();
    private const int MaxNotifications = 5;
    private const double NotificationDurationMs = 4000;

    public static readonly StyledProperty<bool> DarkThemeProperty =
        AvaloniaProperty.Register<NotificationPanel, bool>(nameof(DarkTheme), true);

    public bool DarkTheme
    {
        get => GetValue(DarkThemeProperty);
        set => SetValue(DarkThemeProperty, value);
    }

    public NotificationPanel()
    {
        HorizontalAlignment = HorizontalAlignment.Right;
        VerticalAlignment = VerticalAlignment.Top;
        Margin = new Thickness(0, 60, 16, 0);
        MaxWidth = 360;
        ZIndex = 100;

        itemsPanel = new StackPanel
        {
            Spacing = 8,
        };
        Child = itemsPanel;
    }

    public void ShowNotification(string message, NotificationType type = NotificationType.Info)
    {
        Dispatcher.UIThread.Post(() =>
        {
            var item = new NotificationItem(message, type, DarkTheme);
            item.Closed += () => RemoveNotification(item);
            items.Add(item);
            itemsPanel.Children.Add(item);

            if (items.Count > MaxNotifications)
            {
                var oldest = items[0];
                items.RemoveAt(0);
                itemsPanel.Children.Remove(oldest);
            }
        });
    }

    public void ShowError(string message, Exception? exception = null)
    {
        string fullMessage = exception != null
            ? $"{message}\n{exception.Message}"
            : message;
        ShowNotification(fullMessage, NotificationType.Error);
    }

    public void ShowSuccess(string message)
    {
        ShowNotification(message, NotificationType.Success);
    }

    public void ShowWarning(string message)
    {
        ShowNotification(message, NotificationType.Warning);
    }

    public void ShowInfo(string message)
    {
        ShowNotification(message, NotificationType.Info);
    }

    private void RemoveNotification(NotificationItem item)
    {
        Dispatcher.UIThread.Post(() =>
        {
            items.Remove(item);
            itemsPanel.Children.Remove(item);
        });
    }

    protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change)
    {
        base.OnPropertyChanged(change);
        if (change.Property == DarkThemeProperty)
        {
            foreach (var item in items)
            {
                item.UpdateTheme(DarkTheme);
            }
        }
    }
}

public sealed class NotificationItem : Border
{
    private readonly TextBlock messageText;
    private readonly DispatcherTimer closeTimer;
    private readonly NotificationType type;
    private bool darkTheme;

    public event Action? Closed;

    public NotificationItem(string message, NotificationType notificationType, bool isDarkTheme)
    {
        type = notificationType;
        darkTheme = isDarkTheme;

        CornerRadius = new CornerRadius(8);
        Padding = new Thickness(16, 12);
        Margin = new Thickness(0);
        BorderThickness = new Thickness(1);

        Grid content = new()
        {
            ColumnDefinitions = new ColumnDefinitions("Auto,*"),
            ColumnSpacing = 12,
        };

        TextBlock icon = new()
        {
            Text = GetIcon(notificationType),
            FontSize = 16,
            VerticalAlignment = VerticalAlignment.Center,
        };
        content.Children.Add(icon);

        messageText = new TextBlock
        {
            Text = message,
            FontSize = 13,
            TextWrapping = TextWrapping.Wrap,
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(messageText, 1);
        content.Children.Add(messageText);

        Child = content;
        UpdateColors();

        closeTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(4000),
        };
        closeTimer.Tick += (_, _) => Close();
        closeTimer.Start();

        PointerEntered += (_, _) => closeTimer.Stop();
        PointerExited += (_, _) => closeTimer.Start();
    }

    public void UpdateTheme(bool isDarkTheme)
    {
        darkTheme = isDarkTheme;
        UpdateColors();
    }

    private void UpdateColors()
    {
        (uint bg, uint border, uint fg, uint iconColor) = type switch
        {
            NotificationType.Success => darkTheme
                ? (0xFF1A3328u, 0xFF2D5A47u, 0xFFA8D5BAu, 0xFF4CAF50u)
                : (0xFFE8F5E9u, 0xFFA5D6A7u, 0xFF2E7D32u, 0xFF4CAF50u),
            NotificationType.Warning => darkTheme
                ? (0xFF33291Au, 0xFF5A4A2Du, 0xFFD5C4A8u, 0xFFFF9800u)
                : (0xFFFFF3E0u, 0xFFFFCC80u, 0xFFE65100u, 0xFFFF9800u),
            NotificationType.Error => darkTheme
                ? (0xFF331A1Au, 0xFF5A2D2Du, 0xFFD5A8A8u, 0xFFF44336u)
                : (0xFFFFEBEEu, 0xFFEF9A9Au, 0xFFC62828u, 0xFFF44336u),
            _ => darkTheme
                ? (0xFF1A2333u, 0xFF2D3A5Au, 0xFFA8B8D5u, 0xFF2196F3u)
                : (0xFFE3F2FDu, 0xFF90CAF9u, 0xFF1565C0u, 0xFF2196F3u),
        };

        Background = new SolidColorBrush(Color.FromUInt32(bg));
        BorderBrush = new SolidColorBrush(Color.FromUInt32(border));
        messageText.Foreground = new SolidColorBrush(Color.FromUInt32(fg));

        if (Child is Grid grid && grid.Children[0] is TextBlock icon)
        {
            icon.Foreground = new SolidColorBrush(Color.FromUInt32(iconColor));
        }
    }

    private static string GetIcon(NotificationType notificationType) => notificationType switch
    {
        NotificationType.Success => "✓",
        NotificationType.Warning => "⚠",
        NotificationType.Error => "✕",
        _ => "ℹ",
    };

    public void Close()
    {
        closeTimer.Stop();
        Closed?.Invoke();
    }
}

public sealed class ErrorDialog : Window
{
    public ErrorDialog(string title, string message, string? details = null)
    {
        Title = title;
        Width = 420;
        SizeToContent = SizeToContent.Height;
        CanResize = false;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;

        Background = new SolidColorBrush(Color.Parse("#1B1E24"));
        Foreground = new SolidColorBrush(Color.Parse("#D7DEE9"));

        StackPanel content = new()
        {
            Margin = new Thickness(24),
            Spacing = 16,
        };

        TextBlock messageText = new()
        {
            Text = message,
            FontSize = 14,
            TextWrapping = TextWrapping.Wrap,
        };
        content.Children.Add(messageText);

        if (!string.IsNullOrEmpty(details))
        {
            Border detailsBorder = new()
            {
                Background = new SolidColorBrush(Color.Parse("#242A33")),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(12),
                MaxHeight = 200,
            };

            ScrollViewer scrollViewer = new()
            {
                Content = new TextBlock
                {
                    Text = details,
                    FontSize = 11,
                    FontFamily = FontFamily.Parse("monospace"),
                    TextWrapping = TextWrapping.Wrap,
                    Foreground = new SolidColorBrush(Color.Parse("#7A8494")),
                },
            };
            detailsBorder.Child = scrollViewer;
            content.Children.Add(detailsBorder);
        }

        Button closeButton = new()
        {
            Content = "Close",
            HorizontalAlignment = HorizontalAlignment.Right,
            Background = new SolidColorBrush(Color.Parse("#4C9DFF")),
            Foreground = new SolidColorBrush(Colors.White),
            Padding = new Thickness(24, 8),
            CornerRadius = new CornerRadius(8),
        };
        closeButton.Click += (_, _) => Close();
        content.Children.Add(closeButton);

        Content = content;
    }

    public static void Show(Window owner, string title, string message, string? details = null)
    {
        var dialog = new ErrorDialog(title, message, details);
        dialog.ShowDialog(owner);
    }
}
