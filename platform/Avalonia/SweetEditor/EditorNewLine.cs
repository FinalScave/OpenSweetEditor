using System;
using System.Collections.Generic;

namespace SweetEditor {
	public sealed class NewLineAction {
		public string Text { get; }

		public NewLineAction(string text) {
			Text = text;
		}
	}

	public sealed class NewLineContext {
		public int LineNumber { get; }
		public int Column { get; }
		public string LineText { get; }
		public LanguageConfiguration? LanguageConfiguration { get; }
		public IEditorMetadata? EditorMetadata { get; }

		public NewLineContext(
			int lineNumber,
			int column,
			string lineText,
			LanguageConfiguration? languageConfig,
			IEditorMetadata? editorMetadata = null) {
			LineNumber = lineNumber;
			Column = column;
			LineText = lineText;
			LanguageConfiguration = languageConfig;
			EditorMetadata = editorMetadata;
		}
	}

	public interface INewLineActionProvider {
		NewLineAction? ProvideNewLineAction(NewLineContext context);
	}

	internal sealed class NewLineActionProviderManager : IDisposable {
		private readonly SweetEditorControl editor;
		private readonly List<INewLineActionProvider> providers = new();

		public NewLineActionProviderManager(SweetEditorControl editor) {
			this.editor = editor;
		}

		public void AddProvider(INewLineActionProvider provider) {
			if (provider == null) {
				return;
			}
			if (!providers.Contains(provider)) {
				providers.Add(provider);
			}
		}

		public void RemoveProvider(INewLineActionProvider provider) {
			providers.Remove(provider);
		}

		public void Dispose() {
			providers.Clear();
		}

		public NewLineAction? ProvideNewLineAction() {
			var cursor = editor.GetCursorPosition();
			var doc = editor.GetDocument();
			string lineText = doc?.GetLineText(cursor.Line) ?? string.Empty;
			var context = new NewLineContext(
				cursor.Line,
				cursor.Column,
				lineText,
				editor.GetLanguageConfiguration(),
				editor.MetadataInternal);
			foreach (var provider in providers) {
				var action = provider.ProvideNewLineAction(context);
				if (action != null) {
					return action;
				}
			}
			return null;
		}
	}
}
