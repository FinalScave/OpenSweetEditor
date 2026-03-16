using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace SweetEditor.Perf {
	internal static class EditorPerf {
		public const bool Enabled = true;
		public const double WarnBuildMs = 8.0;
		public const double WarnPaintMs = 8.0;
		public const double WarnInputMs = 3.0;
		public const double WarnPaintStepMs = 2.0;
		public const double WarnMeasureSingleMs = 1.0;

		public static long NowTicks() => Stopwatch.GetTimestamp();

		public static double TicksToMs(long ticks) => ticks * 1000.0 / Stopwatch.Frequency;

		public static void LogSlow(string tag, long elapsedTicks, double thresholdMs) {
			if (!Enabled) return;
			double elapsedMs = TicksToMs(elapsedTicks);
			if (elapsedMs >= thresholdMs) {
				Debug.WriteLine($"[PERF][SLOW] {tag}: {elapsedMs:F2} ms");
			}
		}
	}

	internal readonly struct PerfScope : IDisposable {
		private readonly string tag;
		private readonly double thresholdMs;
		private readonly long startTicks;
		private readonly Action<string, double>? onStop;

		private PerfScope(string tag, double thresholdMs, Action<string, double>? onStop) {
			this.tag = tag;
			this.thresholdMs = thresholdMs;
			this.onStop = onStop;
			this.startTicks = EditorPerf.Enabled ? EditorPerf.NowTicks() : 0;
		}

		public static PerfScope Start(string tag, double thresholdMs, Action<string, double>? onStop = null) {
			return new PerfScope(tag, thresholdMs, onStop);
		}

		public static long StartTicks() {
			return EditorPerf.Enabled ? EditorPerf.NowTicks() : 0;
		}

		public static long ElapsedTicks(long startTicks) {
			return startTicks == 0 ? 0 : (EditorPerf.NowTicks() - startTicks);
		}

		public void Dispose() {
			if (startTicks == 0) return;
			long elapsedTicks = EditorPerf.NowTicks() - startTicks;
			EditorPerf.LogSlow(tag, elapsedTicks, thresholdMs);
			onStop?.Invoke(tag, EditorPerf.TicksToMs(elapsedTicks));
		}
	}

	internal sealed class PerfStepRecorder {
		private const int MaxSteps = 32;

		public const string StepPrep = "prep";
		public const string StepBuild = "build";
		public const string StepMetrics = "metrics";
		public const string StepAnchor = "anchor";
		public const string StepInvalidate = "invalidate";
		public const string StepClear = "clear";
		public const string StepCurrent = "current";
		public const string StepSelection = "selection";
		public const string StepLines = "lines";
		public const string StepGuides = "guides";
		public const string StepComposition = "comp";
		public const string StepDiagnostics = "diag";
		public const string StepLinkedEditing = "linked";
		public const string StepBracket = "bracket";
		public const string StepCursor = "cursor";
		public const string StepGutter = "gutter";
		public const string StepLineNumber = "lineNo";
		public const string StepScrollbar = "scrollbar";
		public const string StepPopup = "popup";

		private readonly string[] stepNames = new string[MaxSteps];
		private readonly long[] stepTicks = new long[MaxSteps];
		private int stepCount = 0;
		private readonly long startTicks;
		private long lastTicks;
		private long endTicks = 0;

		private PerfStepRecorder() {
			startTicks = EditorPerf.Enabled ? EditorPerf.NowTicks() : 0;
			lastTicks = startTicks;
		}

		public static PerfStepRecorder Start() {
			return new PerfStepRecorder();
		}

		public long TotalTicks => startTicks == 0 ? 0 : ((endTicks != 0 ? endTicks : EditorPerf.NowTicks()) - startTicks);

		public double TotalMs => EditorPerf.TicksToMs(TotalTicks);

		public void Mark(string stepName) {
			if (startTicks == 0) return;
			long now = EditorPerf.NowTicks();
			if (stepCount < MaxSteps) {
				stepNames[stepCount] = stepName;
				stepTicks[stepCount] = now - lastTicks;
				stepCount++;
			}
			lastTicks = now;
		}

		public void Finish() {
			if (startTicks == 0 || endTicks != 0) return;
			endTicks = EditorPerf.NowTicks();
		}

		public long GetStepTicks(string stepName) {
			for (int i = 0; i < stepCount; i++) {
				if (stepNames[i] == stepName) return stepTicks[i];
			}
			return 0;
		}

		public double GetStepMs(string stepName) => EditorPerf.TicksToMs(GetStepTicks(stepName));

		public int GetStepCount() => stepCount;

		public string GetStepName(int index) => index >= 0 && index < stepCount ? stepNames[index] : string.Empty;

		public double GetStepMsByIndex(int index) => index >= 0 && index < stepCount ? EditorPerf.TicksToMs(stepTicks[index]) : 0;

		public bool AnyStepOver(double thresholdMs) {
			for (int i = 0; i < stepCount; i++) {
				if (EditorPerf.TicksToMs(stepTicks[i]) >= thresholdMs) return true;
			}
			return false;
		}
	}

	internal sealed class MeasurePerfStats {
		private long textCount = 0;
		private long textTicksTotal = 0;
		private long textTicksMax = 0;
		private int textMaxLen = 0;
		private int textMaxStyle = 0;
		private long inlayCount = 0;
		private long inlayTicksTotal = 0;
		private long inlayTicksMax = 0;
		private int inlayMaxLen = 0;
		private long iconCount = 0;
		private long iconTicksTotal = 0;
		private long iconTicksMax = 0;

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
			if (!EditorPerf.Enabled || elapsedTicks <= 0) return;
			textCount++;
			textTicksTotal += elapsedTicks;
			if (elapsedTicks > textTicksMax) {
				textTicksMax = elapsedTicks;
				textMaxLen = textLen;
				textMaxStyle = fontStyle;
			}
			EditorPerf.LogSlow($"MeasureText(len={textLen}, style={fontStyle})", elapsedTicks, EditorPerf.WarnMeasureSingleMs);
		}

		public void RecordInlay(long elapsedTicks, int textLen) {
			if (!EditorPerf.Enabled || elapsedTicks <= 0) return;
			inlayCount++;
			inlayTicksTotal += elapsedTicks;
			if (elapsedTicks > inlayTicksMax) {
				inlayTicksMax = elapsedTicks;
				inlayMaxLen = textLen;
			}
			EditorPerf.LogSlow($"MeasureInlay(len={textLen})", elapsedTicks, EditorPerf.WarnMeasureSingleMs);
		}

		public void RecordIcon(long elapsedTicks, int iconId) {
			if (!EditorPerf.Enabled || elapsedTicks <= 0) return;
			iconCount++;
			iconTicksTotal += elapsedTicks;
			if (elapsedTicks > iconTicksMax) {
				iconTicksMax = elapsedTicks;
			}
			EditorPerf.LogSlow($"MeasureIcon(id={iconId})", elapsedTicks, EditorPerf.WarnMeasureSingleMs);
		}

		public bool ShouldLogBuild() {
			return EditorPerf.TicksToMs(textTicksTotal) >= 2.0 || EditorPerf.TicksToMs(inlayTicksTotal) >= 1.0;
		}

		public string BuildSummary() {
			double measureTextMs = EditorPerf.TicksToMs(textTicksTotal);
			double measureInlayMs = EditorPerf.TicksToMs(inlayTicksTotal);
			double measureIconMs = EditorPerf.TicksToMs(iconTicksTotal);
			return
				$"measureText={textCount}/{measureTextMs:F2}ms max={EditorPerf.TicksToMs(textTicksMax):F2}ms(len={textMaxLen},style={textMaxStyle}) " +
				$"measureInlay={inlayCount}/{measureInlayMs:F2}ms max={EditorPerf.TicksToMs(inlayTicksMax):F2}ms(len={inlayMaxLen}) " +
				$"measureIcon={iconCount}/{measureIconMs:F2}ms max={EditorPerf.TicksToMs(iconTicksMax):F2}ms";
		}
	}

	internal sealed class PerfOverlay : IDisposable {
		private const int Margin = 8;
		private const int PaddingHorizontal = 10;
		private const int PaddingVertical = 8;
		private const int LineSpacing = 2;
		private static readonly TextFormatFlags TextFlags = TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine;
		private static readonly Color OkTextColor = Color.Lime;
		private static readonly Color WarnTextColor = Color.FromArgb(255, 96, 96);

		private readonly Font textFont = new Font("Consolas", 8.5f, FontStyle.Regular, GraphicsUnit.Point);
		private readonly SolidBrush backgroundBrush = new SolidBrush(Color.FromArgb(180, 0, 0, 0));
		private bool enabled = false;
		private double currentFps = 0;
		private double lastBuildMs = 0;
		private double lastDrawMs = 0;
		private double lastTotalMs = 0;
		private PerfStepRecorder? lastBuildPerf;
		private PerfStepRecorder? lastDrawPerf;
		private string lastMeasureSummary = string.Empty;
		private string lastInputTag = string.Empty;
		private double lastInputMs = 0;

		public bool IsEnabled => enabled;

		public void SetEnabled(bool enabled) {
			this.enabled = enabled;
		}

		public void RecordBuild(PerfStepRecorder buildPerf, string measureSummary) {
			lastBuildPerf = buildPerf;
			lastBuildMs = buildPerf.TotalMs;
			lastMeasureSummary = measureSummary ?? string.Empty;
			UpdateFrameStats();
		}

		public void RecordDraw(PerfStepRecorder drawPerf) {
			lastDrawPerf = drawPerf;
			lastDrawMs = drawPerf.TotalMs;
			UpdateFrameStats();
		}

		public void RecordInput(string tag, double inputMs) {
			lastInputTag = tag ?? string.Empty;
			lastInputMs = inputMs;
		}

		public void Draw(Graphics g, int viewWidth) {
			if (!enabled || viewWidth <= Margin * 2) return;
			int maxWidth = Math.Max(0, viewWidth - Margin * 2 - PaddingHorizontal * 2);
			if (maxWidth <= 0) return;

			List<string> lines = BuildOverlayLines(g, maxWidth);
			if (lines.Count == 0) return;

			int lineHeight = textFont.Height + LineSpacing;
			int contentWidth = 0;
			for (int i = 0; i < lines.Count; i++) {
				contentWidth = Math.Max(contentWidth, MeasureTextWidth(g, lines[i]));
			}

			int panelWidth = Math.Min(contentWidth + PaddingHorizontal * 2, viewWidth - Margin * 2);
			if (panelWidth <= 0) return;
			int panelHeight = lines.Count * lineHeight + PaddingVertical * 2;
			var panelBounds = new Rectangle(Margin, Margin, panelWidth, panelHeight);
			g.FillRectangle(backgroundBrush, panelBounds);

			int x = panelBounds.Left + PaddingHorizontal;
			int y = panelBounds.Top + PaddingVertical;
			for (int i = 0; i < lines.Count; i++) {
				string line = lines[i];
				TextRenderer.DrawText(
					g,
					line,
					textFont,
					new Point(x, y),
					IsWarnLine(line) ? WarnTextColor : OkTextColor,
					TextFlags);
				y += lineHeight;
			}
		}

		public void Dispose() {
			textFont.Dispose();
			backgroundBrush.Dispose();
		}

		private void UpdateFrameStats() {
			lastTotalMs = lastBuildMs + lastDrawMs;
			currentFps = lastTotalMs > 0 ? 1000.0 / lastTotalMs : 0;
		}

		private List<string> BuildOverlayLines(Graphics g, int maxWidth) {
			var lines = new List<string>();
			lines.Add($"FPS: {currentFps:F0}");

			string frameSuffix = lastTotalMs >= 16.6 || lastBuildMs >= EditorPerf.WarnBuildMs || lastDrawMs >= EditorPerf.WarnPaintMs ? " SLOW" : string.Empty;
			lines.Add($"Frame: {lastTotalMs:F2}ms (build={lastBuildMs:F2} draw={lastDrawMs:F2}){frameSuffix}");

			AppendStepLines(lines, g, maxWidth, "Build: ", lastBuildPerf);
			AppendStepLines(lines, g, maxWidth, "Draw: ", lastDrawPerf);

			if (!string.IsNullOrWhiteSpace(lastMeasureSummary)) {
				AppendWrappedText(lines, g, maxWidth, lastMeasureSummary);
			}

			if (!string.IsNullOrEmpty(lastInputTag)) {
				string inputSuffix = lastInputMs >= EditorPerf.WarnInputMs ? " SLOW" : string.Empty;
				lines.Add($"Input[{lastInputTag}]: {lastInputMs:F2}ms{inputSuffix}");
			}

			return lines;
		}

		private void AppendStepLines(List<string> lines, Graphics g, int maxWidth, string prefix, PerfStepRecorder? perf) {
			if (perf == null) return;
			int stepCount = perf.GetStepCount();
			if (stepCount == 0) return;

			const string continuationPrefix = "  ";
			var builder = new StringBuilder(prefix);
			for (int i = 0; i < stepCount; i++) {
				double stepMs = perf.GetStepMsByIndex(i);
				string entry = $"{perf.GetStepName(i)}={stepMs:F1}";
				if (stepMs >= EditorPerf.WarnPaintStepMs) {
					entry += "!";
				}

				string candidate = builder.Length <= prefix.Length
					? builder.ToString() + entry
					: builder.ToString() + " " + entry;
				if (MeasureTextWidth(g, candidate) > maxWidth && builder.Length > prefix.Length) {
					lines.Add(builder.ToString());
					builder.Clear();
					builder.Append(continuationPrefix);
					builder.Append(entry);
				} else {
					if (builder.Length > prefix.Length && builder.Length > continuationPrefix.Length) {
						builder.Append(' ');
					}
					builder.Append(entry);
				}
			}

			if (builder.Length > 0) {
				lines.Add(builder.ToString());
			}
		}

		private void AppendWrappedText(List<string> lines, Graphics g, int maxWidth, string text) {
			if (MeasureTextWidth(g, text) <= maxWidth) {
				lines.Add(text);
				return;
			}

			const string continuationPrefix = "  ";
			string[] words = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
			var builder = new StringBuilder();
			for (int i = 0; i < words.Length; i++) {
				string word = words[i];
				string candidate = builder.Length == 0 ? word : builder.ToString() + " " + word;
				if (MeasureTextWidth(g, candidate) > maxWidth && builder.Length > 0) {
					lines.Add(builder.ToString());
					builder.Clear();
					builder.Append(continuationPrefix);
					builder.Append(word);
				} else {
					if (builder.Length > 0) {
						builder.Append(' ');
					}
					builder.Append(word);
				}
			}

			if (builder.Length > 0) {
				lines.Add(builder.ToString());
			}
		}

		private int MeasureTextWidth(Graphics g, string text) {
			return TextRenderer.MeasureText(g, text, textFont, new Size(int.MaxValue, int.MaxValue), TextFlags).Width;
		}

		private static bool IsWarnLine(string line) {
			return line.Contains("SLOW", StringComparison.Ordinal) || line.Contains('!');
		}
	}
}
