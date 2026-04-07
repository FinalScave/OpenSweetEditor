using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace SweetEditor {
	internal sealed class RenderOptimizer {
		private const int MaxDirtyRegions = 32;
		private const float MinDirtyWidth = 8f;
		private const float MinDirtyHeight = 4f;

		private readonly List<DirtyRect> _dirtyRegions = new(MaxDirtyRegions);
		private readonly List<DirtyRect> _mergedRegions = new(8);
		private bool _fullInvalidation;

		private int _cachedVisibleStartLine = -1;
		private int _cachedVisibleEndLine = -1;
		private float _cachedScrollX = float.MinValue;
		private float _cachedScrollY = float.MinValue;
		private int _cachedLineCount = -1;

		public bool HasFullInvalidation => _fullInvalidation;
		public IReadOnlyList<DirtyRect> DirtyRegions => _mergedRegions;

		public void InvalidateFull() {
			_fullInvalidation = true;
			_dirtyRegions.Clear();
			_mergedRegions.Clear();
		}

		public void InvalidateRect(float x, float y, float width, float height) {
			if (_fullInvalidation) {
				return;
			}

			if (width < MinDirtyWidth || height < MinDirtyHeight) {
				return;
			}

			DirtyRect region = new DirtyRect(x, y, width, height);
			_dirtyRegions.Add(region);

			if (_dirtyRegions.Count >= MaxDirtyRegions) {
				InvalidateFull();
			}
		}

		public void InvalidateLine(int lineIndex, float y, float height, float viewportWidth) {
			if (_fullInvalidation) {
				return;
			}

			InvalidateRect(0, y, viewportWidth, height);
		}

		public void InvalidateLineRange(int startLine, int endLine, float lineHeight, float viewportWidth) {
			if (_fullInvalidation) {
				return;
			}

			float y = startLine * lineHeight;
			float height = (endLine - startLine + 1) * lineHeight;
			InvalidateRect(0, y, viewportWidth, height);
		}

		public bool PrepareForRender(int visibleStartLine, int visibleEndLine, float scrollX, float scrollY, int lineCount) {
			bool needsRender = _fullInvalidation;

			if (!_fullInvalidation) {
				if (visibleStartLine != _cachedVisibleStartLine || visibleEndLine != _cachedVisibleEndLine) {
					needsRender = true;
				}
				if (Math.Abs(scrollX - _cachedScrollX) > 0.5f || Math.Abs(scrollY - _cachedScrollY) > 0.5f) {
					needsRender = true;
				}
				if (lineCount != _cachedLineCount) {
					needsRender = true;
				}
				if (_dirtyRegions.Count > 0) {
					needsRender = true;
				}
			}

			_cachedVisibleStartLine = visibleStartLine;
			_cachedVisibleEndLine = visibleEndLine;
			_cachedScrollX = scrollX;
			_cachedScrollY = scrollY;
			_cachedLineCount = lineCount;

			if (needsRender && !_fullInvalidation) {
				MergeDirtyRegions();
			}

			return needsRender;
		}

		public void Reset() {
			_fullInvalidation = false;
			_dirtyRegions.Clear();
			_mergedRegions.Clear();
		}

		public void Clear() {
			_fullInvalidation = false;
			_dirtyRegions.Clear();
			_mergedRegions.Clear();
			_cachedVisibleStartLine = -1;
			_cachedVisibleEndLine = -1;
			_cachedScrollX = float.MinValue;
			_cachedScrollY = float.MinValue;
			_cachedLineCount = -1;
		}

		private void MergeDirtyRegions() {
			_mergedRegions.Clear();

			if (_dirtyRegions.Count == 0) {
				return;
			}

			if (_dirtyRegions.Count == 1) {
				_mergedRegions.Add(_dirtyRegions[0]);
				_dirtyRegions.Clear();
				return;
			}

			_dirtyRegions.Sort((a, b) => a.Y.CompareTo(b.Y));

			DirtyRect current = _dirtyRegions[0];
			for (int i = 1; i < _dirtyRegions.Count; i++) {
				DirtyRect next = _dirtyRegions[i];
				if (TryMergeVertical(current, next, out DirtyRect merged)) {
					current = merged;
				} else {
					_mergedRegions.Add(current);
					current = next;
				}
			}
			_mergedRegions.Add(current);

			_dirtyRegions.Clear();
		}

		private static bool TryMergeVertical(DirtyRect a, DirtyRect b, out DirtyRect merged) {
			merged = default;

			float gap = b.Y - (a.Y + a.Height);
			if (gap > a.Height * 0.5f) {
				return false;
			}

			float minX = Math.Min(a.X, b.X);
			float maxX = Math.Max(a.X + a.Width, b.X + b.Width);
			float minY = a.Y;
			float maxY = Math.Max(a.Y + a.Height, b.Y + b.Height);

			merged = new DirtyRect(minX, minY, maxX - minX, maxY - minY);
			return true;
		}
	}

	internal readonly struct DirtyRect {
		public readonly float X;
		public readonly float Y;
		public readonly float Width;
		public readonly float Height;

		public DirtyRect(float x, float y, float width, float height) {
			X = x;
			Y = y;
			Width = Math.Max(0, width);
			Height = Math.Max(0, height);
		}

		public float Right => X + Width;
		public float Bottom => Y + Height;

		public bool Intersects(DirtyRect other) {
			return X < other.Right && Right > other.X && Y < other.Bottom && Bottom > other.Y;
		}

		public bool Contains(float x, float y) {
			return x >= X && x < Right && y >= Y && y < Bottom;
		}
	}
}
