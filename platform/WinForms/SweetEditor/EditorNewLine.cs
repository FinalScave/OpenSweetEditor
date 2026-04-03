using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace SweetEditor {
	/// <summary>New-line action result that describes the text to insert after pressing Enter.</summary>
	public sealed class NewLineAction {
		/// <summary>Full text to insert (including line break and indentation).</summary>
		public string Text { get; }
		public NewLineAction(string text) { Text = text; }
	}

	/// <summary>New-line context passed to INewLineActionProvider for indentation calculation.</summary>
	public sealed class NewLineContext {
		/// <summary>Caret line number (0-based).</summary>
		public int LineNumber { get; }
		/// <summary>Caret column (0-based).</summary>
		public int Column { get; }
		/// <summary>Current line text.</summary>
		public string LineText { get; }
		/// <summary>Language configuration (nullable).</summary>
		public LanguageConfiguration? LanguageConfig { get; }
		/// <summary>Editor metadata (nullable).</summary>
		public IEditorMetadata? EditorMetadata { get; }

		public NewLineContext(int lineNumber, int column, string lineText,
							  LanguageConfiguration? languageConfig,
							  IEditorMetadata? editorMetadata = null) {
			LineNumber = lineNumber;
			Column = column;
			LineText = lineText;
			LanguageConfig = languageConfig;
			EditorMetadata = editorMetadata;
		}
	}

	/// <summary>
	/// Smart new-line provider interface.
	/// Implement this interface to customize new-line behavior (smart indentation, comment continuation, bracket expansion, etc.).
	/// Returning null means this provider does not handle the request and it falls through to the next provider in the chain.
	/// </summary>
	public interface INewLineActionProvider {
		NewLineAction? ProvideNewLineAction(NewLineContext context);
	}

	/// <summary>Manages new-line providers as a chain and uses the first provider that returns a non-null result.</summary>
	internal sealed class NewLineActionProviderManager {
		private readonly SweetEditorControl editor;
		private readonly List<INewLineActionProvider> providers = new();

		public NewLineActionProviderManager(SweetEditorControl editor) {
			this.editor = editor;
		}

		public void AddProvider(INewLineActionProvider provider) {
			providers.Add(provider);
		}

		public void RemoveProvider(INewLineActionProvider provider) {
			providers.Remove(provider);
		}

		/// <summary>Iterates all providers and returns the first non-null NewLineAction; returns null if all providers return null.</summary>
		public NewLineAction? ProvideNewLineAction() {
			var cursor = editor.GetCursorPosition();
			var doc = editor.GetDocument();
			string lineText = doc?.GetLineText(cursor.Line) ?? "";
			var context = new NewLineContext(
				cursor.Line,
				cursor.Column,
				lineText,
				editor.GetLanguageConfiguration(),
				editor.Metadata);
			foreach (var provider in providers) {
				var action = provider.ProvideNewLineAction(context);
				if (action != null) return action;
			}
			return null;
		}
	}


}
