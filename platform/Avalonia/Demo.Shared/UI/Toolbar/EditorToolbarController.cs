using System.Collections.Generic;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using SweetEditor;
using AvaPath = Avalonia.Controls.Shapes.Path;

namespace SweetEditor.Avalonia.Demo.UI.Toolbar;

public sealed class EditorToolbarController
{
    private const string UndoIcon = "M12.5,8c-2.65,0 -5.05,0.99 -6.9,2.6L2,7v9h9l-3.62,-3.62c1.39,-1.16 3.16,-1.88 5.12,-1.88 3.54,0 6.55,2.31 7.6,5.5l2.37,-0.78C21.08,11.03 17.15,8 12.5,8z";
    private const string RedoIcon = "M18.4,10.6C16.55,8.99 14.15,8 11.5,8c-4.65,0 -8.58,3.03 -9.96,7.22L3.9,16c1.05,-3.19 4.05,-5.5 7.6,-5.5 1.95,0 3.73,0.72 5.12,1.88L13,16h9V7l-3.6,3.6z";
    private const string ThemeIcon = "M20,8.69V4h-4.69L12,0.69 8.69,4H4v4.69L0.69,12 4,15.31V20h4.69L12,23.31 15.31,20H20v-4.69L23.31,12 20,8.69zM12,18c-3.31,0 -6,-2.69 -6,-6s2.69,-6 6,-6 6,2.69 6,6 -2.69,6 -6,6zM12,8v8c2.21,0 4,-1.79 4,-4s-1.79,-4 -4,-4z";
    private const string WrapIcon = "M4,19h6v-2H4v2zM20,5H4v2h16V5zM17,11H4v2h13.25c1.1,0 2,0.9 2,2s-0.9,2 -2,2H15v-2l-3,3 3,3v-2h2.25c2.21,0 4,-1.79 4,-4s-1.79,-4 -4,-4z";
    private const string ChevronDownIcon = "M7,10l5,5 5,-5";
    private const string HelpIcon = "M11,18h2v-2h-2v2zM12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM12,20c-4.41,0 -8,-3.59 -8,-8s3.59,-8 8,-8 8,3.59 8,8 -3.59,8 -8,8zM12,6c-2.21,0 -4,1.79 -4,4h2c0,-1.1 0.9,-2 2,-2s2,0.9 2,2c0,2 -3,1.75 -3,5h2c0,-2.25 3,-2.5 3,-5 0,-2.21 -1.79,-4 -4,-4z";

    private readonly TextBlock wrapBadgeText;
    private readonly TextBlock samplePickerLabel;
    private readonly AvaPath samplePickerChevron;
    private readonly Border samplePickerChrome;

    public EditorToolbarController()
    {
        UndoButton = CreateIconButton(UndoIcon, "Undo");
        RedoButton = CreateIconButton(RedoIcon, "Redo");
        ThemeButton = CreateIconButton(ThemeIcon, "Switch theme");
        WrapButton = CreateWrapButton();
        ZoomOutButton = CreateTextButton("A-", "Smaller UI");
        ZoomInButton = CreateTextButton("A+", "Larger UI");
        PerfButton = CreateTextButton("FPS", "Toggle performance overlay");
        HelpButton = CreateIconButton(HelpIcon, "Keyboard shortcuts");
        SamplePickerButton = CreateSamplePickerButton(out samplePickerChrome, out samplePickerLabel, out samplePickerChevron);
        wrapBadgeText = FindWrapBadge(WrapButton);
        SetSamplePickerLabel(null);
        SetSamplePickerExpanded(false);
        SetTheme(true);
        SetWrapMode(WrapMode.NONE);
    }

    public ComboBox FileCombo { get; } = new();
    public Button SamplePickerButton { get; }
    public Button UndoButton { get; }
    public Button RedoButton { get; }
    public Button ThemeButton { get; }
    public Button WrapButton { get; }
    public Button ZoomOutButton { get; }
    public Button ZoomInButton { get; }
    public Button PerfButton { get; }
    public Button HelpButton { get; }
    public Border SamplePickerChrome => samplePickerChrome;
    public TextBlock SamplePickerLabel => samplePickerLabel;
    public AvaPath SamplePickerChevron => samplePickerChevron;

    public IEnumerable<Button> ActionButtons
    {
        get
        {
            yield return UndoButton;
            yield return RedoButton;
            yield return ThemeButton;
            yield return WrapButton;
            yield return ZoomOutButton;
            yield return ZoomInButton;
            yield return PerfButton;
            yield return HelpButton;
        }
    }

