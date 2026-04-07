using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Text;

namespace SweetEditor.Avalonia.Demo.Performance;

/// <summary>
/// High-performance object pool for reducing GC pressure.
/// Provides thread-safe pooling of frequently allocated objects.
/// </summary>
public sealed class ObjectPool<T> where T : class, new()
{
    private readonly Stack<T> _pool;
    private readonly int _maxPoolSize;

    public ObjectPool(int initialCapacity = 16, int maxPoolSize = 256)
    {
        _maxPoolSize = maxPoolSize;
        _pool = new Stack<T>(initialCapacity);
        
        for (int i = 0; i < initialCapacity; i++)
        {
            _pool.Push(new T());
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public T Rent()
    {
        lock (_pool)
        {
            return _pool.Count > 0 ? _pool.Pop() : new T();
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public void Return(T item)
    {
        lock (_pool)
        {
            if (_pool.Count < _maxPoolSize)
            {
                _pool.Push(item);
            }
        }
    }

    public void Clear()
    {
        lock (_pool)
        {
            _pool.Clear();
        }
    }

    public int AvailableCount
    {
        get
        {
            lock (_pool)
            {
                return _pool.Count;
            }
        }
    }
}

/// <summary>
/// String builder pool for reducing string allocation overhead.
/// </summary>
public static class StringBuilderPool
{
    private static readonly Stack<StringBuilder> Pool = new();
    private const int MaxPoolSize = 32;
    private const int DefaultCapacity = 256;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static StringBuilder Rent()
    {
        lock (Pool)
        {
            if (Pool.Count > 0)
            {
                StringBuilder sb = Pool.Pop();
                sb.Clear();
                return sb;
            }
        }
        return new StringBuilder(DefaultCapacity);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static void Return(StringBuilder sb)
    {
        if (sb == null || sb.Capacity > 4096)
            return;

        lock (Pool)
        {
            if (Pool.Count < MaxPoolSize)
            {
                Pool.Push(sb);
            }
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static string GetStringAndReturn(StringBuilder sb)
    {
        string result = sb.ToString();
        Return(sb);
        return result;
    }
}

/// <summary>
/// List pool for reducing List allocation overhead.
/// </summary>
public static class ListPool<T>
{
    private static readonly Stack<List<T>> Pool = new();
    private const int MaxPoolSize = 64;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static List<T> Rent(int capacity = 16)
    {
        lock (Pool)
        {
            if (Pool.Count > 0)
            {
                return Pool.Pop();
            }
        }
        return new List<T>(capacity);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static void Return(List<T> list)
    {
        if (list == null || list.Capacity > 65536)
            return;

        list.Clear();
        lock (Pool)
        {
            if (Pool.Count < MaxPoolSize)
            {
                Pool.Push(list);
            }
        }
    }
}

/// <summary>
/// Performance monitoring and profiling utilities.
/// </summary>
public static class PerfMonitor
{
    private static readonly double TickToMs = 1000.0 / System.Diagnostics.Stopwatch.Frequency;
    private static readonly long[] FrameTimes = new long[60];
    private static int _frameIndex;
    private static int _frameCount;
    private static long _lastFrameTime;

    public static double CurrentFps { get; private set; }
    public static double AverageFrameTimeMs { get; private set; }
    public static double MinFrameTimeMs { get; private set; } = double.MaxValue;
    public static double MaxFrameTimeMs { get; private set; }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static void BeginFrame()
    {
        _lastFrameTime = System.Diagnostics.Stopwatch.GetTimestamp();
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static void EndFrame()
    {
        long now = System.Diagnostics.Stopwatch.GetTimestamp();
        long elapsed = now - _lastFrameTime;

        FrameTimes[_frameIndex] = elapsed;
        _frameIndex = (_frameIndex + 1) % FrameTimes.Length;
        _frameCount++;

        if (_frameCount >= FrameTimes.Length)
        {
            UpdateStats();
        }
    }

    private static void UpdateStats()
    {
        long total = 0;
        long min = long.MaxValue;
        long max = long.MinValue;

        for (int i = 0; i < FrameTimes.Length; i++)
        {
            long t = FrameTimes[i];
            total += t;
            if (t < min) min = t;
            if (t > max) max = t;
        }

        double avgMs = total * TickToMs / FrameTimes.Length;
        CurrentFps = avgMs > 0 ? 1000.0 / avgMs : 0;
        AverageFrameTimeMs = avgMs;
        MinFrameTimeMs = min * TickToMs;
        MaxFrameTimeMs = max * TickToMs;
    }

    public static string GetStatsString()
    {
        return $"FPS: {CurrentFps:F1} | Frame: {AverageFrameTimeMs:F2}ms ({MinFrameTimeMs:F2}-{MaxFrameTimeMs:F2}ms)";
    }
}

/// <summary>
/// High-resolution timer for micro-benchmarks.
/// </summary>
public readonly struct PerfTimer : IDisposable
{
    private static readonly double TickToMs = 1000.0 / System.Diagnostics.Stopwatch.Frequency;
    private readonly long _startTicks;
    private readonly Action<double> _callback;

    private PerfTimer(Action<double> callback)
    {
        _startTicks = System.Diagnostics.Stopwatch.GetTimestamp();
        _callback = callback;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static PerfTimer Start(Action<double> callback)
    {
        return new PerfTimer(callback);
    }

    public double ElapsedMs
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => (System.Diagnostics.Stopwatch.GetTimestamp() - _startTicks) * TickToMs;
    }

    public void Dispose()
    {
        _callback?.Invoke(ElapsedMs);
    }
}

/// <summary>
/// Fast hash for string interning and caching.
/// </summary>
public static class FastHash
{
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static int Compute(string? value)
    {
        if (value == null)
            return 0;

        unchecked
        {
            uint hash = 5381;
            for (int i = 0; i < value.Length; i++)
            {
                hash = ((hash << 5) + hash) ^ value[i];
            }
            return (int)hash;
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static int Combine(int hash1, int hash2)
    {
        unchecked
        {
            return (hash1 * 31) + hash2;
        }
    }
}
