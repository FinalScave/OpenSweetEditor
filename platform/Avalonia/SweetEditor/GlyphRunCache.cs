using System;
using System.Buffers;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Text;
using Avalonia;
using Avalonia.Media;

namespace SweetEditor {
	internal sealed class GlyphRunCache : IDisposable {
		private const int MaxCacheEntries = 16384;
		private const int MaxPooledBuilders = 32;
		private const int MaxTextLength = 256;

		private readonly LruCache<GlyphCacheKey, CachedGlyphRun> _cache;
		private readonly Dictionary<Typeface, TypefaceCache> _typefaceCaches;
		private readonly Stack<StringBuilder> _builderPool;
		private readonly object _lock = new();

		public GlyphRunCache() {
			_cache = new LruCache<GlyphCacheKey, CachedGlyphRun>(MaxCacheEntries);
			_typefaceCaches = new Dictionary<Typeface, TypefaceCache>(8);
			_builderPool = new Stack<StringBuilder>(MaxPooledBuilders);
		}

		public bool TryGet(string text, Typeface typeface, float size, int fontStyle, out GlyphRun? glyphRun) {
			glyphRun = null;
			if (string.IsNullOrEmpty(text) || text.Length > MaxTextLength) {
				return false;
			}

			var key = new GlyphCacheKey(text, typeface, size, fontStyle);
			lock (_lock) {
				if (_cache.TryGet(key, out CachedGlyphRun cached)) {
					glyphRun = cached.GlyphRun;
					return glyphRun != null;
				}
			}
			return false;
		}

		public void Set(string text, Typeface typeface, float size, int fontStyle, GlyphRun glyphRun) {
			if (string.IsNullOrEmpty(text) || text.Length > MaxTextLength || glyphRun == null) {
				return;
			}

			var key = new GlyphCacheKey(text, typeface, size, fontStyle);
			var cached = new CachedGlyphRun(glyphRun);
			lock (_lock) {
				_cache.Set(key, cached);
			}
		}

		public bool TryGetOrCreate(string text, Typeface typeface, float size, int fontStyle, out GlyphRun? glyphRun) {
			glyphRun = null;
			if (string.IsNullOrEmpty(text)) {
				return false;
			}

			if (text.Length <= MaxTextLength) {
				if (TryGet(text, typeface, size, fontStyle, out glyphRun)) {
					return glyphRun != null;
				}
			}

			if (typeface.GlyphTypeface is not IGlyphTypeface glyphTypeface) {
				return false;
			}

			if (!CanUseGlyphFastPath(text)) {
				return false;
			}

			glyphRun = CreateGlyphRun(text, glyphTypeface, size);
			if (glyphRun == null) {
				return false;
			}

			if (text.Length <= MaxTextLength) {
				Set(text, typeface, size, fontStyle, glyphRun);
			}

			return true;
		}

		public GlyphRun? GetOrCreate(string text, Typeface typeface, float size, int fontStyle) {
			TryGetOrCreate(text, typeface, size, fontStyle, out GlyphRun? glyphRun);
			return glyphRun;
		}

		private static GlyphRun? CreateGlyphRun(string text, IGlyphTypeface glyphTypeface, float size) {
			int length = text.Length;
			ushort[] glyphIndices = ArrayPool<ushort>.Shared.Rent(length);
			try {
				for (int i = 0; i < length; i++) {
					glyphIndices[i] = glyphTypeface.GetGlyph(text[i]);
				}
				return new GlyphRun(glyphTypeface, size, text.AsMemory(), glyphIndices.AsSpan(0, length).ToArray(), new Point(0, 0), 0);
			} finally {
				ArrayPool<ushort>.Shared.Return(glyphIndices);
			}
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private static bool CanUseGlyphFastPath(string text) {
			for (int i = 0; i < text.Length; i++) {
				char ch = text[i];
				if (ch > 0x7F || ch == '\t' || ch == '\r' || ch == '\n') {
					return false;
				}
			}
			return true;
		}

		public StringBuilder RentBuilder() {
			lock (_lock) {
				return _builderPool.Count > 0 ? _builderPool.Pop() : new StringBuilder(128);
			}
		}

		public void ReturnBuilder(StringBuilder builder) {
			if (builder == null) {
				return;
			}
			builder.Clear();
			lock (_lock) {
				if (_builderPool.Count < MaxPooledBuilders) {
					_builderPool.Push(builder);
				}
			}
		}

		public void Clear() {
			lock (_lock) {
				_cache.Clear();
				_typefaceCaches.Clear();
			}
		}

		public void Dispose() {
			Clear();
		}

		private readonly struct GlyphCacheKey : IEquatable<GlyphCacheKey> {
			private readonly string _text;
			private readonly Typeface _typeface;
			private readonly float _size;
			private readonly int _fontStyle;
			private readonly int _hashCode;

			public GlyphCacheKey(string text, Typeface typeface, float size, int fontStyle) {
				_text = text;
				_typeface = typeface;
				_size = size;
				_fontStyle = fontStyle;
				_hashCode = ComputeHashCode(text, typeface, size, fontStyle);
			}

			public bool Equals(GlyphCacheKey other) {
				return _fontStyle == other._fontStyle &&
					   _size == other._size &&
					   ReferenceEquals(_typeface, other._typeface) &&
					   string.Equals(_text, other._text, StringComparison.Ordinal);
			}

			public override bool Equals(object? obj) => obj is GlyphCacheKey key && Equals(key);

			public override int GetHashCode() => _hashCode;

			private static int ComputeHashCode(string text, Typeface typeface, float size, int fontStyle) {
				unchecked {
					int hash = text.GetHashCode();
					hash = hash * 31 + typeface.GetHashCode();
					hash = hash * 31 + size.GetHashCode();
					hash = hash * 31 + fontStyle;
					return hash;
				}
			}
		}

		private readonly struct CachedGlyphRun {
			public readonly GlyphRun GlyphRun;

			public CachedGlyphRun(GlyphRun glyphRun) {
				GlyphRun = glyphRun;
			}
		}

		private sealed class TypefaceCache {
			public readonly Dictionary<int, GlyphRun> RunsByTextHash = new();
		}
	}
}
