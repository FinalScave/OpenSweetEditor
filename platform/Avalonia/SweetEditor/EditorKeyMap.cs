using System;
using System.Collections.Generic;
using Avalonia.Input;

namespace SweetEditor {
	internal enum KeyMapMatchKind {
		None = 0,
		AwaitingSecondChord = 1,
		Command = 2,
	}

	internal readonly struct KeyMapMatch {
		public static readonly KeyMapMatch None = new(KeyMapMatchKind.None, 0);

		public KeyMapMatch(KeyMapMatchKind kind, int commandId) {
			Kind = kind;
			CommandId = commandId;
		}

		public KeyMapMatchKind Kind { get; }

		public int CommandId { get; }

		public bool HasMatch => Kind != KeyMapMatchKind.None;

		public bool AwaitingSecondChord => Kind == KeyMapMatchKind.AwaitingSecondChord;

		public bool IsCommand => Kind == KeyMapMatchKind.Command;

		public static KeyMapMatch WaitSecondChord() => new(KeyMapMatchKind.AwaitingSecondChord, 0);

		public static KeyMapMatch Command(int commandId) => new(KeyMapMatchKind.Command, commandId);
	}

	internal enum EditorCommandRoute {
		Core = 0,
		Host = 1,
	}

	public sealed class EditorKeyMap {
		public delegate bool EditorCommandHandler(SweetEditorControl editor);

		public const int BUILT_IN_MAX = (int)EditorBuiltinCommand.TRIGGER_COMPLETION;

		private readonly List<KeyBinding> bindings = new();
		private readonly Dictionary<int, EditorCommandHandler> hostCommandHandlers = new();
		private int nextCustomCommandId = BUILT_IN_MAX + 1;

		public EditorKeyMap() {
		}

		public EditorKeyMap(IEnumerable<KeyBinding>? bindings) {
			if (bindings == null) {
				return;
			}
			foreach (KeyBinding binding in bindings) {
				AddOrReplace(binding);
			}
		}

		public IReadOnlyList<KeyBinding> Bindings => bindings;

		public int Count => bindings.Count;

		public void Clear() {
			bindings.Clear();
		}

		public void Add(KeyBinding binding) {
			if (binding == null) {
				return;
			}
			bindings.Add(binding);
		}

		public void AddOrReplace(KeyBinding binding) {
			if (binding == null) {
				return;
			}
			for (int i = bindings.Count - 1; i >= 0; i--) {
				KeyBinding existing = bindings[i];
				if (existing.First == binding.First && existing.Second == binding.Second) {
					bindings.RemoveAt(i);
				}
			}
			bindings.Add(binding);
		}

		public bool Remove(KeyBinding binding) {
			return bindings.Remove(binding);
		}

		internal int RemoveByCommand(int commandId) {
			int removed = 0;
			for (int i = bindings.Count - 1; i >= 0; i--) {
				if (bindings[i].Command == commandId) {
					bindings.RemoveAt(i);
					removed++;
				}
			}
			return removed;
		}

		internal bool TryResolve(KeyChord first, out int commandId) {
			for (int i = 0; i < bindings.Count; i++) {
				KeyBinding binding = bindings[i];
				if (binding.First == first && binding.Second.IsEmpty) {
					commandId = binding.Command;
					return true;
				}
			}

			commandId = 0;
			return false;
		}

		internal bool TryResolve(KeyChord first, KeyChord second, out int commandId) {
			for (int i = 0; i < bindings.Count; i++) {
				KeyBinding binding = bindings[i];
				if (binding.First == first && binding.Second == second) {
					commandId = binding.Command;
					return true;
				}
			}

			commandId = 0;
			return false;
		}

		internal bool HasSecondChordPrefix(KeyChord first) {
			for (int i = 0; i < bindings.Count; i++) {
				KeyBinding binding = bindings[i];
				if (binding.First == first && !binding.Second.IsEmpty) {
					return true;
				}
			}
			return false;
		}

		internal EditorKeyMap Clone() {
			EditorKeyMap clone = new(bindings);
			foreach (KeyValuePair<int, EditorCommandHandler> kv in hostCommandHandlers) {
				clone.hostCommandHandlers[kv.Key] = kv.Value;
			}
			clone.nextCustomCommandId = nextCustomCommandId;
			return clone;
		}

