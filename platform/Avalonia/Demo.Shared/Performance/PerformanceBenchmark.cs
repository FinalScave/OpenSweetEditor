using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using Avalonia.Threading;
using SweetEditor.Avalonia.Demo.Performance;

namespace SweetEditor.Avalonia.Demo.Performance;

/// <summary>
/// Performance benchmark suite for measuring editor performance.
/// </summary>
public sealed class PerformanceBenchmark
{
    private readonly Dictionary<string, BenchmarkResult> _results = new();
    private readonly List<double> _frameTimes = new(1000);
    private readonly Stopwatch _stopwatch = new();
    private bool _isRunning;

    public event Action<BenchmarkResult>? BenchmarkCompleted;
    public event Action<string>? ProgressChanged;

    public IReadOnlyDictionary<string, BenchmarkResult> Results => _results;

    public void RunFullBenchmark()
    {
        if (_isRunning)
            return;

        _isRunning = true;
        _results.Clear();
        _frameTimes.Clear();

        Dispatcher.UIThread.Post(async () =>
        {
            try
            {
                await RunBenchmarkAsync();
            }
            finally
            {
                _isRunning = false;
            }
        });
    }

    private async System.Threading.Tasks.Task RunBenchmarkAsync()
    {
        ProgressChanged?.Invoke("Starting performance benchmark...");

        await MeasureFrameRateAsync();
        await MeasureMemoryUsageAsync();
        await MeasureRenderingPerformanceAsync();

        ProgressChanged?.Invoke("Benchmark completed!");
    }

    private async System.Threading.Tasks.Task MeasureFrameRateAsync()
    {
        ProgressChanged?.Invoke("Measuring frame rate...");

        _frameTimes.Clear();
        _stopwatch.Restart();

        int frameCount = 0;
        int targetFrames = 300;

        while (frameCount < targetFrames)
        {
            long frameStart = _stopwatch.ElapsedTicks;

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                PerfMonitor.BeginFrame();
                PerfMonitor.EndFrame();
            }, DispatcherPriority.Render);

            long frameEnd = _stopwatch.ElapsedTicks;
            double frameMs = (frameEnd - frameStart) * 1000.0 / Stopwatch.Frequency;
            _frameTimes.Add(frameMs);

            frameCount++;

            if (frameCount % 60 == 0)
            {
                await System.Threading.Tasks.Task.Delay(1);
            }
        }

        _stopwatch.Stop();

        double avgFrameMs = CalculateAverage(_frameTimes);
        double minFrameMs = CalculateMin(_frameTimes);
        double maxFrameMs = CalculateMax(_frameTimes);
        double fps = avgFrameMs > 0 ? 1000.0 / avgFrameMs : 0;

        var result = new BenchmarkResult
        {
            Name = "Frame Rate",
            Metrics = new Dictionary<string, double>
            {
                ["FPS"] = fps,
                ["Avg Frame (ms)"] = avgFrameMs,
                ["Min Frame (ms)"] = minFrameMs,
                ["Max Frame (ms)"] = maxFrameMs,
                ["Frame Count"] = targetFrames,
            },
            Passed = fps >= 1500,
        };

        _results["FrameRate"] = result;
        BenchmarkCompleted?.Invoke(result);
    }

    private async System.Threading.Tasks.Task MeasureMemoryUsageAsync()
    {
        ProgressChanged?.Invoke("Measuring memory usage...");

        await System.Threading.Tasks.Task.Delay(100);

        long totalMemory = GC.GetTotalMemory(false);
        long peakMemory = GetPeakMemoryUsage();

        var result = new BenchmarkResult
        {
            Name = "Memory Usage",
            Metrics = new Dictionary<string, double>
            {
                ["Total Memory (MB)"] = totalMemory / (1024.0 * 1024.0),
                ["Peak Memory (MB)"] = peakMemory / (1024.0 * 1024.0),
                ["Gen 0 Collections"] = GC.CollectionCount(0),
                ["Gen 1 Collections"] = GC.CollectionCount(1),
                ["Gen 2 Collections"] = GC.CollectionCount(2),
            },
            Passed = totalMemory < 100 * 1024 * 1024,
        };

        _results["Memory"] = result;
        BenchmarkCompleted?.Invoke(result);
    }

    private async System.Threading.Tasks.Task MeasureRenderingPerformanceAsync()
    {
        ProgressChanged?.Invoke("Measuring rendering performance...");

        var renderTimes = new List<double>(100);

        for (int i = 0; i < 100; i++)
        {
            var timer = PerfTimer.Start(ms => renderTimes.Add(ms));

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
            }, DispatcherPriority.Render);

            timer.Dispose();
        }

        double avgRenderMs = CalculateAverage(renderTimes);
        double renderFps = avgRenderMs > 0 ? 1000.0 / avgRenderMs : 0;

        var result = new BenchmarkResult
        {
            Name = "Rendering",
            Metrics = new Dictionary<string, double>
            {
                ["Render FPS"] = renderFps,
                ["Avg Render (ms)"] = avgRenderMs,
            },
            Passed = renderFps >= 1500,
        };

        _results["Rendering"] = result;
        BenchmarkCompleted?.Invoke(result);
    }

    private static double CalculateAverage(List<double> values)
    {
        if (values.Count == 0)
            return 0;

        double sum = 0;
        foreach (double v in values)
            sum += v;

        return sum / values.Count;
    }

    private static double CalculateMin(List<double> values)
    {
        if (values.Count == 0)
            return 0;

        double min = double.MaxValue;
        foreach (double v in values)
            if (v < min)
                min = v;

        return min;
    }

    private static double CalculateMax(List<double> values)
    {
        if (values.Count == 0)
            return 0;

        double max = double.MinValue;
        foreach (double v in values)
            if (v > max)
                max = v;

        return max;
    }

    private static long GetPeakMemoryUsage()
    {
        try
        {
            using var process = Process.GetCurrentProcess();
            return process.PeakWorkingSet64;
        }
        catch
        {
            return 0;
        }
    }

    public string GenerateReport()
    {
        var sb = StringBuilderPool.Rent();

        sb.AppendLine("=== Performance Benchmark Report ===");
        sb.AppendLine($"Date: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        sb.AppendLine();

        foreach (var kvp in _results)
        {
            BenchmarkResult result = kvp.Value;
            sb.AppendLine($"[{result.Name}] {(result.Passed ? "PASS" : "FAIL")}");

            foreach (var metric in result.Metrics)
            {
                sb.AppendLine($"  {metric.Key}: {metric.Value:F2}");
            }

            sb.AppendLine();
        }

        sb.AppendLine("=== Summary ===");

        int passed = 0;
        int total = _results.Count;

        foreach (var result in _results.Values)
        {
            if (result.Passed)
                passed++;
        }

        sb.AppendLine($"Passed: {passed}/{total}");
        sb.AppendLine($"Overall: {(passed == total ? "PASS" : "FAIL")}");

        return StringBuilderPool.GetStringAndReturn(sb);
    }
}

/// <summary>
/// Represents a single benchmark result.
/// </summary>
public sealed class BenchmarkResult
{
    public string Name { get; set; } = "";
    public Dictionary<string, double> Metrics { get; set; } = new();
    public bool Passed { get; set; }
}
