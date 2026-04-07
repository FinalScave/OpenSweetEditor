using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace SweetEditor {
	internal sealed class FrameRateMonitor {
		private const int FrameHistorySize = 60;
		private const double TargetFrameTimeMs = 1000.0 / 1500.0;
		private const double WarningThresholdMs = 1000.0 / 1440.0;

		private readonly double[] _frameTimes = new double[FrameHistorySize];
		private readonly double[] _buildTimes = new double[FrameHistorySize];
		private readonly double[] _drawTimes = new double[FrameHistorySize];
		private readonly Stopwatch _stopwatch = Stopwatch.StartNew();
		private readonly Queue<double> _recentFrameTimes = new(FrameHistorySize);

		private int _frameIndex;
		private int _frameCount;
		private long _lastFrameTicks;
		private double _currentFps;
		private double _averageFps;
		private double _minFps;
		private double _maxFps;
		private double _averageBuildMs;
		private double _averageDrawMs;
		private double _jitter;
		private int _framesBelowTarget;
		private bool _initialized;

		public double CurrentFps => _currentFps;
		public double AverageFps => _averageFps;
		public double MinFps => _minFps;
		public double MaxFps => _maxFps;
		public double AverageFrameTimeMs => _averageFps > 0 ? 1000.0 / _averageFps : 0;
		public double AverageBuildMs => _averageBuildMs;
		public double AverageDrawMs => _averageDrawMs;
		public double Jitter => _jitter;
		public int FramesBelowTarget => _framesBelowTarget;
		public bool IsHealthy => _averageFps >= 1440.0;

		public void BeginFrame() {
			_lastFrameTicks = _stopwatch.ElapsedTicks;
		}

		public void EndFrame(double buildMs, double drawMs) {
			long currentTicks = _stopwatch.ElapsedTicks;
			double frameTimeMs = (currentTicks - _lastFrameTicks) * 1000.0 / Stopwatch.Frequency;

			_frameTimes[_frameIndex] = frameTimeMs;
			_buildTimes[_frameIndex] = buildMs;
			_drawTimes[_frameIndex] = drawMs;
			_frameIndex = (_frameIndex + 1) % FrameHistorySize;
			_frameCount++;

			_recentFrameTimes.Enqueue(frameTimeMs);
			while (_recentFrameTimes.Count > FrameHistorySize) {
				_recentFrameTimes.Dequeue();
			}

			UpdateStatistics();
		}

		private void UpdateStatistics() {
			if (_frameCount < 2) {
				return;
			}

			int count = Math.Min(_frameCount, FrameHistorySize);
			double totalFrameTime = 0;
			double totalBuildTime = 0;
			double totalDrawTime = 0;
			double minFrameTime = double.MaxValue;
			double maxFrameTime = double.MinValue;
			int belowTarget = 0;

			for (int i = 0; i < count; i++) {
				double frameTime = _frameTimes[i];
				totalFrameTime += frameTime;
				totalBuildTime += _buildTimes[i];
				totalDrawTime += _drawTimes[i];
				if (frameTime < minFrameTime) minFrameTime = frameTime;
				if (frameTime > maxFrameTime) maxFrameTime = frameTime;
				if (frameTime > TargetFrameTimeMs) belowTarget++;
			}

			double avgFrameTime = totalFrameTime / count;
			_currentFps = avgFrameTime > 0 ? 1000.0 / avgFrameTime : 0;
			_averageFps = _currentFps;
			_minFps = maxFrameTime > 0 ? 1000.0 / maxFrameTime : 0;
			_maxFps = minFrameTime > 0 ? 1000.0 / minFrameTime : 0;
			_averageBuildMs = totalBuildTime / count;
			_averageDrawMs = totalDrawTime / count;
			_framesBelowTarget = belowTarget;

			if (_recentFrameTimes.Count >= 3) {
				double variance = 0;
				double[] times = _recentFrameTimes.ToArray();
				foreach (double t in times) {
					variance += (t - avgFrameTime) * (t - avgFrameTime);
				}
				_jitter = Math.Sqrt(variance / times.Length);
			}

			_initialized = true;
		}

		public FrameRateSnapshot GetSnapshot() {
			return new FrameRateSnapshot(
				_currentFps,
				_averageFps,
				_minFps,
				_maxFps,
				AverageFrameTimeMs,
				_averageBuildMs,
				_averageDrawMs,
				_jitter,
				_framesBelowTarget,
				IsHealthy);
		}

		public string GetStatusText() {
			if (!_initialized) {
				return "Initializing...";
			}

			string healthStatus = IsHealthy ? "OK" : "WARN";
			return $"FPS: {_currentFps:0} avg={_averageFps:0} min={_minFps:0} max={_maxFps:0} [{healthStatus}] build={_averageBuildMs:0.00}ms draw={_averageDrawMs:0.00}ms jitter={_jitter:0.00}ms";
		}

		public void Reset() {
			_frameIndex = 0;
			_frameCount = 0;
			_lastFrameTicks = 0;
			_currentFps = 0;
			_averageFps = 0;
			_minFps = 0;
			_maxFps = 0;
			_averageBuildMs = 0;
			_averageDrawMs = 0;
			_jitter = 0;
			_framesBelowTarget = 0;
			_initialized = false;
			_recentFrameTimes.Clear();
			Array.Clear(_frameTimes, 0, _frameTimes.Length);
			Array.Clear(_buildTimes, 0, _buildTimes.Length);
			Array.Clear(_drawTimes, 0, _drawTimes.Length);
		}
	}

	public readonly struct FrameRateSnapshot {
		public readonly double CurrentFps;
		public readonly double AverageFps;
		public readonly double MinFps;
		public readonly double MaxFps;
		public readonly double AverageFrameTimeMs;
		public readonly double AverageBuildMs;
		public readonly double AverageDrawMs;
		public readonly double Jitter;
		public readonly int FramesBelowTarget;
		public readonly bool IsHealthy;

		public FrameRateSnapshot(
			double currentFps,
			double averageFps,
			double minFps,
			double maxFps,
			double averageFrameTimeMs,
			double averageBuildMs,
			double averageDrawMs,
			double jitter,
			int framesBelowTarget,
			bool isHealthy) {
			CurrentFps = currentFps;
			AverageFps = averageFps;
			MinFps = minFps;
			MaxFps = maxFps;
			AverageFrameTimeMs = averageFrameTimeMs;
			AverageBuildMs = averageBuildMs;
			AverageDrawMs = averageDrawMs;
			Jitter = jitter;
			FramesBelowTarget = framesBelowTarget;
			IsHealthy = isHealthy;
		}
	}
}
