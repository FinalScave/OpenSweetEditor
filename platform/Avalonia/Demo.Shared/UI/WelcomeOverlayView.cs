using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using AvaPath = Avalonia.Controls.Shapes.Path;

namespace SweetEditor.Avalonia.Demo.UI;

public sealed class WelcomeOverlayView : Border
{
    private const string WelcomeIcon = "M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zm1,15h-2v-6h2v6zm0,-8h-2V7h2v2z";
    private const string KeyboardIcon = "M20,5H4c-1.1,0 -1.99,0.9 -1.99,2L2,17c0,1.1 0.9,2 2,2h16c1.1,0 2,-0.9 2,-2V7c0,-1.1 -0.9,-2 -2,-2zm-9,3h2v2h-2V8zm0,3h2v2h-2v-2zM8,8h2v2H8V8zm0,3h2v2H8v-2zm-1,2H5v-2h2v2zm0,-3H5V8h2v2zm9,7H8v-2h8v2zm0,-4h-2v-2h2v2zm0,-3h-2V8h2v2zm3,3h-2v-2h2v2zm0,-3h-2V8h2v2z";
    private const string MouseIcon = "M13,3v6h8l0,0C20.26,5.63 16.99,3.22 13,3zM13,10v8l0,0c4.41,0 8,-3.59 8,-8l0,0H13zM11,3C6.59,3 3,6.59 3,11c0,4.41 3.59,8 8,8v-8V3z";
    private const string TouchIcon = "M9,11.24V7.5C9,6.12 10.12,5 11.5,5S14,6.12 14,7.5v3.74c1.21,-0.81 2,-2.18 2,-3.74C16,5.01 13.99,3 11.5,3S7,5.01 7,7.5C7,9.06 7.79,10.43 9,11.24zM18.84,15.87l-4.54,-2.26c-0.17,-0.07 -0.35,-0.11 -0.54,-0.11H13v-6c0,-0.83 -0.67,-1.5 -1.5,-1.5S10,6.67 10,7.5v10.74l-3.43,-0.72c-0.08,-0.01 -0.15,-0.03 -0.24,-0.03 -0.31,0 -0.59,0.13 -0.79,0.33l-0.79,0.8 4.94,4.94c0.27,0.27 0.65,0.44 1.06,0.44h6.79c0.75,0 1.33,-0.55 1.44,-1.28l0.75,-5.27c0.01,-0.07 0.02,-0.14 0.02,-0.21 0,-0.59 -0.34,-1.1 -0.91,-1.33z";

    public event Action? CloseRequested;
    public event Action? DontShowAgainRequested;

    public WelcomeOverlayView()
    {
        BuildLayout();
    }

    private void BuildLayout()
    {
        Background = CreateBrush(0xE0182231);
        CornerRadius = new CornerRadius(16);
        Padding = new Thickness(32);
        MaxWidth = 640;
        MaxHeight = 520;
        HorizontalAlignment = HorizontalAlignment.Center;
        VerticalAlignment = VerticalAlignment.Center;

        StackPanel content = new()
        {
            Spacing = 20,
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };

        content.Children.Add(BuildHeader());
        content.Children.Add(BuildShortcutsSection());
        content.Children.Add(BuildActionsSection());

        Child = content;
    }

