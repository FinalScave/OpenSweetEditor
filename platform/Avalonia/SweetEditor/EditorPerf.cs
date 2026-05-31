using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using Avalonia;
using Avalonia.Media;
using AvaloniaRect = Avalonia.Rect;

namespace SweetEditor {
	/// <summary>
	/// Per-frame text measurement performance statistics.
	/// </summary>
	public sealed class MeasurePerfStats {
		private static readonly double TickToMs = 1000.0 / Stopwatch.Frequency;

		private int textCount;
		private long textTicksTotal;
		private long textTicksMax;
		private int textMaxLen;
		private int textMaxStyle;

		private int inlayCount;
		private long inlayTicksTotal;
		private long inlayTicksMax;
		private int inlayMaxLen;

		private int iconCount;
		private long iconTicksTotal;
		private long iconTicksMax;

		public void Reset() {
			textCount = 0;
			textTicksTotal = 0;
			textTicksMax = 0;
			textMaxLen = 0;
			textMaxStyle = 0;
			inlayCount = 0;
			inlayTicksTotal = 0;
			inlayTicksMax = 0;
			inlayMaxLen = 0;
			iconCount = 0;
			iconTicksTotal = 0;
			iconTicksMax = 0;
		}

		public void RecordText(long elapsedTicks, int textLen, int fontStyle) {
			textCount++;
			textTicksTotal += elapsedTicks;
			if (elapsedTicks > textTicksMax) {
				textTicksMax = elapsedTicks;
				textMaxLen = textLen;
				textMaxStyle = fontStyle;
			}
		}

		public void RecordInlay(long elapsedTicks, int textLen) {
			inlayCount++;
			inlayTicksTotal += elapsedTicks;
			if (elapsedTicks > inlayTicksMax) {
				inlayTicksMax = elapsedTicks;
				inlayMaxLen = textLen;
			}
		}

		public void RecordIcon(long elapsedTicks) {
			iconCount++;
			iconTicksTotal += elapsedTicks;
			if (elapsedTicks > iconTicksMax) {
				iconTicksMax = elapsedTicks;
			}
		}

		public bool ShouldLog() {
			return textTicksTotal * TickToMs >= 2.0 || inlayTicksTotal * TickToMs >= 1.0;
		}

		public string BuildSummary() {
			return string.Format(
				CultureInfo.InvariantCulture,
				"measure{{text={0}/{1:0.00}ms max={2:0.00}ms(len={3},style={4}) inlay={5}/{6:0.00}ms icon={7}/{8:0.00}ms}}",
				textCount, textTicksTotal * TickToMs, textTicksMax * TickToMs, textMaxLen, textMaxStyle,
				inlayCount, inlayTicksTotal * TickToMs,
				iconCount, iconTicksTotal * TickToMs);
		}
	}

	/// <summary>
	/// Step-by-step performance timer for recording phase durations.
	/// </summary>
	public sealed class PerfStepRecorder {
		private static readonly double TickToMs = 1000.0 / Stopwatch.Frequency;
		private const int MaxSteps = 32;

		public const string STEP_BUILD = "build";
		public const string STEP_CLEAR = "clear";
		public const string STEP_CURRENT = "current";
		public const string STEP_SELECTION = "selection";
		public const string STEP_LINES = "lines";
		public const string STEP_CURSOR = "cursor";
		public const string STEP_GUTTER = "gutter";
		public const string STEP_SCROLLBARS = "scrollbars";

		private readonly string[] stepNames = new string[MaxSteps];
		private readonly long[] stepTicks = new long[MaxSteps];
		private readonly long startTicks;
		private long lastTicks;
		private long endTicks;
		private int stepCount;

		private PerfStepRecorder() {
			startTicks = Stopwatch.GetTimestamp();
			lastTicks = startTicks;
		}

		public static PerfStepRecorder Start() => new();

		public void Mark(string stepName) {
			long now = Stopwatch.GetTimestamp();
			if (stepCount < MaxSteps) {
				stepNames[stepCount] = stepName;
				stepTicks[stepCount] = now - lastTicks;
				stepCount++;
			}
			lastTicks = now;
		}

		public void Finish() {
			if (endTicks == 0) {
				endTicks = Stopwatch.GetTimestamp();
			}
		}

		public float GetTotalMs() {
			long end = endTicks == 0 ? Stopwatch.GetTimestamp() : endTicks;
			return (float)((end - startTicks) * TickToMs);
		}

		public int GetStepCount() => stepCount;

		public string GetStepName(int index) {
			return index >= 0 && index < stepCount ? stepNames[index] : string.Empty;
		}

