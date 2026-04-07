using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;

namespace SweetEditor.Avalonia.Demo.UI;

public sealed class KeyboardShortcutsDialog : Window
{
    public KeyboardShortcutsDialog()
    {
        Title = "Keyboard Shortcuts";
        Width = 500;
        SizeToContent = SizeToContent.Height;
        CanResize = false;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;

        Background = new SolidColorBrush(Color.Parse("#1B1E24"));
        Foreground = new SolidColorBrush(Color.Parse("#D7DEE9"));

        BuildLayout();
    }

    private void BuildLayout()
    {
        ScrollViewer scrollViewer = new()
        {
            MaxHeight = 500,
            Padding = new Thickness(16),
        };

        StackPanel content = new()
        {
            Spacing = 16,
        };

        content.Children.Add(BuildSection("Editor Navigation", new[]
        {
            ("Ctrl+Home", "Go to beginning of document"),
            ("Ctrl+End", "Go to end of document"),
            ("Ctrl+G", "Go to line"),
            ("Ctrl+↑/↓", "Scroll line up/down"),
            ("Ctrl+U", "Undo cursor position"),
        }));

        content.Children.Add(BuildSection("Editing", new[]
        {
            ("Ctrl+Z", "Undo"),
            ("Ctrl+Y / Ctrl+Shift+Z", "Redo"),
            ("Ctrl+X", "Cut"),
            ("Ctrl+C", "Copy"),
            ("Ctrl+V", "Paste"),
            ("Ctrl+D", "Duplicate line"),
            ("Ctrl+Shift+K", "Delete line"),
            ("Ctrl+Enter", "Insert line below"),
            ("Ctrl+Shift+Enter", "Insert line above"),
            ("Ctrl+Shift+\\", "Jump to matching bracket"),
        }));

        content.Children.Add(BuildSection("Selection", new[]
        {
            ("Ctrl+A", "Select all"),
            ("Ctrl+L", "Select line"),
            ("Shift+Alt+→", "Expand selection"),
            ("Shift+Alt+←", "Shrink selection"),
            ("Ctrl+Shift+L", "Select all occurrences"),
        }));

        content.Children.Add(BuildSection("Search & Replace", new[]
        {
            ("Ctrl+F", "Find"),
            ("Ctrl+H", "Replace"),
            ("F3 / Shift+F3", "Find next/previous"),
            ("Ctrl+Shift+F", "Find in files"),
        }));

        content.Children.Add(BuildSection("Code Editing", new[]
        {
            ("F1", "Trigger code completion"),
            ("F2", "Show inline suggestion"),
            ("F3", "Insert code snippet"),
            ("Ctrl+/", "Toggle line comment"),
            ("Ctrl+Shift+/", "Toggle block comment"),
            ("Tab", "Accept suggestion / Indent"),
            ("Shift+Tab", "Outdent"),
        }));

        content.Children.Add(BuildSection("View", new[]
        {
            ("Ctrl++", "Zoom in"),
            ("Ctrl+-", "Zoom out"),
            ("Ctrl+0", "Reset zoom"),
            ("Ctrl+B", "Toggle sidebar"),
            ("F11", "Toggle full screen"),
        }));

        content.Children.Add(BuildSection("Demo Features", new[]
        {
            ("Ctrl+K, Ctrl+D", "Trigger completion (host keymap)"),
            ("Ctrl+K, Ctrl+I", "Show inline suggestion"),
            ("Ctrl+K, Ctrl+S", "Insert snippet"),
            ("Ctrl+K, Ctrl+F", "Toggle fold"),
        }));

        scrollViewer.Content = content;

        Button closeButton = new()
        {
            Content = "Close",
            HorizontalAlignment = HorizontalAlignment.Right,
            Background = new SolidColorBrush(Color.Parse("#4C9DFF")),
            Foreground = new SolidColorBrush(Colors.White),
            Padding = new Thickness(24, 8),
            CornerRadius = new CornerRadius(8),
            Margin = new Thickness(0, 16, 16, 16),
        };
        closeButton.Click += (_, _) => Close();

        Grid mainGrid = new()
        {
            RowDefinitions = new RowDefinitions("*,Auto"),
        };
        Grid.SetRow(scrollViewer, 0);
        Grid.SetRow(closeButton, 1);
        mainGrid.Children.Add(scrollViewer);
        mainGrid.Children.Add(closeButton);

        Content = mainGrid;
    }

    private Control BuildSection(string title, (string Key, string Description)[] shortcuts)
    {
        StackPanel section = new()
        {
            Spacing = 8,
        };

        TextBlock titleText = new()
        {
            Text = title,
            FontSize = 14,
            FontWeight = FontWeight.SemiBold,
            Foreground = new SolidColorBrush(Color.Parse("#4C9DFF")),
        };
        section.Children.Add(titleText);

        Grid shortcutsGrid = new()
        {
            ColumnDefinitions = new ColumnDefinitions("Auto,*"),
        };

        for (int i = 0; i < shortcuts.Length; i++)
        {
            shortcutsGrid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        }

        for (int i = 0; i < shortcuts.Length; i++)
        {
            (string key, string description) = shortcuts[i];

            Border keyBadge = new()
            {
                Background = new SolidColorBrush(Color.Parse("#242A33")),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(8, 4),
                Margin = new Thickness(0, 2, 8, 2),
                HorizontalAlignment = HorizontalAlignment.Left,
                Child = new TextBlock
                {
                    Text = key,
                    FontSize = 11,
                    FontWeight = FontWeight.Medium,
                    Foreground = new SolidColorBrush(Color.Parse("#D7DEE9")),
                    FontFamily = FontFamily.Parse("monospace"),
                },
            };
            Grid.SetRow(keyBadge, i);
            shortcutsGrid.Children.Add(keyBadge);

            TextBlock descText = new()
            {
                Text = description,
                FontSize = 12,
                Foreground = new SolidColorBrush(Color.Parse("#7A8494")),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 4, 0, 4),
            };
            Grid.SetRow(descText, i);
            Grid.SetColumn(descText, 1);
            shortcutsGrid.Children.Add(descText);
        }

        section.Children.Add(shortcutsGrid);
        return section;
    }

    public static void Open(Window owner)
    {
        KeyboardShortcutsDialog dialog = new();
        dialog.ShowDialog(owner);
    }
}
