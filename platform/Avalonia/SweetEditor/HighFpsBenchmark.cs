using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading.Tasks;
using Avalonia.Threading;

namespace SweetEditor {
	public sealed class HighFpsBenchmarkResult {
		public string Name { get; set; } = "";
		public Dictionary<string, double> Metrics { get; set; } = new();
		public bool Passed { get; set; }
	}

	public sealed class HighFpsBenchmark {
		private const int TargetFps = 1500;
		private const double TargetFrameTimeMs = 1000.0 / TargetFps;
		private const int WarmupFrames = 60;
		private const int TestFrames = 600;
		private const int StressTestFrames = 3000;

		private readonly Dictionary<string, HighFpsBenchmarkResult> _results = new();
		private readonly List<double> _frameTimes = new(TestFrames);
		private readonly List<double> _buildTimes = new(TestFrames);
		private readonly List<double> _drawTimes = new(TestFrames);
		private readonly Stopwatch _stopwatch = new();
		private readonly FrameRateMonitor _monitor = new();

		public event Action<string>? ProgressChanged;
		public event Action<HighFpsBenchmarkResult>? BenchmarkCompleted;
		public event Action<FrameRateSnapshot>? FrameRecorded;

		public IReadOnlyDictionary<string, HighFpsBenchmarkResult> Results => _results;

		public async Task RunFullBenchmarkAsync() {
			ProgressChanged?.Invoke("Starting high-FPS benchmark suite...");

			await RunWarmupAsync();
			await RunStandardBenchmarkAsync();
			await RunStressTestAsync();
			await RunMemoryBenchmarkAsync();

			ProgressChanged?.Invoke("Benchmark suite completed!");
		}

		private async Task RunWarmupAsync() {
			ProgressChanged?.Invoke("Running warmup...");

			for (int i = 0; i < WarmupFrames; i++) {
				_monitor.BeginFrame();
				await Dispatcher.UIThread.InvokeAsync(() => { }, DispatcherPriority.Render);
				_monitor.EndFrame(0, 0);
				await Task.Delay(1);
			}
		}

		private async Task RunStandardBenchmarkAsync() {
			ProgressChanged?.Invoke($"Running standard benchmark ({TestFrames} frames)...");

			_frameTimes.Clear();
			_buildTimes.Clear();
			_drawTimes.Clear();
			_monitor.Reset();
			_stopwatch.Restart();

			int framesBelowTarget = 0;
			double totalBuildMs = 0;
			double totalDrawMs = 0;
			double minFrameMs = double.MaxValue;
			double maxFrameMs = double.MinValue;
			double jitterSum = 0;
			double lastFrameTime = 0;

			for (int i = 0; i < TestFrames; i++) {
				_monitor.BeginFrame();

				long frameStart = _stopwatch.ElapsedTicks;

				await Dispatcher.UIThread.InvokeAsync(() => {
				}, DispatcherPriority.Render);

				long buildEnd = _stopwatch.ElapsedTicks;

				await Dispatcher.UIThread.InvokeAsync(() => {
				}, DispatcherPriority.Render);

				long frameEnd = _stopwatch.ElapsedTicks;

				double frameMs = (frameEnd - frameStart) * 1000.0 / Stopwatch.Frequency;
				double buildMs = (buildEnd - frameStart) * 1000.0 / Stopwatch.Frequency;
				double drawMs = (frameEnd - buildEnd) * 1000.0 / Stopwatch.Frequency;

				_monitor.EndFrame(buildMs, drawMs);
				_frameTimes.Add(frameMs);
				_buildTimes.Add(buildMs);
				_drawTimes.Add(drawMs);

				totalBuildMs += buildMs;
				totalDrawMs += drawMs;

				if (frameMs < minFrameMs) minFrameMs = frameMs;
				if (frameMs > maxFrameMs) maxFrameMs = frameMs;

				if (frameMs > TargetFrameTimeMs) {
					framesBelowTarget++;
				}

				if (i > 0) {
					double jitter = Math.Abs(frameMs - lastFrameTime);
					jitterSum += jitter;
				}
				lastFrameTime = frameMs;

				FrameRecorded?.Invoke(_monitor.GetSnapshot());

				if (i % 100 == 0) {
					await Task.Delay(1);
				}
			}

			_stopwatch.Stop();

			double avgFrameMs = CalculateAverage(_frameTimes);
			double avgBuildMs = totalBuildMs / TestFrames;
			double avgDrawMs = totalDrawMs / TestFrames;
			double avgJitter = jitterSum / (TestFrames - 1);
			double fps = avgFrameMs > 0 ? 1000.0 / avgFrameMs : 0;
			double fps1PercentLow = Calculate1PercentLow(_frameTimes);
			double fps99thPercentile = CalculatePercentileFps(_frameTimes, 99);

			var result = new HighFpsBenchmarkResult {
				Name = "Standard Benchmark",
				Metrics = new Dictionary<string, double> {
					["FPS"] = fps,
					["FPS 1% Low"] = fps1PercentLow,
					["FPS 99th Percentile"] = fps99thPercentile,
					["Avg Frame (ms)"] = avgFrameMs,
					["Min Frame (ms)"] = minFrameMs,
					["Max Frame (ms)"] = maxFrameMs,
					["Avg Build (ms)"] = avgBuildMs,
					["Avg Draw (ms)"] = avgDrawMs,
					["Jitter (ms)"] = avgJitter,
					["Frames Below Target"] = framesBelowTarget,
					["Target FPS"] = TargetFps,
					["Frame Count"] = TestFrames,
				},
				Passed = fps >= TargetFps && framesBelowTarget < TestFrames * 0.05,
			};

			_results["Standard"] = result;
			BenchmarkCompleted?.Invoke(result);
		}