		public float GetStepMsByIndex(int index) {
			return index >= 0 && index < stepCount
				? (float)(stepTicks[index] * TickToMs)
				: 0f;
		}
	}

	/// <summary>
	/// Debug performance panel rendered at the top-left of the editor area.
	/// </summary>
	public sealed class PerfOverlay {
		public const float WARN_BUILD_MS = 8.0f;
		public const float WARN_PAINT_MS = 8.0f;
		public const float WARN_INPUT_MS = 3.0f;
		public const float WARN_PAINT_STEP_MS = 2.0f;

		private const double TextSize = 11.5;
		private const double LineSpacing = 3.0;
		private const double PaddingH = 9.0;
		private const double PaddingV = 7.0;
		private const double Margin = 8.0;
		private const int SnapshotIntervalMs = 125;

		private readonly Typeface monoTypeface = new("monospace");
		private readonly ISolidColorBrush panelBrush = new SolidColorBrush(Color.FromArgb(180, 0, 0, 0));
		private readonly ISolidColorBrush okBrush = new SolidColorBrush(Color.FromArgb(255, 120, 255, 145));
		private readonly ISolidColorBrush warnBrush = new SolidColorBrush(Color.FromArgb(255, 255, 93, 93));
		private readonly Dictionary<OverlayTextKey, FormattedText> formattedLineCache = new();
		private readonly List<FormattedText> snapshotLines = new();
		private double monoAdvance = -1;
		private bool enabled;
		private float currentFps;
		private float lastBuildMs;
		private float lastDrawMs;
		private float lastTotalMs;
		private PerfStepRecorder? lastDrawPerf;
		private MeasurePerfStats? lastMeasureStats;
		private string lastInputTag = string.Empty;
		private float lastInputMs;
		private double snapshotMaxContentWidth = -1;
		private double snapshotPanelWidth;
		private double snapshotPanelHeight;
		private long nextSnapshotTick;

		private readonly record struct OverlayTextKey(string Text, bool Slow);

		public bool IsEnabled() => enabled;

		public void SetEnabled(bool enabled) {
			this.enabled = enabled;
			nextSnapshotTick = 0;
			snapshotLines.Clear();
		}

		public void RecordFrame(float buildMs, float drawMs, float totalMs, PerfStepRecorder? drawPerf, MeasurePerfStats? measureStats) {
			lastBuildMs = buildMs;
			lastDrawMs = drawMs;
			lastTotalMs = totalMs;
			lastDrawPerf = drawPerf;
			lastMeasureStats = measureStats;
			currentFps = totalMs > 0 ? 1000f / totalMs : 0f;
		}

		public void RecordInput(string tag, float inputMs) {
			lastInputTag = tag ?? string.Empty;
			lastInputMs = inputMs;
		}

		public void Render(DrawingContext context, Size viewportSize) {
			if (!enabled || viewportSize.Width <= 0 || viewportSize.Height <= 0) {
				return;
			}

			double maxContentWidth = Math.Max(120, viewportSize.Width - Margin * 2 - PaddingH * 2);
			RefreshSnapshot(maxContentWidth);
			if (snapshotLines.Count == 0) {
				return;
			}

			double left = Margin;
			double top = Margin;
			context.FillRectangle(panelBrush, new AvaloniaRect(left, top, snapshotPanelWidth, snapshotPanelHeight));

			double x = left + PaddingH;
			double y = top + PaddingV;
			double lineHeight = TextSize + LineSpacing;
			for (int i = 0; i < snapshotLines.Count; i++) {
				context.DrawText(snapshotLines[i], new Point(x, y));
				y += lineHeight;
			}
		}

		private void RefreshSnapshot(double maxContentWidth) {
			long now = Stopwatch.GetTimestamp();
			bool widthChanged = Math.Abs(maxContentWidth - snapshotMaxContentWidth) > 1.0;
			if (!widthChanged && now < nextSnapshotTick && snapshotLines.Count > 0) {
				return;
			}

			List<string> lines = BuildOverlayLines(maxContentWidth);
			snapshotLines.Clear();
			snapshotMaxContentWidth = maxContentWidth;
			nextSnapshotTick = now + Stopwatch.Frequency * SnapshotIntervalMs / 1000;
			if (lines.Count == 0) {
				snapshotPanelWidth = 0;
				snapshotPanelHeight = 0;
				return;
			}

			double contentWidth = 0;
			for (int i = 0; i < lines.Count; i++) {
				string line = lines[i];
				bool slowLine = line.Contains("SLOW", StringComparison.Ordinal) || line.Contains("!", StringComparison.Ordinal);
				FormattedText formatted = GetFormattedLine(line, slowLine);
				snapshotLines.Add(formatted);
				contentWidth = Math.Max(contentWidth, formatted.WidthIncludingTrailingWhitespace);
			}

			double lineHeight = TextSize + LineSpacing;
			snapshotPanelWidth = Math.Min(contentWidth + PaddingH * 2, Math.Max(120, maxContentWidth + PaddingH * 2));
			snapshotPanelHeight = lines.Count * lineHeight + PaddingV * 2;
		}