    public Control BuildView()
    {
        FileCombo.MaxDropDownHeight = 320;
        SamplePickerButton.MinWidth = 84;
        SamplePickerButton.Height = 32;
        SamplePickerButton.HorizontalAlignment = HorizontalAlignment.Stretch;
        SamplePickerButton.VerticalAlignment = VerticalAlignment.Center;

        StackPanel actions = new()
        {
            Orientation = Orientation.Horizontal,
            Spacing = 1,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
        };
        foreach (Button button in ActionButtons)
        {
            actions.Children.Add(button);
        }

        Grid bar = new()
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto"),
            ColumnSpacing = 4,
            MinHeight = 32,
        };
        bar.Children.Add(SamplePickerButton);
        Grid.SetColumn(actions, 1);
        bar.Children.Add(actions);
        return bar;
    }

    public void SetTheme(bool dark)
    {
        ThemeButton.Content = CreateIconChrome(ThemeIcon);
    }

    public void SetWrapMode(WrapMode mode)
    {
        wrapBadgeText.Text = mode switch
        {
            WrapMode.WORD_BREAK => "W",
            WrapMode.CHAR_BREAK => "C",
            _ => "N",
        };
    }

    public void SetSamplePickerLabel(string? label)
    {
        samplePickerLabel.Text = string.IsNullOrWhiteSpace(label) ? "Samples" : label;
    }

    public void SetSamplePickerExpanded(bool expanded)
    {
        samplePickerChevron.RenderTransform = new RotateTransform(expanded ? 180 : 0);
        samplePickerChevron.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
    }

    public void SetSamplePickerEnabled(bool enabled)
    {
        SamplePickerButton.IsEnabled = enabled;
        SamplePickerButton.Opacity = enabled ? 1.0 : 0.42;
    }

    private static Button CreateIconButton(string data, string tooltip)
    {
        Button button = CreateBaseButton();
        button.Content = CreateIconChrome(data);
        ToolTip.SetTip(button, tooltip);
        return button;
    }

    private static Button CreateTextButton(string text, string tooltip)
    {
        Button button = CreateBaseButton();
        button.Width = 30;
        button.Content = CreateTextChrome(text);
        ToolTip.SetTip(button, tooltip);
        return button;
    }

    private static Button CreateBaseButton() => new()
    {
        Width = 28,
        Height = 28,
        Padding = new Thickness(0),
        Background = Brushes.Transparent,
        BorderBrush = Brushes.Transparent,
        BorderThickness = new Thickness(0),
        HorizontalContentAlignment = HorizontalAlignment.Center,
        VerticalContentAlignment = VerticalAlignment.Center,
    };

    private static Button CreateSamplePickerButton(out Border chrome, out TextBlock label, out AvaPath chevron)
    {
        label = new TextBlock
        {
            Text = "Samples",
            FontSize = 11.25,
            FontWeight = FontWeight.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };

        chevron = CreateIconPath(ChevronDownIcon);
        chevron.Width = 12;
        chevron.Height = 12;
        chevron.Fill = null;
        chevron.StrokeThickness = 1.4;
        chevron.HorizontalAlignment = HorizontalAlignment.Right;
        chevron.VerticalAlignment = VerticalAlignment.Center;

        Grid content = new()
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto"),
            ColumnSpacing = 6,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Center,
        };
        content.Children.Add(label);
        Grid.SetColumn(chevron, 1);
        content.Children.Add(chevron);

        chrome = new Border
        {
            MinWidth = 84,
            Height = 24,
            Padding = new Thickness(8, 0, 6, 0),
            Background = Brushes.Transparent,
            CornerRadius = new CornerRadius(7),
            Child = content,
        };

        Button button = CreateBaseButton();
        button.Width = double.NaN;
        button.HorizontalContentAlignment = HorizontalAlignment.Stretch;
        button.Content = chrome;
        ToolTip.SetTip(button, "Open sample list");
        return button;
    }

    private static Button CreateWrapButton()
    {
        TextBlock badge = new()
        {
            Name = "WrapBadge",
            FontSize = 8,
            FontWeight = FontWeight.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };

        Border badgeChrome = new()
        {
            Width = 11,
            Height = 11,
            CornerRadius = new CornerRadius(999),
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(0, 0, 1, 1),
            Child = badge,
        };

        Grid chrome = new()
        {
            Width = 24,
            Height = 24,
            Children =
            {
                CreateIconPath(WrapIcon),
                badgeChrome,
            },
        };

        Border container = new()
        {
            Width = 24,
            Height = 24,
            Background = Brushes.Transparent,
            CornerRadius = new CornerRadius(7),
            Child = chrome,
        };

        Button button = CreateBaseButton();
        button.Content = container;
        ToolTip.SetTip(button, "Cycle wrap mode");
        return button;
    }

    private static TextBlock FindWrapBadge(Button button)
    {
        if (button.Content is Border container &&
            container.Child is Grid grid &&
            grid.Children.Count > 1 &&
            grid.Children[1] is Border badgeChrome &&
            badgeChrome.Child is TextBlock badge)
        {
            return badge;
        }

        return new TextBlock();
    }

    private static Border CreateIconChrome(string data) => new()
    {
        Width = 24,
        Height = 24,
        Background = Brushes.Transparent,
        CornerRadius = new CornerRadius(7),
        Child = CreateIconPath(data),
    };

    private static Border CreateTextChrome(string text) => new()
    {
        MinWidth = 24,
        Height = 24,
        Padding = new Thickness(0, 0, 0, 1),
        Background = Brushes.Transparent,
        CornerRadius = new CornerRadius(7),
        Child = new TextBlock
        {
            Text = text,
            FontSize = 9.25,
            FontWeight = FontWeight.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            TextAlignment = TextAlignment.Center,
        },
    };

    private static AvaPath CreateIconPath(string data) => new()
    {
        Data = Geometry.Parse(data),
        Stretch = Stretch.Uniform,
        Width = 16,
        Height = 16,
        Fill = Brushes.White,
        HorizontalAlignment = HorizontalAlignment.Center,
        VerticalAlignment = VerticalAlignment.Center,
    };
}
