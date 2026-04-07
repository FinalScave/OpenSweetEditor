using System;
using System.Buffers;
using System.Collections.Generic;

namespace SweetEditor {
	internal static class RenderBufferPool {
		private const int DefaultBufferSize = 256;
		private const int MaxBufferSize = 16384;
		private const int MaxPooledArrays = 64;

		private static readonly ArrayPool<float> FloatPool = ArrayPool<float>.Create(MaxBufferSize, MaxPooledArrays);
		private static readonly ArrayPool<int> IntPool = ArrayPool<int>.Create(MaxBufferSize, MaxPooledArrays);
		private static readonly ArrayPool<double> DoublePool = ArrayPool<double>.Create(MaxBufferSize, MaxPooledArrays);

		public static float[] RentFloatArray(int minimumLength) {
			return FloatPool.Rent(minimumLength);
		}

		public static void ReturnFloatArray(float[] array) {
			FloatPool.Return(array);
		}

		public static int[] RentIntArray(int minimumLength) {
			return IntPool.Rent(minimumLength);
		}

		public static void ReturnIntArray(int[] array) {
			IntPool.Return(array);
		}

		public static double[] RentDoubleArray(int minimumLength) {
			return DoublePool.Rent(minimumLength);
		}

		public static void ReturnDoubleArray(double[] array) {
			DoublePool.Return(array);
		}
	}

	internal sealed class PooledList<T> : IDisposable {
		private const int DefaultCapacity = 64;
		private static readonly ArrayPool<T> Pool = ArrayPool<T>.Create(8192, 64);

		private T[] _items;
		private int _count;
		private bool _disposed;

		public PooledList() {
			_items = Pool.Rent(DefaultCapacity);
			_count = 0;
		}

		public PooledList(int capacity) {
			_items = Pool.Rent(Math.Max(1, capacity));
			_count = 0;
		}

		public int Count => _count;
		public int Capacity => _items.Length;
		public bool IsReadOnly => false;

		public ref T this[int index] {
			get {
				if ((uint)index >= (uint)_count) {
					throw new ArgumentOutOfRangeException(nameof(index));
				}
				return ref _items[index];
			}
		}

		public void Add(T item) {
			if (_count == _items.Length) {
				Grow();
			}
			_items[_count++] = item;
		}

		public void AddRange(ReadOnlySpan<T> items) {
			if (_count + items.Length > _items.Length) {
				Grow(_count + items.Length);
			}
			items.CopyTo(_items.AsSpan(_count));
			_count += items.Length;
		}

		public void Clear() {
			if (RuntimeHelpers.IsReferenceOrContainsReferences<T>()) {
				Array.Clear(_items, 0, _count);
			}
			_count = 0;
		}

		public void RemoveAt(int index) {
			if ((uint)index >= (uint)_count) {
				throw new ArgumentOutOfRangeException(nameof(index));
			}
			_count--;
			if (index < _count) {
				Array.Copy(_items, index + 1, _items, index, _count - index);
			}
			if (RuntimeHelpers.IsReferenceOrContainsReferences<T>()) {
				_items[_count] = default!;
			}
		}

		public bool Remove(T item) {
			int index = Array.IndexOf(_items, item, 0, _count);
			if (index >= 0) {
				RemoveAt(index);
				return true;
			}
			return false;
		}

		public T[] ToArray() {
			T[] result = new T[_count];
			Array.Copy(_items, result, _count);
			return result;
		}

		public Span<T> AsSpan() {
			return _items.AsSpan(0, _count);
		}

		public ReadOnlySpan<T> AsReadOnlySpan() {
			return _items.AsSpan(0, _count);
		}

		public void Dispose() {
			if (_disposed) {
				return;
			}
			_disposed = true;
			Pool.Return(_items);
			_items = Array.Empty<T>();
			_count = 0;
		}

		private void Grow() {
			Grow(_items.Length * 2);
		}

		private void Grow(int newCapacity) {
			newCapacity = Math.Max(newCapacity, _items.Length * 2);
			T[] newArray = Pool.Rent(newCapacity);
			Array.Copy(_items, newArray, _count);
			Pool.Return(_items);
			_items = newArray;
		}
	}

	internal static class RuntimeHelpers {
		public static bool IsReferenceOrContainsReferences<T>() {
			return !typeof(T).IsValueType || (typeof(T).IsGenericType && typeof(T).GetGenericTypeDefinition() == typeof(Nullable<>));
		}
	}
}