		private List<string> BuildOverlayLines(double maxWidth) {
			var lines = new List<string> {
				string.Format(CultureInfo.InvariantCulture, "FPS: {0:0}", currentFps),
			};

			string frameSuffix = lastTotalMs > 16.6f ? " SLOW" : string.Empty;
			lines.Add(string.Format(
				CultureInfo.InvariantCulture,
				"Frame: {0:0.00}ms (build={1:0.00} draw={2:0.00}){3}",
				lastTotalMs, lastBuildMs, lastDrawMs, frameSuffix));

			if (lastDrawPerf != null) {
				BuildStepLines(lines, maxWidth, lastDrawPerf);
			}

			if (lastMeasureStats != null && lastMeasureStats.ShouldLog()) {
				WrapText(lines, lastMeasureStats.BuildSummary(), maxWidth);
			}

			if (!string.IsNullOrEmpty(lastInputTag)) {
				string suffix = lastInputMs > WARN_INPUT_MS ? " SLOW" : string.Empty;
				lines.Add(string.Format(CultureInfo.InvariantCulture, "Input[{0}]: {1:0.00}ms{2}", lastInputTag, lastInputMs, suffix));
			}

			return lines;
		}

		private void BuildStepLines(List<string> lines, double maxWidth, PerfStepRecorder perf) {
			int count = perf.GetStepCount();
			if (count == 0) {
				return;
			}

			string prefix = "Step: ";
			string contPrefix = "  ";
			string current = prefix;

			for (int i = 0; i < count; i++) {
				float ms = perf.GetStepMsByIndex(i);
				string entry = string.Format(CultureInfo.InvariantCulture, "{0}={1:0.0}", perf.GetStepName(i), ms);
				if (ms >= WARN_PAINT_STEP_MS) {
					entry += "!";
				}

				string candidate = current == prefix || current == contPrefix
					? current + entry
					: current + " " + entry;

				if (MeasureTextWidth(candidate) > maxWidth && current != prefix && current != contPrefix) {
					lines.Add(current);
					current = contPrefix + entry;
				} else {
					current = candidate;
				}
			}

			if (!string.IsNullOrEmpty(current)) {
				lines.Add(current);
			}
		}

		private void WrapText(List<string> lines, string text, double maxWidth) {
			if (string.IsNullOrWhiteSpace(text)) {
				return;
			}

			if (MeasureTextWidth(text) <= maxWidth) {
				lines.Add(text);
				return;
			}

			string[] words = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
			string current = string.Empty;
			foreach (string word in words) {
				string candidate = string.IsNullOrEmpty(current) ? word : current + " " + word;
				if (MeasureTextWidth(candidate) > maxWidth && !string.IsNullOrEmpty(current)) {
					lines.Add(current);
					current = "  " + word;
				} else {
					current = candidate;
				}
			}
			if (!string.IsNullOrEmpty(current)) {
				lines.Add(current);
			}
		}

		private double MeasureTextWidth(string text) {
			if (string.IsNullOrEmpty(text)) {
				return 0;
			}
			try {
				return text.Length * GetMonospaceAdvance();
			} catch {
				return text.Length * TextSize * 0.6;
			}
		}

		private FormattedText GetFormattedLine(string text, bool slow) {
			var key = new OverlayTextKey(text, slow);
			if (formattedLineCache.TryGetValue(key, out FormattedText? formatted)) {
				return formatted;
			}

			if (formattedLineCache.Count >= 256) {
				formattedLineCache.Clear();
			}

			formatted = new FormattedText(
				text,
				CultureInfo.InvariantCulture,
				FlowDirection.LeftToRight,
				monoTypeface,
				TextSize,
				slow ? warnBrush : okBrush);
			formattedLineCache[key] = formatted;
			return formatted;
		}

		private double GetMonospaceAdvance() {
			if (monoAdvance > 0) {
				return monoAdvance;
			}

			var formatted = new FormattedText(
				"M",
				CultureInfo.InvariantCulture,
				FlowDirection.LeftToRight,
				monoTypeface,
				TextSize,
				Brushes.Transparent);
			monoAdvance = Math.Max(formatted.Width, formatted.WidthIncludingTrailingWhitespace);
			return monoAdvance;
		}
	}
}