    private Control BuildHeader()
    {
        Grid header = new()
        {
            ColumnDefinitions = new ColumnDefinitions("Auto,*"),
            ColumnSpacing = 16,
        };

        AvaPath icon = new()
        {
            Data = Geometry.Parse(WelcomeIcon),
            Fill = CreateBrush(0xFF4C9DFF),
            Width = 48,
            Height = 48,
            VerticalAlignment = VerticalAlignment.Center,
        };
        header.Children.Add(icon);

        StackPanel text = new()
        {
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(text, 1);

        text.Children.Add(new TextBlock
        {
            Text = "Welcome to SweetEditor Demo",
            FontSize = 24,
            FontWeight = FontWeight.Bold,
            Foreground = CreateBrush(0xFFD7DEE9),
        });

        text.Children.Add(new TextBlock
        {
            Text = "A high-performance code editor built with Avalonia",
            FontSize = 13,
            Foreground = CreateBrush(0xFF7A8494),
            Margin = new Thickness(0, 4, 0, 0),
        });

        header.Children.Add(text);
        return header;
    }

    private Control BuildShortcutsSection()
    {
        StackPanel section = new()
        {
            Spacing = 12,
        };

        section.Children.Add(new TextBlock
        {
            Text = "Keyboard Shortcuts",
            FontSize = 14,
            FontWeight = FontWeight.SemiBold,
            Foreground = CreateBrush(0xFFD7DEE9),
        });

        Grid shortcuts = new()
        {
            ColumnDefinitions = new ColumnDefinitions("*,*"),
            RowDefinitions = new RowDefinitions("Auto,Auto,Auto,Auto"),
        };

        AddShortcutRow(shortcuts, 0, "F1", "Trigger code completion");
        AddShortcutRow(shortcuts, 1, "F2", "Show inline suggestion");
        AddShortcutRow(shortcuts, 2, "F3", "Insert code snippet");
        AddShortcutRow(shortcuts, 3, "Ctrl+Z/Y", "Undo / Redo");

        section.Children.Add(shortcuts);
        return section;
    }

    private Control BuildActionsSection()
    {
        StackPanel section = new()
        {
            Spacing = 12,
        };

        section.Children.Add(new TextBlock
        {
            Text = "Touch & Mouse Interactions",
            FontSize = 14,
            FontWeight = FontWeight.SemiBold,
            Foreground = CreateBrush(0xFFD7DEE9),
        });

        Grid actions = new()
        {
            ColumnDefinitions = new ColumnDefinitions("Auto,*"),
            RowDefinitions = new RowDefinitions("Auto,Auto,Auto"),
            ColumnSpacing = 12,
            RowSpacing = 8,
        };

        AddActionRow(actions, 0, MouseIcon, "Double-click", "Select word under cursor");
        AddActionRow(actions, 1, TouchIcon, "Long press", "Show selection menu");
        AddActionRow(actions, 2, KeyboardIcon, "Tab", "Accept inline suggestion");

        section.Children.Add(actions);
        section.Children.Add(BuildButtons());
        return section;
    }

    private Control BuildButtons()
    {
        StackPanel buttons = new()
        {
            Orientation = Orientation.Horizontal,
            Spacing = 12,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 16, 0, 0),
        };

        CheckBox dontShowAgain = new()
        {
            Content = "Don't show again",
            Foreground = CreateBrush(0xFF7A8494),
            VerticalAlignment = VerticalAlignment.Center,
        };
        dontShowAgain.IsCheckedChanged += (_, _) =>
        {
            if (dontShowAgain.IsChecked == true)
                DontShowAgainRequested?.Invoke();
        };
        buttons.Children.Add(dontShowAgain);

        Button closeButton = new()
        {
            Content = "Get Started",
            Background = CreateBrush(0xFF4C9DFF),
            Foreground = CreateBrush(0xFFFFFFFF),
            Padding = new Thickness(20, 10),
            CornerRadius = new CornerRadius(8),
            FontWeight = FontWeight.SemiBold,
        };
        closeButton.Click += (_, _) => CloseRequested?.Invoke();
        buttons.Children.Add(closeButton);

        return buttons;
    }

    private static void AddShortcutRow(Grid grid, int row, string key, string description)
    {
        Border keyBadge = new()
        {
            Background = CreateBrush(0xFF242A33),
            CornerRadius = new CornerRadius(4),
            Padding = new Thickness(8, 4),
            HorizontalAlignment = HorizontalAlignment.Left,
            Child = new TextBlock
            {
                Text = key,
                FontSize = 12,
                FontWeight = FontWeight.SemiBold,
                Foreground = CreateBrush(0xFF4C9DFF),
                FontFamily = FontFamily.Parse("monospace"),
            },
        };
        Grid.SetRow(keyBadge, row);
        grid.Children.Add(keyBadge);

        TextBlock desc = new()
        {
            Text = description,
            FontSize = 12,
            Foreground = CreateBrush(0xFF7A8494),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(8, 0, 0, 0),
        };
        Grid.SetRow(desc, row);
        Grid.SetColumn(desc, 1);
        grid.Children.Add(desc);
    }

    private static void AddActionRow(Grid grid, int row, string iconData, string action, string description)
    {
        AvaPath icon = new()
        {
            Data = Geometry.Parse(iconData),
            Fill = CreateBrush(0xFF4C9DFF),
            Width = 16,
            Height = 16,
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetRow(icon, row);
        grid.Children.Add(icon);

        TextBlock text = new()
        {
            Text = $"{action} - {description}",
            FontSize = 12,
            Foreground = CreateBrush(0xFF7A8494),
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetRow(text, row);
        Grid.SetColumn(text, 1);
        grid.Children.Add(text);
    }

    private static SolidColorBrush CreateBrush(uint argb) => new(Color.FromUInt32(argb));
}