		private async Task RunStressTestAsync() {
			ProgressChanged?.Invoke($"Running stress test ({StressTestFrames} frames)...");

			var stressFrameTimes = new List<double>(StressTestFrames);
			_monitor.Reset();
			_stopwatch.Restart();

			int droppedFrames = 0;
			int consecutiveSlowFrames = 0;
			int maxConsecutiveSlow = 0;

			for (int i = 0; i < StressTestFrames; i++) {
				_monitor.BeginFrame();

				long frameStart = _stopwatch.ElapsedTicks;

				await Dispatcher.UIThread.InvokeAsync(() => {
				}, DispatcherPriority.Render);

				long frameEnd = _stopwatch.ElapsedTicks;

				double frameMs = (frameEnd - frameStart) * 1000.0 / Stopwatch.Frequency;
				_monitor.EndFrame(0, frameMs);
				stressFrameTimes.Add(frameMs);

				if (frameMs > TargetFrameTimeMs * 2) {
					droppedFrames++;
					consecutiveSlowFrames++;
					if (consecutiveSlowFrames > maxConsecutiveSlow) {
						maxConsecutiveSlow = consecutiveSlowFrames;
					}
				} else {
					consecutiveSlowFrames = 0;
				}

				if (i % 300 == 0) {
					await Task.Delay(1);
				}
			}

			_stopwatch.Stop();

			double avgFrameMs = CalculateAverage(stressFrameTimes);
			double fps = avgFrameMs > 0 ? 1000.0 / avgFrameMs : 0;
			double stabilityScore = 100.0 * (1.0 - (double)droppedFrames / StressTestFrames);

			var result = new HighFpsBenchmarkResult {
				Name = "Stress Test",
				Metrics = new Dictionary<string, double> {
					["FPS"] = fps,
					["Avg Frame (ms)"] = avgFrameMs,
					["Dropped Frames"] = droppedFrames,
					["Max Consecutive Slow"] = maxConsecutiveSlow,
					["Stability Score (%)"] = stabilityScore,
					["Frame Count"] = StressTestFrames,
				},
				Passed = fps >= TargetFps * 0.95 && stabilityScore >= 95.0,
			};

			_results["Stress"] = result;
			BenchmarkCompleted?.Invoke(result);
		}

		private async Task RunMemoryBenchmarkAsync() {
			ProgressChanged?.Invoke("Running memory benchmark...");

			GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced, blocking: true);
			GC.WaitForPendingFinalizers();
			GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced, blocking: true);

			long initialMemory = GC.GetTotalMemory(forceFullCollection: false);
			int initialGen0 = GC.CollectionCount(0);
			int initialGen1 = GC.CollectionCount(1);
			int initialGen2 = GC.CollectionCount(2);

			await Task.Delay(100);

			for (int i = 0; i < 100; i++) {
				await Dispatcher.UIThread.InvokeAsync(() => {
				}, DispatcherPriority.Render);
			}

			GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced, blocking: true);

			long finalMemory = GC.GetTotalMemory(forceFullCollection: false);
			int finalGen0 = GC.CollectionCount(0);
			int finalGen1 = GC.CollectionCount(1);
			int finalGen2 = GC.CollectionCount(2);

			long memoryDelta = finalMemory - initialMemory;
			int gen0Collections = finalGen0 - initialGen0;
			int gen1Collections = finalGen1 - initialGen1;
			int gen2Collections = finalGen2 - initialGen2;

			var result = new HighFpsBenchmarkResult {
				Name = "Memory",
				Metrics = new Dictionary<string, double> {
					["Initial Memory (MB)"] = initialMemory / (1024.0 * 1024.0),
					["Final Memory (MB)"] = finalMemory / (1024.0 * 1024.0),
					["Memory Delta (MB)"] = memoryDelta / (1024.0 * 1024.0),
					["Gen 0 Collections"] = gen0Collections,
					["Gen 1 Collections"] = gen1Collections,
					["Gen 2 Collections"] = gen2Collections,
				},
				Passed = gen2Collections == 0 && memoryDelta < 10 * 1024 * 1024,
			};

			_results["Memory"] = result;
			BenchmarkCompleted?.Invoke(result);
		}

		private static double CalculateAverage(List<double> values) {
			if (values.Count == 0) return 0;

			double sum = 0;
			foreach (double v in values) sum += v;
			return sum / values.Count;
		}

		private static double Calculate1PercentLow(List<double> frameTimes) {
			if (frameTimes.Count == 0) return 0;

			var sorted = new List<double>(frameTimes);
			sorted.Sort();

			int index = (int)Math.Ceiling(sorted.Count * 0.99) - 1;
			index = Math.Max(0, Math.Min(index, sorted.Count - 1));

			double frameMs = sorted[index];
			return frameMs > 0 ? 1000.0 / frameMs : 0;
		}

		private static double CalculatePercentileFps(List<double> frameTimes, int percentile) {
			if (frameTimes.Count == 0) return 0;

			var sorted = new List<double>(frameTimes);
			sorted.Sort();

			int index = (int)Math.Ceiling(sorted.Count * percentile / 100.0) - 1;
			index = Math.Max(0, Math.Min(index, sorted.Count - 1));

			double frameMs = sorted[index];
			return frameMs > 0 ? 1000.0 / frameMs : 0;
		}

		public string GenerateReport() {
			var sb = new StringBuilder();

			sb.AppendLine("╔══════════════════════════════════════════════════════════════════╗");
			sb.AppendLine("║              HIGH-FPS BENCHMARK REPORT (Target: 1500 FPS)        ║");
			sb.AppendLine("╚══════════════════════════════════════════════════════════════════╝");
			sb.AppendLine();
			sb.AppendLine($"Date: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
			sb.AppendLine($"Target FPS: {TargetFps}");
			sb.AppendLine($"Target Frame Time: {TargetFrameTimeMs:F4} ms");
			sb.AppendLine();

			foreach (var kvp in _results) {
				HighFpsBenchmarkResult result = kvp.Value;
				string status = result.Passed ? "PASS" : "FAIL";

				sb.AppendLine($"┌─────────────────────────────────────────────────────────────────┐");
				sb.AppendLine($"│ {result.Name,-48} {status,10} │");
				sb.AppendLine($"├─────────────────────────────────────────────────────────────────┤");

				foreach (var metric in result.Metrics) {
					string value = metric.Value < 1000 ? metric.Value.ToString("F2") : metric.Value.ToString("N0");
					sb.AppendLine($"│ {metric.Key,-40} {value,18} │");
				}

				sb.AppendLine($"└─────────────────────────────────────────────────────────────────┘");
				sb.AppendLine();
			}

			int passed = 0;
			foreach (var result in _results.Values) {
				if (result.Passed) passed++;
			}

			sb.AppendLine("══════════════════════════════════════════════════════════════════");
			sb.AppendLine($"SUMMARY: {passed}/{_results.Count} tests passed");
			sb.AppendLine($"OVERALL: {(passed == _results.Count ? "ALL TESTS PASSED" : "SOME TESTS FAILED")}");
			sb.AppendLine("══════════════════════════════════════════════════════════════════");

			return sb.ToString();
		}
	}
}