		public static EditorKeyMap DefaultKeyMap() => Vscode();

		public static EditorKeyMap Vscode() {
			EditorKeyMap map = new();

			static KeyChord Chord(KeyModifier modifiers, int keyCode) => new(modifiers, keyCode);

			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.LEFT), EditorBuiltinCommand.CURSOR_LEFT));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.RIGHT), EditorBuiltinCommand.CURSOR_RIGHT));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.UP), EditorBuiltinCommand.CURSOR_UP));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.DOWN), EditorBuiltinCommand.CURSOR_DOWN));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.HOME), EditorBuiltinCommand.CURSOR_LINE_START));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.END), EditorBuiltinCommand.CURSOR_LINE_END));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.PAGE_UP), EditorBuiltinCommand.CURSOR_PAGE_UP));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.PAGE_DOWN), EditorBuiltinCommand.CURSOR_PAGE_DOWN));

			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.LEFT), EditorBuiltinCommand.SELECT_LEFT));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.RIGHT), EditorBuiltinCommand.SELECT_RIGHT));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.UP), EditorBuiltinCommand.SELECT_UP));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.DOWN), EditorBuiltinCommand.SELECT_DOWN));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.HOME), EditorBuiltinCommand.SELECT_LINE_START));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.END), EditorBuiltinCommand.SELECT_LINE_END));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.PAGE_UP), EditorBuiltinCommand.SELECT_PAGE_UP));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.SHIFT, KeyCode.PAGE_DOWN), EditorBuiltinCommand.SELECT_PAGE_DOWN));

			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.BACKSPACE), EditorBuiltinCommand.BACKSPACE));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.DELETE_KEY), EditorBuiltinCommand.DELETE_FORWARD));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.TAB), EditorBuiltinCommand.INSERT_TAB));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.NONE, KeyCode.ENTER), EditorBuiltinCommand.INSERT_NEWLINE));

			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.A), EditorBuiltinCommand.SELECT_ALL));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.C), EditorBuiltinCommand.COPY));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.V), EditorBuiltinCommand.PASTE));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.X), EditorBuiltinCommand.CUT));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.SPACE), EditorBuiltinCommand.TRIGGER_COMPLETION));

			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.A), EditorBuiltinCommand.SELECT_ALL));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.C), EditorBuiltinCommand.COPY));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.V), EditorBuiltinCommand.PASTE));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.X), EditorBuiltinCommand.CUT));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.SPACE), EditorBuiltinCommand.TRIGGER_COMPLETION));

			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.Z), EditorBuiltinCommand.UNDO));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.Y), EditorBuiltinCommand.REDO));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z), EditorBuiltinCommand.REDO));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.Z), EditorBuiltinCommand.UNDO));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.Y), EditorBuiltinCommand.REDO));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z), EditorBuiltinCommand.REDO));

			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL, KeyCode.ENTER), EditorBuiltinCommand.INSERT_LINE_BELOW));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER), EditorBuiltinCommand.INSERT_LINE_ABOVE));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.ALT, KeyCode.UP), EditorBuiltinCommand.MOVE_LINE_UP));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.ALT, KeyCode.DOWN), EditorBuiltinCommand.MOVE_LINE_DOWN));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP), EditorBuiltinCommand.COPY_LINE_UP));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN), EditorBuiltinCommand.COPY_LINE_DOWN));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K), EditorBuiltinCommand.DELETE_LINE));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META, KeyCode.ENTER), EditorBuiltinCommand.INSERT_LINE_BELOW));
			map.AddOrReplace(new KeyBinding(Chord(KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER), EditorBuiltinCommand.INSERT_LINE_ABOVE));

			return map;
		}

		public int RegisterCommand(KeyBinding binding, EditorCommandHandler handler) {
			if (handler == null) {
				return (int)EditorBuiltinCommand.NONE;
			}

			int commandId = binding.Command;
			if (commandId == (int)EditorBuiltinCommand.NONE) {
				commandId = AllocateCustomCommandId();
				binding = binding.WithCommandId(commandId);
			}

			AddOrReplace(binding);
			hostCommandHandlers[commandId] = handler;
			return commandId;
		}

		internal bool TryInvokeHostCommand(SweetEditorControl editor, int commandId) {
			if (editor == null) {
				return false;
			}
			return hostCommandHandlers.TryGetValue(commandId, out EditorCommandHandler? handler) && handler(editor);
		}

		internal static EditorCommandRoute GetCommandRoute(int commandId) {
			EditorBuiltinCommand command = (EditorBuiltinCommand)commandId;
			return command switch {
				EditorBuiltinCommand.COPY => EditorCommandRoute.Host,
				EditorBuiltinCommand.PASTE => EditorCommandRoute.Host,
				EditorBuiltinCommand.CUT => EditorCommandRoute.Host,
				EditorBuiltinCommand.TRIGGER_COMPLETION => EditorCommandRoute.Host,
				_ => EditorCommandRoute.Core,
			};
		}

		internal KeyMapMatch Match(KeyChord incoming, ref KeyChord pendingFirstChord) {
			if (incoming.IsEmpty) {
				return KeyMapMatch.None;
			}

			if (!pendingFirstChord.IsEmpty) {
				KeyChord first = pendingFirstChord;
				pendingFirstChord = KeyChord.Empty;

				if (TryResolve(first, incoming, out int chordedCommandId)) {
					return KeyMapMatch.Command(chordedCommandId);
				}
			}

			if (TryResolve(incoming, out int singleCommandId)) {
				return KeyMapMatch.Command(singleCommandId);
			}

			if (HasSecondChordPrefix(incoming)) {
				pendingFirstChord = incoming;
				return KeyMapMatch.WaitSecondChord();
			}

			return KeyMapMatch.None;
		}

		internal static bool TryFromAvalonia(Key key, KeyModifiers modifiers, out KeyChord chord) {
			int keyCode = ToKeyCode(key);
			if (keyCode == KeyCode.NONE) {
				chord = KeyChord.Empty;
				return false;
			}

			chord = new KeyChord(ToKeyModifier(modifiers), keyCode);
			return true;
		}

		private int AllocateCustomCommandId() {
			while (hostCommandHandlers.ContainsKey(nextCustomCommandId)) {
				nextCustomCommandId++;
			}
			return nextCustomCommandId++;
		}

		private static KeyModifier ToKeyModifier(KeyModifiers modifiers) {
			KeyModifier result = KeyModifier.NONE;
			if ((modifiers & KeyModifiers.Shift) != 0) {
				result |= KeyModifier.SHIFT;
			}
			if ((modifiers & KeyModifiers.Control) != 0) {
				result |= KeyModifier.CTRL;
			}
			if ((modifiers & KeyModifiers.Alt) != 0) {
				result |= KeyModifier.ALT;
			}
			if ((modifiers & KeyModifiers.Meta) != 0) {
				result |= KeyModifier.META;
			}
			return result;
		}

		private static int ToKeyCode(Key key) {
			return key switch {
				Key.Back => KeyCode.BACKSPACE,
				Key.Tab => KeyCode.TAB,
				Key.Enter => KeyCode.ENTER,
				Key.Escape => KeyCode.ESCAPE,
				Key.Space => KeyCode.SPACE,
				Key.PageUp => KeyCode.PAGE_UP,
				Key.PageDown => KeyCode.PAGE_DOWN,
				Key.End => KeyCode.END,
				Key.Home => KeyCode.HOME,
				Key.Left => KeyCode.LEFT,
				Key.Up => KeyCode.UP,
				Key.Right => KeyCode.RIGHT,
				Key.Down => KeyCode.DOWN,
				Key.Delete => KeyCode.DELETE_KEY,
				Key.A => KeyCode.A,
				Key.C => KeyCode.C,
				Key.D => KeyCode.D,
				Key.K => KeyCode.K,
				Key.V => KeyCode.V,
				Key.X => KeyCode.X,
				Key.Y => KeyCode.Y,
				Key.Z => KeyCode.Z,
				_ => KeyCode.NONE,
			};
		}
	}
}
