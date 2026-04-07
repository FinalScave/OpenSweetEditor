using System;
using Avalonia;
using Avalonia.Animation;
using Avalonia.Animation.Easings;
using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Styling;
using Avalonia.Threading;

namespace SweetEditor.Avalonia.Demo.UI;

public sealed class LoadingIndicator : Border
{
    private readonly DispatcherTimer animationTimer;
    private readonly Ellipse[] dots;
    private int animationFrame;
    private bool isAnimating;

    public static readonly StyledProperty<bool> IsLoadingProperty =
        AvaloniaProperty.Register<LoadingIndicator, bool>(nameof(IsLoading));

    public bool IsLoading
    {
        get => GetValue(IsLoadingProperty);
        set => SetValue(IsLoadingProperty, value);
    }

    public static readonly StyledProperty<string> LoadingTextProperty =
        AvaloniaProperty.Register<LoadingIndicator, string>(nameof(LoadingText), "Loading...");

    public string LoadingText
    {
        get => GetValue(LoadingTextProperty);
        set => SetValue(LoadingTextProperty, value);
    }

    public LoadingIndicator()
    {
        dots = new Ellipse[3];
        animationTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(150),
        };
        animationTimer.Tick += OnAnimationTick;

        BuildLayout();
        UpdateVisibility();
    }

    protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change)
    {
        base.OnPropertyChanged(change);
        if (change.Property == IsLoadingProperty)
        {
            UpdateVisibility();
        }
        else if (change.Property == LoadingTextProperty)
        {
            UpdateLoadingText();
        }
    }

    private void BuildLayout()
    {
        Background = CreateBrush(0xE0182231);
        CornerRadius = new CornerRadius(12);
        Padding = new Thickness(24, 16);
        HorizontalAlignment = HorizontalAlignment.Center;
        VerticalAlignment = VerticalAlignment.Center;
        IsVisible = false;

        StackPanel content = new()
        {
            Orientation = Orientation.Horizontal,
            Spacing = 16,
        };

        StackPanel dotsContainer = new()
        {
            Orientation = Orientation.Horizontal,
            Spacing = 6,
            VerticalAlignment = VerticalAlignment.Center,
        };

        for (int i = 0; i < dots.Length; i++)
        {
            dots[i] = new Ellipse
            {
                Width = 8,
                Height = 8,
                Fill = CreateBrush(0xFF4C9DFF),
            };
            dotsContainer.Children.Add(dots[i]);
        }

        content.Children.Add(dotsContainer);

        TextBlock text = new()
        {
            Name = "LoadingText",
            Text = LoadingText,
            FontSize = 14,
            FontWeight = FontWeight.Medium,
            Foreground = CreateBrush(0xFFD7DEE9),
            VerticalAlignment = VerticalAlignment.Center,
        };
        content.Children.Add(text);

        Child = content;
    }

    private void UpdateVisibility()
    {
        IsVisible = IsLoading;
        if (IsLoading)
        {
            StartAnimation();
        }
        else
        {
            StopAnimation();
        }
    }

    private void UpdateLoadingText()
    {
        if (Child is StackPanel content && content.Children.Count > 1 &&
            content.Children[1] is TextBlock text)
        {
            text.Text = LoadingText;
        }
    }

    private void StartAnimation()
    {
        if (isAnimating)
            return;

        isAnimating = true;
        animationFrame = 0;
        animationTimer.Start();
    }

    private void StopAnimation()
    {
        isAnimating = false;
        animationTimer.Stop();
        ResetDots();
    }

    private void OnAnimationTick(object? sender, EventArgs e)
    {
        if (!isAnimating)
            return;

        animationFrame = (animationFrame + 1) % (dots.Length * 2);

        for (int i = 0; i < dots.Length; i++)
        {
            int phase = (animationFrame - i + dots.Length * 2) % (dots.Length * 2);
            double scale = phase switch
            {
                0 => 1.3,
                1 => 1.0,
                _ => 0.7,
            };

            dots[i].Width = 8 * scale;
            dots[i].Height = 8 * scale;
            dots[i].Opacity = phase == 0 ? 1.0 : 0.5;
        }
    }

    private void ResetDots()
    {
        foreach (Ellipse dot in dots)
        {
            dot.Width = 8;
            dot.Height = 8;
            dot.Opacity = 1.0;
        }
    }

    private static SolidColorBrush CreateBrush(uint argb) => new(Color.FromUInt32(argb));
}

public sealed class ProgressBar : Control
{
    private readonly Rectangle progressRect;
    private readonly DispatcherTimer animationTimer;
    private double progress;
    private bool isIndeterminate;
    private double indeterminateOffset;

    public static readonly StyledProperty<double> ValueProperty =
        AvaloniaProperty.Register<ProgressBar, double>(nameof(Value));

    public double Value
    {
        get => GetValue(ValueProperty);
        set => SetValue(ValueProperty, Math.Clamp(value, 0, 100));
    }

    public static readonly StyledProperty<bool> IsIndeterminateProperty =
        AvaloniaProperty.Register<ProgressBar, bool>(nameof(IsIndeterminate));

    public bool IsIndeterminate
    {
        get => GetValue(IsIndeterminateProperty);
        set => SetValue(IsIndeterminateProperty, value);
    }

    public static readonly StyledProperty<uint> ProgressColorProperty =
        AvaloniaProperty.Register<ProgressBar, uint>(nameof(ProgressColor), 0xFF4C9DFF);

    public uint ProgressColor
    {
        get => GetValue(ProgressColorProperty);
        set => SetValue(ProgressColorProperty, value);
    }

    public ProgressBar()
    {
        progressRect = new Rectangle();
        animationTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(16),
        };
        animationTimer.Tick += OnAnimationTick;
    }

    protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change)
    {
        base.OnPropertyChanged(change);
        if (change.Property == ValueProperty ||
            change.Property == IsIndeterminateProperty ||
            change.Property == ProgressColorProperty)
        {
            InvalidateVisual();
        }
    }

    public override void Render(DrawingContext context)
    {
        double width = Bounds.Width;
        double height = Bounds.Height;

        if (width <= 0 || height <= 0)
            return;

        context.FillRectangle(
            new SolidColorBrush(Color.FromUInt32(0xFF242A33)),
            new Rect(0, 0, width, height),
            (float)(height / 2));

        if (IsIndeterminate)
        {
            double indicatorWidth = width * 0.3;
            double x = indeterminateOffset % (width + indicatorWidth) - indicatorWidth;
            context.FillRectangle(
                new SolidColorBrush(Color.FromUInt32(ProgressColor)),
                new Rect(x, 0, indicatorWidth, height),
                (float)(height / 2));
        }
        else
        {
            double progressWidth = width * (Value / 100.0);
            if (progressWidth > 0)
            {
                context.FillRectangle(
                    new SolidColorBrush(Color.FromUInt32(ProgressColor)),
                    new Rect(0, 0, progressWidth, height),
                    (float)(height / 2));
            }
        }
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        if (IsIndeterminate)
            animationTimer.Start();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        animationTimer.Stop();
    }

    private void OnAnimationTick(object? sender, EventArgs e)
    {
        if (IsIndeterminate)
        {
            indeterminateOffset += 3;
            InvalidateVisual();
        }
        else
        {
            animationTimer.Stop();
        }
    }
}
