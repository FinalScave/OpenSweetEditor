using System;
using System.Collections.Generic;

namespace SweetEditor {
	internal sealed class LruCache<TKey, TValue> where TKey : notnull {
		private readonly LinkedList<KeyValuePair<TKey, TValue>> _list;
		private readonly Dictionary<TKey, LinkedListNode<KeyValuePair<TKey, TValue>>> _map;
		private readonly int _maxCapacity;

		public LruCache(int maxCapacity) {
			if (maxCapacity <= 0) {
				throw new ArgumentOutOfRangeException(nameof(maxCapacity), "Capacity must be positive.");
			}
			_maxCapacity = maxCapacity;
			_list = new LinkedList<KeyValuePair<TKey, TValue>>();
			_map = new Dictionary<TKey, LinkedListNode<KeyValuePair<TKey, TValue>>>(maxCapacity);
		}

		public int Count => _map.Count;

		public bool TryGet(TKey key, out TValue? value) {
			if (_map.TryGetValue(key, out LinkedListNode<KeyValuePair<TKey, TValue>>? node)) {
				_list.Remove(node);
				_list.AddFirst(node);
				value = node.Value.Value;
				return true;
			}
			value = default;
			return false;
		}

		public void Set(TKey key, TValue value) {
			if (_map.TryGetValue(key, out LinkedListNode<KeyValuePair<TKey, TValue>>? existingNode)) {
				_list.Remove(existingNode);
				existingNode.Value = new KeyValuePair<TKey, TValue>(key, value);
				_list.AddFirst(existingNode);
				return;
			}

			if (_map.Count >= _maxCapacity) {
				LinkedListNode<KeyValuePair<TKey, TValue>>? last = _list.Last;
				if (last != null) {
					_map.Remove(last.Value.Key);
					_list.RemoveLast();
				}
			}

			LinkedListNode<KeyValuePair<TKey, TValue>> node = _list.AddFirst(new KeyValuePair<TKey, TValue>(key, value));
			_map[key] = node;
		}

		public void Clear() {
			_list.Clear();
			_map.Clear();
		}
	}

	internal sealed class LruCacheLongKey<TValue> {
		private readonly LinkedList<KeyValuePair<long, TValue>> _list;
		private readonly Dictionary<long, LinkedListNode<KeyValuePair<long, TValue>>> _map;
		private readonly int _maxCapacity;

		public LruCacheLongKey(int maxCapacity) {
			if (maxCapacity <= 0) {
				throw new ArgumentOutOfRangeException(nameof(maxCapacity), "Capacity must be positive.");
			}
			_maxCapacity = maxCapacity;
			_list = new LinkedList<KeyValuePair<long, TValue>>();
			_map = new Dictionary<long, LinkedListNode<KeyValuePair<long, TValue>>>(maxCapacity);
		}

		public int Count => _map.Count;

		public bool TryGet(long key, out TValue? value) {
			if (_map.TryGetValue(key, out LinkedListNode<KeyValuePair<long, TValue>>? node)) {
				_list.Remove(node);
				_list.AddFirst(node);
				value = node.Value.Value;
				return true;
			}
			value = default;
			return false;
		}

		public void Set(long key, TValue value) {
			if (_map.TryGetValue(key, out LinkedListNode<KeyValuePair<long, TValue>>? existingNode)) {
				_list.Remove(existingNode);
				existingNode.Value = new KeyValuePair<long, TValue>(key, value);
				_list.AddFirst(existingNode);
				return;
			}

			if (_map.Count >= _maxCapacity) {
				LinkedListNode<KeyValuePair<long, TValue>>? last = _list.Last;
				if (last != null) {
					_map.Remove(last.Value.Key);
					_list.RemoveLast();
				}
			}

			LinkedListNode<KeyValuePair<long, TValue>> node = _list.AddFirst(new KeyValuePair<long, TValue>(key, value));
			_map[key] = node;
		}

		public void Clear() {
			_list.Clear();
			_map.Clear();
		}
	}
}
