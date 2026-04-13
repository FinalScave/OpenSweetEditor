using System;
using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace SweetEditor {
	internal static class ProtocolEncoder {

		#region EditorOptions

		internal static byte[] PackEditorOptions(EditorOptions options) {
			// 4 + 8 + 8 + 4 + 4 + 4 + 8 = 40 bytes
			byte[] payload = new byte[40];
			int offset = 0;
			BitConverter.TryWriteBytes(payload.AsSpan(offset), options.TouchSlop); offset += 4;
			BinaryPrimitives.WriteInt64LittleEndian(payload.AsSpan(offset), options.DoubleTapTimeout); offset += 8;
			BinaryPrimitives.WriteInt64LittleEndian(payload.AsSpan(offset), options.LongPressMs); offset += 8;
			BitConverter.TryWriteBytes(payload.AsSpan(offset), options.FlingFriction); offset += 4;
			BitConverter.TryWriteBytes(payload.AsSpan(offset), options.FlingMinVelocity); offset += 4;
			BitConverter.TryWriteBytes(payload.AsSpan(offset), options.FlingMaxVelocity); offset += 4;
			BinaryPrimitives.WriteUInt64LittleEndian(payload.AsSpan(offset), options.MaxUndoStackSize);
			return payload;
		}

		#endregion

		#region Spans

		internal static byte[] PackBatchTextStyles(IReadOnlyDictionary<uint, TextStyle> stylesById) {
			if (stylesById == null || stylesById.Count == 0) {
				return Array.Empty<byte>();
			}

			var styleIds = new List<uint>(stylesById.Keys);
			styleIds.Sort();
			byte[] payload = new byte[4 + styleIds.Count * 16];
			int offset = 0;
			WriteInt32LE(payload, ref offset, styleIds.Count);
			for (int i = 0; i < styleIds.Count; i++) {
				uint styleId = styleIds[i];
				TextStyle style = stylesById[styleId];
				WriteUInt32LE(payload, ref offset, styleId);
				WriteInt32LE(payload, ref offset, style.Color);
				WriteInt32LE(payload, ref offset, style.BackgroundColor);
				WriteInt32LE(payload, ref offset, style.FontStyle);
			}
			return payload;
		}

		internal static byte[] PackLineSpans(int line, int layer, IList<StyleSpan> spans) {
			int count = spans.Count;
			byte[] payload = new byte[12 + count * 12];
			int offset = 0;
			WriteInt32LE(payload, ref offset, line);
			WriteInt32LE(payload, ref offset, layer);
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				var s = spans[i];
				WriteInt32LE(payload, ref offset, s.Column);
				WriteInt32LE(payload, ref offset, s.Length);
				WriteInt32LE(payload, ref offset, s.StyleId);
			}
			return payload;
		}

		internal static byte[] PackBatchLineSpans(int layer, Dictionary<int, IList<StyleSpan>> spansByLine) {
			int totalSpans = 0;
			foreach (var kv in spansByLine) totalSpans += kv.Value.Count;
			// header: layer(4) + lineCount(4) + per-line: line(4) + spanCount(4) + per-span: col(4)+len(4)+style(4)
			byte[] payload = new byte[8 + spansByLine.Count * 8 + totalSpans * 12];
			int offset = 0;
			WriteInt32LE(payload, ref offset, layer);
			WriteInt32LE(payload, ref offset, spansByLine.Count);
			foreach (var kv in spansByLine) {
				WriteInt32LE(payload, ref offset, kv.Key);
				var spans = kv.Value;
				WriteInt32LE(payload, ref offset, spans.Count);
				for (int i = 0; i < spans.Count; i++) {
					var s = spans[i];
					WriteInt32LE(payload, ref offset, s.Column);
					WriteInt32LE(payload, ref offset, s.Length);
					WriteInt32LE(payload, ref offset, s.StyleId);
				}
			}
			return payload;
		}

		internal static byte[] PackBatchLineSpans(int layer, Dictionary<int, List<StyleSpan>> spansByLine) {
			int totalSpans = 0;
			foreach (var kv in spansByLine) totalSpans += kv.Value.Count;
			byte[] payload = new byte[8 + spansByLine.Count * 8 + totalSpans * 12];
			int offset = 0;
			WriteInt32LE(payload, ref offset, layer);
			WriteInt32LE(payload, ref offset, spansByLine.Count);
			foreach (var kv in spansByLine) {
				WriteInt32LE(payload, ref offset, kv.Key);
				List<StyleSpan> spans = kv.Value;
				WriteInt32LE(payload, ref offset, spans.Count);
				for (int i = 0; i < spans.Count; i++) {
					var s = spans[i];
					WriteInt32LE(payload, ref offset, s.Column);
					WriteInt32LE(payload, ref offset, s.Length);
					WriteInt32LE(payload, ref offset, s.StyleId);
				}
			}
			return payload;
		}

		#endregion

		#region InlayHint

		internal static byte[] PackLineInlayHints(int line, IList<InlayHint> hints) {
			// Compute bytes length
			int count = hints.Count;
			var textBytesArray = new byte[count][];
			int textBlobSize = 0;
			for (int i = 0; i < count; i++) {
				var h = hints[i];
				if (h.Type == InlayType.Text && h.Text != null) {
					var bytes = Encoding.UTF8.GetBytes(h.Text);
					textBytesArray[i] = bytes;
					textBlobSize += bytes.Length;
				}
			}
			// header: line(4) + count(4) + per-hint: type(4)+col(4)+intValue(4)+textLen(4)
			byte[] payload = new byte[8 + count * 16 + textBlobSize];
			int offset = 0;
			WriteInt32LE(payload, ref offset, line);
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				var h = hints[i];
				WriteInt32LE(payload, ref offset, (int)h.Type);
				WriteInt32LE(payload, ref offset, h.Column);
				WriteInt32LE(payload, ref offset, h.IntValue);
				var textBytes = textBytesArray[i];
				if (textBytes != null) {
					WriteInt32LE(payload, ref offset, textBytes.Length);
					Buffer.BlockCopy(textBytes, 0, payload, offset, textBytes.Length);
					offset += textBytes.Length;
				} else {
					WriteInt32LE(payload, ref offset, 0);
				}
			}
			return payload;
		}

		internal static byte[] PackBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) {
			using var ms = new System.IO.MemoryStream();
			using var bw = new System.IO.BinaryWriter(ms);
			bw.Write(hintsByLine.Count);
			foreach (var kv in hintsByLine) {
				byte[] linePayload = PackLineInlayHints(kv.Key, kv.Value);
				bw.Write(linePayload);
			}
			return ms.ToArray();
		}

		internal static byte[] PackBatchLineInlayHints(Dictionary<int, List<InlayHint>> hintsByLine) {
			using var ms = new System.IO.MemoryStream();
			using var bw = new System.IO.BinaryWriter(ms);
			bw.Write(hintsByLine.Count);
			foreach (var kv in hintsByLine) {
				byte[] linePayload = PackLineInlayHints(kv.Key, kv.Value);
				bw.Write(linePayload);
			}
			return ms.ToArray();
		}

		#endregion

		#region PhantomText

		internal static byte[] PackLinePhantomTexts(int line, IList<PhantomText> phantoms) {
			int count = phantoms.Count;
			var textBytesArray = new byte[count][];
			int textBlobSize = 0;
			for (int i = 0; i < count; i++) {
				var bytes = Encoding.UTF8.GetBytes(phantoms[i].Text ?? "");
				textBytesArray[i] = bytes;
				textBlobSize += bytes.Length;
			}
			// header: line(4) + count(4) + per-phantom: col(4)+textLen(4)
			byte[] payload = new byte[8 + count * 8 + textBlobSize];
			int offset = 0;
			WriteInt32LE(payload, ref offset, line);
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				WriteInt32LE(payload, ref offset, phantoms[i].Column);
				var textBytes = textBytesArray[i];
				WriteInt32LE(payload, ref offset, textBytes.Length);
				Buffer.BlockCopy(textBytes, 0, payload, offset, textBytes.Length);
				offset += textBytes.Length;
			}
			return payload;
		}

		internal static byte[] PackBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) {
			using var ms = new System.IO.MemoryStream();
			using var bw = new System.IO.BinaryWriter(ms);
			bw.Write(phantomsByLine.Count);
			foreach (var kv in phantomsByLine) {
				byte[] linePayload = PackLinePhantomTexts(kv.Key, kv.Value);
				bw.Write(linePayload);
			}
			return ms.ToArray();
		}

		internal static byte[] PackBatchLinePhantomTexts(Dictionary<int, List<PhantomText>> phantomsByLine) {
			using var ms = new System.IO.MemoryStream();
			using var bw = new System.IO.BinaryWriter(ms);
			bw.Write(phantomsByLine.Count);
			foreach (var kv in phantomsByLine) {
				byte[] linePayload = PackLinePhantomTexts(kv.Key, kv.Value);
				bw.Write(linePayload);
			}
			return ms.ToArray();
		}

		#endregion

		#region GutterIcon

		internal static byte[] PackLineGutterIcons(int line, IList<GutterIcon> icons) {
			int count = icons.Count;
			byte[] payload = new byte[8 + count * 4];
			int offset = 0;
			WriteInt32LE(payload, ref offset, line);
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				WriteInt32LE(payload, ref offset, icons[i].IconId);
			}
			return payload;
		}

		internal static byte[] PackBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) {
			int totalIcons = 0;
			foreach (var kv in iconsByLine) totalIcons += kv.Value.Count;
			byte[] payload = new byte[4 + iconsByLine.Count * 8 + totalIcons * 4];
			int offset = 0;
			WriteInt32LE(payload, ref offset, iconsByLine.Count);
			foreach (var kv in iconsByLine) {
				WriteInt32LE(payload, ref offset, kv.Key);
				var icons = kv.Value;
				WriteInt32LE(payload, ref offset, icons.Count);
				for (int i = 0; i < icons.Count; i++) {
					WriteInt32LE(payload, ref offset, icons[i].IconId);
				}
			}
			return payload;
		}

		internal static byte[] PackBatchLineGutterIcons(Dictionary<int, List<GutterIcon>> iconsByLine) {
			int totalIcons = 0;
			foreach (var kv in iconsByLine) totalIcons += kv.Value.Count;
			byte[] payload = new byte[4 + iconsByLine.Count * 8 + totalIcons * 4];
			int offset = 0;
			WriteInt32LE(payload, ref offset, iconsByLine.Count);
			foreach (var kv in iconsByLine) {
				WriteInt32LE(payload, ref offset, kv.Key);
				List<GutterIcon> icons = kv.Value;
				WriteInt32LE(payload, ref offset, icons.Count);
				for (int i = 0; i < icons.Count; i++) {
					WriteInt32LE(payload, ref offset, icons[i].IconId);
				}
			}
			return payload;
		}

		#endregion

		#region CodeLens

		internal static byte[] PackLineCodeLens(int line, IList<CodeLensItem> items) {
			CodeLensItem[] orderedItems = NormalizeCodeLensItems(items);
			int count = orderedItems.Length;
			int totalSize = 8;
			byte[][] textBytes = new byte[count][];
			for (int i = 0; i < count; i++) {
				byte[] bytes = Encoding.UTF8.GetBytes(orderedItems[i].Text ?? string.Empty);
				textBytes[i] = bytes;
				totalSize += 12 + bytes.Length;
			}
			byte[] payload = new byte[totalSize];
			int offset = 0;
			WriteInt32LE(payload, ref offset, Math.Max(0, line));
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				WriteInt32LE(payload, ref offset, Math.Max(0, orderedItems[i].Column));
				WriteInt32LE(payload, ref offset, orderedItems[i].CommandId);
				byte[] bytes = textBytes[i];
				WriteInt32LE(payload, ref offset, bytes.Length);
				if (bytes.Length > 0) {
					Buffer.BlockCopy(bytes, 0, payload, offset, bytes.Length);
					offset += bytes.Length;
				}
			}
			return payload;
		}

		internal static byte[] PackBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine) {
			int totalSize = 4;
			var orderedItemsByLine = new Dictionary<int, CodeLensItem[]>(itemsByLine.Count);
			var allTextBytes = new Dictionary<int, byte[][]>(itemsByLine.Count);
			foreach (var kv in itemsByLine) {
				CodeLensItem[] items = NormalizeCodeLensItems(kv.Value);
				orderedItemsByLine[kv.Key] = items;
				totalSize += 8;
				var lineTextBytes = new byte[items.Length][];
				for (int i = 0; i < items.Length; i++) {
					byte[] bytes = Encoding.UTF8.GetBytes(items[i].Text ?? string.Empty);
					lineTextBytes[i] = bytes;
					totalSize += 12 + bytes.Length;
				}
				allTextBytes[kv.Key] = lineTextBytes;
			}
			byte[] payload = new byte[totalSize];
			int offset = 0;
			WriteInt32LE(payload, ref offset, itemsByLine.Count);
			foreach (var kv in itemsByLine) {
				WriteInt32LE(payload, ref offset, Math.Max(0, kv.Key));
				CodeLensItem[] items = orderedItemsByLine[kv.Key];
				WriteInt32LE(payload, ref offset, items.Length);
				byte[][] lineTextBytes = allTextBytes[kv.Key];
				for (int i = 0; i < items.Length; i++) {
					WriteInt32LE(payload, ref offset, Math.Max(0, items[i].Column));
					WriteInt32LE(payload, ref offset, items[i].CommandId);
					byte[] bytes = lineTextBytes[i];
					WriteInt32LE(payload, ref offset, bytes.Length);
					if (bytes.Length > 0) {
						Buffer.BlockCopy(bytes, 0, payload, offset, bytes.Length);
						offset += bytes.Length;
					}
				}
			}
			return payload;
		}

		private static CodeLensItem[] NormalizeCodeLensItems(IList<CodeLensItem> items) {
			var orderedItems = new CodeLensItem[items.Count];
			for (int i = 0; i < items.Count; i++) {
				orderedItems[i] = items[i];
			}

			Array.Sort(orderedItems, static (left, right) => {
				int columnCompare = Math.Max(0, left.Column).CompareTo(Math.Max(0, right.Column));
				return columnCompare != 0
					? columnCompare
					: left.CommandId.CompareTo(right.CommandId);
			});
			return orderedItems;
		}

		#endregion

		#region Diagnostics

		internal static byte[] PackLineDiagnostics<TDiagnostic>(int line, IList<TDiagnostic> items) where TDiagnostic : Diagnostic {
			int count = items.Count;
			byte[] payload = new byte[8 + count * 16];
			int offset = 0;
			WriteInt32LE(payload, ref offset, Math.Max(0, line));
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				var d = items[i];
				WriteInt32LE(payload, ref offset, Math.Max(0, d.Column));
				WriteInt32LE(payload, ref offset, Math.Max(0, d.Length));
				WriteInt32LE(payload, ref offset, Math.Clamp(d.Severity, 0, 3));
				WriteInt32LE(payload, ref offset, d.Color);
			}
			return payload;
		}

		internal static byte[] PackBatchLineDiagnostics<TDiagnostic>(Dictionary<int, IList<TDiagnostic>> diagsByLine) where TDiagnostic : Diagnostic {
			int totalDiags = 0;
			foreach (var kv in diagsByLine) totalDiags += kv.Value.Count;
			byte[] payload = new byte[4 + diagsByLine.Count * 8 + totalDiags * 16];
			int offset = 0;
			WriteInt32LE(payload, ref offset, diagsByLine.Count);
			foreach (var kv in diagsByLine) {
				WriteInt32LE(payload, ref offset, Math.Max(0, kv.Key));
				var items = kv.Value;
				WriteInt32LE(payload, ref offset, items.Count);
				for (int i = 0; i < items.Count; i++) {
					var d = items[i];
					WriteInt32LE(payload, ref offset, Math.Max(0, d.Column));
					WriteInt32LE(payload, ref offset, Math.Max(0, d.Length));
					WriteInt32LE(payload, ref offset, Math.Clamp(d.Severity, 0, 3));
					WriteInt32LE(payload, ref offset, d.Color);
				}
			}
			return payload;
		}

		internal static byte[] PackBatchLineDiagnostics<TDiagnostic>(Dictionary<int, List<TDiagnostic>> diagsByLine) where TDiagnostic : Diagnostic {
			int totalDiags = 0;
			foreach (var kv in diagsByLine) totalDiags += kv.Value.Count;
			byte[] payload = new byte[4 + diagsByLine.Count * 8 + totalDiags * 16];
			int offset = 0;
			WriteInt32LE(payload, ref offset, diagsByLine.Count);
			foreach (var kv in diagsByLine) {
				WriteInt32LE(payload, ref offset, Math.Max(0, kv.Key));
				List<TDiagnostic> items = kv.Value;
				WriteInt32LE(payload, ref offset, items.Count);
				for (int i = 0; i < items.Count; i++) {
					var d = items[i];
					WriteInt32LE(payload, ref offset, Math.Max(0, d.Column));
					WriteInt32LE(payload, ref offset, Math.Max(0, d.Length));
					WriteInt32LE(payload, ref offset, Math.Clamp(d.Severity, 0, 3));
					WriteInt32LE(payload, ref offset, d.Color);
				}
			}
			return payload;
		}

		#endregion

		#region FoldRegions

		internal static byte[] PackFoldRegions(IList<FoldRegion> regions) {
			int count = regions.Count;
			byte[] payload = new byte[4 + count * 8];
			int offset = 0;
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				var r = regions[i];
				WriteInt32LE(payload, ref offset, r.StartLine);
				WriteInt32LE(payload, ref offset, r.EndLine);
			}
			return payload;
		}

		#endregion

		#region Guides

		internal static byte[] PackIndentGuides(IList<IndentGuide> guides) {
			int count = guides.Count;
			byte[] payload = new byte[4 + count * 16];
			int offset = 0;
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				var g = guides[i];
				WriteInt32LE(payload, ref offset, g.Start.Line);
				WriteInt32LE(payload, ref offset, g.Start.Column);
				WriteInt32LE(payload, ref offset, g.End.Line);
				WriteInt32LE(payload, ref offset, g.End.Column);
			}
			return payload;
		}

		internal static byte[] PackBracketGuides(IList<BracketGuide> guides) {
			// BracketGuide: parent(8) + end(8) + childCount(4) + children(8*n)
			int totalChildren = 0;
			for (int i = 0; i < guides.Count; i++) {
				totalChildren += guides[i].Children?.Length ?? 0;
			}
			byte[] payload = new byte[4 + guides.Count * 20 + totalChildren * 8];
			int offset = 0;
			WriteInt32LE(payload, ref offset, guides.Count);
			for (int i = 0; i < guides.Count; i++) {
				var g = guides[i];
				WriteInt32LE(payload, ref offset, g.Parent.Line);
				WriteInt32LE(payload, ref offset, g.Parent.Column);
				WriteInt32LE(payload, ref offset, g.End.Line);
				WriteInt32LE(payload, ref offset, g.End.Column);
				int childCount = g.Children?.Length ?? 0;
				WriteInt32LE(payload, ref offset, childCount);
				for (int c = 0; c < childCount; c++) {
					WriteInt32LE(payload, ref offset, g.Children![c].Line);
					WriteInt32LE(payload, ref offset, g.Children[c].Column);
				}
			}
			return payload;
		}

		internal static byte[] PackFlowGuides(IList<FlowGuide> guides) {
			int count = guides.Count;
			byte[] payload = new byte[4 + count * 16];
			int offset = 0;
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				var g = guides[i];
				WriteInt32LE(payload, ref offset, g.Start.Line);
				WriteInt32LE(payload, ref offset, g.Start.Column);
				WriteInt32LE(payload, ref offset, g.End.Line);
				WriteInt32LE(payload, ref offset, g.End.Column);
			}
			return payload;
		}

		internal static byte[] PackSeparatorGuides(IList<SeparatorGuide> guides) {
			int count = guides.Count;
			byte[] payload = new byte[4 + count * 16];
			int offset = 0;
			WriteInt32LE(payload, ref offset, count);
			for (int i = 0; i < count; i++) {
				var g = guides[i];
				WriteInt32LE(payload, ref offset, g.Line);
				WriteInt32LE(payload, ref offset, g.Style);
				WriteInt32LE(payload, ref offset, g.Count);
				WriteInt32LE(payload, ref offset, g.TextEndColumn);
			}
			return payload;
		}

		#endregion

		internal static byte[] PackLinkedEditingPayload(LinkedEditingModel model) {
			int groupCount = model.Groups.Count;
			int rangeCount = 0;
			var groupTextBytes = new byte[groupCount][];
			int stringBlobSize = 0;
			for (int i = 0; i < groupCount; i++) {
				var group = model.Groups[i];
				rangeCount += group.Ranges.Count;
				if (group.DefaultText != null) {
					byte[] bytes = Encoding.UTF8.GetBytes(group.DefaultText);
					groupTextBytes[i] = bytes;
					stringBlobSize += bytes.Length;
				}
			}

			byte[] payload = new byte[12 + groupCount * 12 + rangeCount * 20 + stringBlobSize];
			int offset = 0;
			WriteInt32LE(payload, ref offset, groupCount);
			WriteInt32LE(payload, ref offset, rangeCount);
			WriteInt32LE(payload, ref offset, stringBlobSize);

			int textOffset = 0;
			for (int i = 0; i < groupCount; i++) {
				var group = model.Groups[i];
				WriteInt32LE(payload, ref offset, group.Index);
				byte[] bytes = groupTextBytes[i];
				if (bytes == null) {
					WriteUInt32LE(payload, ref offset, 0xFFFFFFFFu);
					WriteInt32LE(payload, ref offset, 0);
				} else {
					WriteInt32LE(payload, ref offset, textOffset);
					WriteInt32LE(payload, ref offset, bytes.Length);
					textOffset += bytes.Length;
				}
			}

			for (int groupOrdinal = 0; groupOrdinal < groupCount; groupOrdinal++) {
				var group = model.Groups[groupOrdinal];
				foreach (var range in group.Ranges) {
					WriteInt32LE(payload, ref offset, groupOrdinal);
					WriteInt32LE(payload, ref offset, range.StartLine);
					WriteInt32LE(payload, ref offset, range.StartColumn);
					WriteInt32LE(payload, ref offset, range.EndLine);
					WriteInt32LE(payload, ref offset, range.EndColumn);
				}
			}

			for (int i = 0; i < groupCount; i++) {
				byte[] bytes = groupTextBytes[i];
				if (bytes == null || bytes.Length == 0) {
					continue;
				}
				Buffer.BlockCopy(bytes, 0, payload, offset, bytes.Length);
				offset += bytes.Length;
			}
			return payload;
		}

		private static void WriteInt32LE(byte[] buffer, ref int offset, int value) {
			BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(offset, 4), value);
			offset += 4;
		}

		private static void WriteUInt32LE(byte[] buffer, ref int offset, uint value) {
			BinaryPrimitives.WriteUInt32LittleEndian(buffer.AsSpan(offset, 4), value);
			offset += 4;
		}
	}

	internal static class ProtocolDecoder {
		private readonly record struct ShortAsciiKey(ulong A, ulong B, ulong C, ulong D);
		private static readonly string[] SharedAsciiChars = CreateSharedAsciiChars();
		private static readonly ConcurrentDictionary<ShortAsciiKey, string> SharedShortAsciiStrings = new();
		private static readonly ConcurrentBag<List<VisualLine>> VisualLineListPool = new();
		private static readonly ConcurrentBag<List<VisualRun>> VisualRunListPool = new();
		private static readonly ConcurrentBag<List<GutterIconRenderItem>> GutterIconListPool = new();
		private static readonly ConcurrentBag<List<FoldMarkerRenderItem>> FoldMarkerListPool = new();
		private static readonly ConcurrentBag<List<SelectionRect>> SelectionRectListPool = new();
		private static readonly ConcurrentBag<List<GuideSegment>> GuideSegmentListPool = new();
		private static readonly ConcurrentBag<List<DiagnosticDecoration>> DiagnosticDecorationListPool = new();
		private static readonly ConcurrentBag<List<LinkedEditingRect>> LinkedEditingRectListPool = new();
		private static readonly ConcurrentBag<List<BracketHighlightRect>> BracketHighlightRectListPool = new();
		private static readonly List<VisualLine> EmptyVisualLines = new(0);
		private static readonly List<VisualRun> EmptyVisualRuns = new(0);
		private static readonly List<GutterIconRenderItem> EmptyGutterIcons = new(0);
		private static readonly List<FoldMarkerRenderItem> EmptyFoldMarkers = new(0);
		private static readonly List<SelectionRect> EmptySelectionRects = new(0);
		private static readonly List<GuideSegment> EmptyGuideSegments = new(0);
		private static readonly List<DiagnosticDecoration> EmptyDiagnosticDecorations = new(0);
		private static readonly List<LinkedEditingRect> EmptyLinkedEditingRects = new(0);
		private static readonly List<BracketHighlightRect> EmptyBracketHighlightRects = new(0);
		private const int MaxPooledVisualLineListCapacity = 256;
		private const int MaxPooledVisualRunListCapacity = 512;
		private const int MaxPooledGutterIconListCapacity = 128;
		private const int MaxPooledFoldMarkerListCapacity = 128;
		private const int MaxPooledSelectionRectListCapacity = 128;
		private const int MaxPooledGuideSegmentListCapacity = 256;
		private const int MaxPooledDiagnosticDecorationListCapacity = 256;
		private const int MaxPooledLinkedEditingRectListCapacity = 128;
		private const int MaxPooledBracketHighlightRectListCapacity = 128;

		internal static int GetPayloadLength(IntPtr payloadPtr, UIntPtr payloadSize) {
			if (payloadPtr == IntPtr.Zero) {
				return 0;
			}
			long size64 = checked((long)payloadSize.ToUInt64());
			if (size64 <= 0) {
				NativeMethods.FreeBinaryData(payloadPtr);
				return 0;
			}
			if (size64 > int.MaxValue) {
				NativeMethods.FreeBinaryData(payloadPtr);
				throw new InvalidOperationException($"Binary payload too large: {size64}");
			}
			return (int)size64;
		}

		internal static bool TryReadInt32(ReadOnlySpan<byte> data, ref int offset, out int value) {
			if ((uint)(offset + 4) > (uint)data.Length) {
				value = 0;
				return false;
			}
			value = BinaryPrimitives.ReadInt32LittleEndian(data.Slice(offset, 4));
			offset += 4;
			return true;
		}

		internal static bool TryReadFloat(ReadOnlySpan<byte> data, ref int offset, out float value) {
			if (!TryReadInt32(data, ref offset, out int bits)) {
				value = 0;
				return false;
			}
			value = BitConverter.Int32BitsToSingle(bits);
			return true;
		}

		internal static bool TryReadUtf8String(ReadOnlySpan<byte> data, ref int offset, out string value) {
			value = string.Empty;
			if (!TryReadInt32(data, ref offset, out int len) || len < 0 || (uint)(offset + len) > (uint)data.Length) {
				return false;
			}
			if (len == 0) {
				return true;
			}
			ReadOnlySpan<byte> textBytes = data.Slice(offset, len);
			if (TryGetSharedAsciiString(textBytes, out string shared)) {
				value = shared;
				offset += len;
				return true;
			}
			value = IsAscii(textBytes)
				? Encoding.ASCII.GetString(textBytes)
				: Encoding.UTF8.GetString(textBytes);
			offset += len;
			return true;
		}

		internal static bool TrySkipUtf8String(ReadOnlySpan<byte> data, ref int offset) {
			if (!TryReadInt32(data, ref offset, out int len) || len < 0 || (uint)(offset + len) > (uint)data.Length) {
				return false;
			}
			offset += len;
			return true;
		}

		internal static bool TrySkipBytes(ReadOnlySpan<byte> data, ref int offset, int length) {
			if (length < 0 || (uint)(offset + length) > (uint)data.Length) {
				return false;
			}
			offset += length;
			return true;
		}

		internal static bool TryReadPointF(ReadOnlySpan<byte> data, ref int offset, out PointF point) {
			point = default;
			if (!TryReadFloat(data, ref offset, out float x) ||
				!TryReadFloat(data, ref offset, out float y)) {
				return false;
			}
			point = new PointF(x, y);
			return true;
		}

		internal static bool TryReadTextPosition(ReadOnlySpan<byte> data, ref int offset, out TextPosition position) {
			position = default;
			if (!TryReadInt32(data, ref offset, out int line) ||
				!TryReadInt32(data, ref offset, out int column)) {
				return false;
			}
			position = new TextPosition { Line = line, Column = column };
			return true;
		}

		internal static bool TryReadTextChange(ReadOnlySpan<byte> data, ref int offset, out TextChange change) {
			change = new TextChange();
			if (!TryReadInt32(data, ref offset, out int startLine) ||
				!TryReadInt32(data, ref offset, out int startColumn) ||
				!TryReadInt32(data, ref offset, out int endLine) ||
				!TryReadInt32(data, ref offset, out int endColumn) ||
				!TryReadUtf8String(data, ref offset, out string newText)) {
				return false;
			}
			change.Range = new TextRange {
				Start = new TextPosition { Line = startLine, Column = startColumn },
				End = new TextPosition { Line = endLine, Column = endColumn },
			};
			change.NewText = newText;
			return true;
		}

		internal static GestureType ToGestureType(int value) => value switch {
			>= (int)GestureType.UNDEFINED and <= (int)GestureType.CONTEXT_MENU => (GestureType)value,
			_ => GestureType.UNDEFINED,
		};

		internal static HitTargetType ToHitTargetType(int value) => value switch {
			>= (int)HitTargetType.NONE and <= (int)HitTargetType.CODELENS => (HitTargetType)value,
			_ => HitTargetType.NONE,
		};

		internal static VisualRunType ToVisualRunType(int value) => value switch {
			>= (int)VisualRunType.TEXT and <= (int)VisualRunType.CODELENS => (VisualRunType)value,
			_ => VisualRunType.TEXT,
		};

		internal static VisualLineKind ToVisualLineKind(int value) => value switch {
			>= (int)VisualLineKind.CONTENT and <= (int)VisualLineKind.CODELENS => (VisualLineKind)value,
			_ => VisualLineKind.CONTENT,
		};

		internal static FoldState ToFoldState(int value) => value switch {
			>= (int)FoldState.NONE and <= (int)FoldState.COLLAPSED => (FoldState)value,
			_ => FoldState.NONE,
		};

		internal static CurrentLineRenderMode ToCurrentLineRenderMode(int value) => value switch {
			(int)CurrentLineRenderMode.BACKGROUND => CurrentLineRenderMode.BACKGROUND,
			(int)CurrentLineRenderMode.BORDER => CurrentLineRenderMode.BORDER,
			(int)CurrentLineRenderMode.NONE => CurrentLineRenderMode.NONE,
			_ => CurrentLineRenderMode.BACKGROUND,
		};

		internal static GuideDirection ToGuideDirection(int value) => value switch {
			>= (int)GuideDirection.HORIZONTAL and <= (int)GuideDirection.VERTICAL => (GuideDirection)value,
			_ => GuideDirection.HORIZONTAL,
		};

		internal static GuideType ToGuideType(int value) => value switch {
			>= (int)GuideType.INDENT and <= (int)GuideType.SEPARATOR => (GuideType)value,
			_ => GuideType.INDENT,
		};

		internal static GuideStyle ToGuideStyle(int value) => value switch {
			>= (int)GuideStyle.SOLID and <= (int)GuideStyle.DOUBLE => (GuideStyle)value,
			_ => GuideStyle.SOLID,
		};

		internal static bool TryReadTextStyle(ReadOnlySpan<byte> data, ref int offset, out TextStyle style) {
			style = default;
			if (!TryReadInt32(data, ref offset, out int color) ||
				!TryReadInt32(data, ref offset, out int backgroundColor) ||
				!TryReadInt32(data, ref offset, out int fontStyle)) {
				return false;
			}
			style = new TextStyle(color, backgroundColor, fontStyle);
			return true;
		}

		internal static bool TryReadVisualRun(ReadOnlySpan<byte> data, ref int offset, out VisualRun run) {
			run = default;
			if (!TryReadInt32(data, ref offset, out int typeValue) ||
				!TryReadFloat(data, ref offset, out float x) ||
				!TryReadFloat(data, ref offset, out float y) ||
				!TryReadUtf8String(data, ref offset, out string text) ||
				!TryReadTextStyle(data, ref offset, out TextStyle style) ||
				!TryReadInt32(data, ref offset, out int iconId) ||
				!TryReadInt32(data, ref offset, out int colorValue) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float padding) ||
				!TryReadFloat(data, ref offset, out float margin) ||
				!TryReadInt32(data, ref offset, out int active)) {
				return false;
			}

			run = new VisualRun {
				Type = ToVisualRunType(typeValue),
				X = x,
				Y = y,
				Text = text,
				Style = style,
				IconId = iconId,
				ColorValue = colorValue,
				Width = width,
				Padding = padding,
				Margin = margin,
				Active = active != 0,
			};
			return true;
		}

		internal static bool TryReadVisualLine(ReadOnlySpan<byte> data, ref int offset, out VisualLine line) {
			line = default;
			if (!TryReadInt32(data, ref offset, out int logicalLine) ||
				!TryReadInt32(data, ref offset, out int wrapIndex) ||
				!TryReadPointF(data, ref offset, out PointF lineNumberPosition) ||
				!TryReadInt32(data, ref offset, out int kindValue) ||
				!TryReadInt32(data, ref offset, out int ownsGutterSemanticsValue) ||
				!TryReadInt32(data, ref offset, out int foldStateValue)) {
				return false;
			}
			if (!TryReadInt32(data, ref offset, out int runCount) || runCount < 0) {
				return false;
			}
			List<VisualRun> runs = EmptyVisualRuns;
			if (runCount > 0) {
				runs = RentPooledList(VisualRunListPool, runCount);
				for (int i = 0; i < runCount; i++) {
					if (!TryReadVisualRun(data, ref offset, out VisualRun run)) {
						return false;
					}
					runs.Add(run);
				}
			}
			VisualLineKind kind = ToVisualLineKind(kindValue);
			line = new VisualLine {
				LogicalLine = logicalLine,
				WrapIndex = wrapIndex,
				LineNumberPosition = lineNumberPosition,
				Runs = runs,
				Kind = kind,
				OwnsGutterSemantics = ownsGutterSemanticsValue != 0,
				IsPhantomLine = kind == VisualLineKind.PHANTOM,
				FoldState = ToFoldState(foldStateValue),
			};
			return true;
		}

		internal static bool TryReadGutterIconRenderItem(ReadOnlySpan<byte> data, ref int offset, out GutterIconRenderItem item) {
			item = default;
			if (!TryReadInt32(data, ref offset, out int logicalLine) ||
				!TryReadInt32(data, ref offset, out int iconId) ||
				!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height)) {
				return false;
			}
			item = new GutterIconRenderItem {
				LogicalLine = logicalLine,
				IconId = iconId,
				Origin = origin,
				Width = width,
				Height = height,
			};
			return true;
		}

		internal static bool TryReadFoldMarkerRenderItem(ReadOnlySpan<byte> data, ref int offset, out FoldMarkerRenderItem item) {
			item = default;
			if (!TryReadInt32(data, ref offset, out int logicalLine) ||
				!TryReadInt32(data, ref offset, out int foldStateValue) ||
				!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height)) {
				return false;
			}
			item = new FoldMarkerRenderItem {
				LogicalLine = logicalLine,
				FoldState = ToFoldState(foldStateValue),
				Origin = origin,
				Width = width,
				Height = height,
			};
			return true;
		}

		internal static bool TryReadCursor(ReadOnlySpan<byte> data, ref int offset, out Cursor cursor) {
			cursor = default;
			if (!TryReadTextPosition(data, ref offset, out TextPosition textPosition) ||
				!TryReadPointF(data, ref offset, out PointF position) ||
				!TryReadFloat(data, ref offset, out float height) ||
				!TryReadInt32(data, ref offset, out int visible) ||
				!TryReadInt32(data, ref offset, out int showDragger)) {
				return false;
			}
			cursor = new Cursor {
				TextPosition = textPosition,
				Position = position,
				Height = height,
				Visible = visible != 0,
				ShowDragger = showDragger != 0,
			};
			return true;
		}

		internal static bool TryReadSelectionRect(ReadOnlySpan<byte> data, ref int offset, out SelectionRect rect) {
			rect = default;
			if (!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height)) {
				return false;
			}
			rect = new SelectionRect { Origin = origin, Width = width, Height = height };
			return true;
		}

		internal static bool TryReadSelectionHandle(ReadOnlySpan<byte> data, ref int offset, out SelectionHandle handle) {
			handle = default;
			if (!TryReadPointF(data, ref offset, out PointF position) ||
				!TryReadFloat(data, ref offset, out float height) ||
				!TryReadInt32(data, ref offset, out int visible)) {
				return false;
			}
			handle = new SelectionHandle { Position = position, Height = height, Visible = visible != 0 };
			return true;
		}

		internal static bool TryReadCompositionDecoration(ReadOnlySpan<byte> data, ref int offset, out CompositionDecoration decoration) {
			decoration = default;
			if (!TryReadInt32(data, ref offset, out int active) ||
				!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height)) {
				return false;
			}
			decoration = new CompositionDecoration {
				Active = active != 0,
				Origin = origin,
				Width = width,
				Height = height,
			};
			return true;
		}

		internal static bool TryReadGuideSegment(ReadOnlySpan<byte> data, ref int offset, out GuideSegment segment) {
			segment = default;
			if (!TryReadInt32(data, ref offset, out int directionValue) ||
				!TryReadInt32(data, ref offset, out int typeValue) ||
				!TryReadInt32(data, ref offset, out int styleValue) ||
				!TryReadPointF(data, ref offset, out PointF start) ||
				!TryReadPointF(data, ref offset, out PointF end) ||
				!TryReadInt32(data, ref offset, out int arrowEnd)) {
				return false;
			}
			segment = new GuideSegment {
				Direction = ToGuideDirection(directionValue),
				Type = ToGuideType(typeValue),
				Style = ToGuideStyle(styleValue),
				Start = start,
				End = end,
				ArrowEnd = arrowEnd != 0,
			};
			return true;
		}

		internal static bool TryReadDiagnosticDecoration(ReadOnlySpan<byte> data, ref int offset, out DiagnosticDecoration decoration) {
			decoration = default;
			if (!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height) ||
				!TryReadInt32(data, ref offset, out int severity) ||
				!TryReadInt32(data, ref offset, out int color)) {
				return false;
			}
			decoration = new DiagnosticDecoration {
				Origin = origin,
				Width = width,
				Height = height,
				Severity = severity,
				Color = color,
			};
			return true;
		}

		internal static bool TryReadLinkedEditingRect(ReadOnlySpan<byte> data, ref int offset, out LinkedEditingRect rect) {
			rect = default;
			if (!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height) ||
				!TryReadInt32(data, ref offset, out int isActive)) {
				return false;
			}
			rect = new LinkedEditingRect {
				Origin = origin,
				Width = width,
				Height = height,
				IsActive = isActive != 0,
			};
			return true;
		}

		internal static bool TryReadBracketHighlightRect(ReadOnlySpan<byte> data, ref int offset, out BracketHighlightRect rect) {
			rect = default;
			if (!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height)) {
				return false;
			}
			rect = new BracketHighlightRect { Origin = origin, Width = width, Height = height };
			return true;
		}

		internal static bool TryReadScrollbarRect(ReadOnlySpan<byte> data, ref int offset, out ScrollbarRect rect) {
			rect = default;
			if (!TryReadPointF(data, ref offset, out PointF origin) ||
				!TryReadFloat(data, ref offset, out float width) ||
				!TryReadFloat(data, ref offset, out float height)) {
				return false;
			}
			rect = new ScrollbarRect {
				Origin = origin,
				Width = width,
				Height = height,
			};
			return true;
		}

		internal static bool TryReadScrollbarModel(ReadOnlySpan<byte> data, ref int offset, out ScrollbarModel scrollbar) {
			scrollbar = default;
			if (!TryReadInt32(data, ref offset, out int visible) ||
				!TryReadFloat(data, ref offset, out float alpha) ||
				!TryReadInt32(data, ref offset, out int thumbActive) ||
				!TryReadScrollbarRect(data, ref offset, out ScrollbarRect track) ||
				!TryReadScrollbarRect(data, ref offset, out ScrollbarRect thumb)) {
				return false;
			}
			scrollbar = new ScrollbarModel {
				Visible = visible != 0,
				Alpha = alpha,
				ThumbActive = thumbActive != 0,
				Track = track,
				Thumb = thumb,
			};
			return true;
		}

		internal static EditorRenderModel CreateEmptyRenderModel() {
			return new EditorRenderModel {
				SplitLineVisible = true,
				VisualLines = EmptyVisualLines,
				GutterIcons = EmptyGutterIcons,
				FoldMarkers = EmptyFoldMarkers,
				SelectionRects = EmptySelectionRects,
				GuideSegments = EmptyGuideSegments,
				DiagnosticDecorations = EmptyDiagnosticDecorations,
				LinkedEditingRects = EmptyLinkedEditingRects,
				BracketHighlightRects = EmptyBracketHighlightRects,
				VerticalScrollbar = default,
				HorizontalScrollbar = default,
				GutterSticky = true,
			};
		}

		internal static unsafe EditorRenderModel ParseRenderModel(IntPtr payloadPtr, UIntPtr payloadSize) {
			EditorRenderModel model = CreateEmptyRenderModel();
			int payloadLength = GetPayloadLength(payloadPtr, payloadSize);
			if (payloadLength == 0) {
				return model;
			}
			try {
				ReadOnlySpan<byte> data = new(payloadPtr.ToPointer(), payloadLength);
				int offset = 0;
				if (!TryReadFloat(data, ref offset, out float splitX) ||
					!TryReadInt32(data, ref offset, out int splitLineVisibleRaw) ||
					!TryReadFloat(data, ref offset, out float scrollX) ||
					!TryReadFloat(data, ref offset, out float scrollY) ||
					!TryReadFloat(data, ref offset, out float viewportWidth) ||
					!TryReadFloat(data, ref offset, out float viewportHeight) ||
					!TryReadPointF(data, ref offset, out PointF currentLine) ||
					!TryReadInt32(data, ref offset, out int currentLineRenderModeValue) ||
					!TryReadInt32(data, ref offset, out int lineCount) ||
					lineCount < 0) {
					return model;
				}

				model.SplitX = splitX;
				model.SplitLineVisible = splitLineVisibleRaw != 0;
				model.ScrollX = scrollX;
				model.ScrollY = scrollY;
				model.ViewportWidth = viewportWidth;
				model.ViewportHeight = viewportHeight;
				model.CurrentLine = currentLine;
				model.CurrentLineRenderMode = ToCurrentLineRenderMode(currentLineRenderModeValue);

				if (lineCount > 0) {
					List<VisualLine> lines = RentPooledList(VisualLineListPool, lineCount);
					for (int i = 0; i < lineCount; i++) {
						if (!TryReadVisualLine(data, ref offset, out VisualLine line)) {
							return model;
						}
						lines.Add(line);
					}
					model.VisualLines = lines;
				}

				if (!TryReadInt32(data, ref offset, out int gutterIconCount) || gutterIconCount < 0) {
					return model;
				}
				if (gutterIconCount > 0) {
					List<GutterIconRenderItem> gutterIcons = RentPooledList(GutterIconListPool, gutterIconCount);
					for (int i = 0; i < gutterIconCount; i++) {
						if (!TryReadGutterIconRenderItem(data, ref offset, out GutterIconRenderItem item)) {
							return model;
						}
						gutterIcons.Add(item);
					}
					model.GutterIcons = gutterIcons;
				}

				if (!TryReadInt32(data, ref offset, out int foldMarkerCount) || foldMarkerCount < 0) {
					return model;
				}
				if (foldMarkerCount > 0) {
					List<FoldMarkerRenderItem> foldMarkers = RentPooledList(FoldMarkerListPool, foldMarkerCount);
					for (int i = 0; i < foldMarkerCount; i++) {
						if (!TryReadFoldMarkerRenderItem(data, ref offset, out FoldMarkerRenderItem item)) {
							return model;
						}
						foldMarkers.Add(item);
					}
					model.FoldMarkers = foldMarkers;
				}

				if (!TryReadCursor(data, ref offset, out Cursor cursor) ||
					!TryReadInt32(data, ref offset, out int selectionRectCount) ||
					selectionRectCount < 0) {
					return model;
				}
				model.Cursor = cursor;

				if (selectionRectCount > 0) {
					List<SelectionRect> selectionRects = RentPooledList(SelectionRectListPool, selectionRectCount);
					for (int i = 0; i < selectionRectCount; i++) {
						if (!TryReadSelectionRect(data, ref offset, out SelectionRect rect)) {
							return model;
						}
						selectionRects.Add(rect);
					}
					model.SelectionRects = selectionRects;
				}

				if (!TryReadSelectionHandle(data, ref offset, out SelectionHandle startHandle) ||
					!TryReadSelectionHandle(data, ref offset, out SelectionHandle endHandle) ||
					!TryReadCompositionDecoration(data, ref offset, out CompositionDecoration compositionDecoration) ||
					!TryReadInt32(data, ref offset, out int guideCount) ||
					guideCount < 0) {
					return model;
				}
				model.SelectionStartHandle = startHandle;
				model.SelectionEndHandle = endHandle;
				model.CompositionDecoration = compositionDecoration;

				if (guideCount > 0) {
					List<GuideSegment> guideSegments = RentPooledList(GuideSegmentListPool, guideCount);
					for (int i = 0; i < guideCount; i++) {
						if (!TryReadGuideSegment(data, ref offset, out GuideSegment segment)) {
							return model;
						}
						guideSegments.Add(segment);
					}
					model.GuideSegments = guideSegments;
				}

				if (!TryReadInt32(data, ref offset, out int diagnosticCount) || diagnosticCount < 0) {
					return model;
				}
				if (diagnosticCount > 0) {
					List<DiagnosticDecoration> diagnosticDecorations = RentPooledList(DiagnosticDecorationListPool, diagnosticCount);
					for (int i = 0; i < diagnosticCount; i++) {
						if (!TryReadDiagnosticDecoration(data, ref offset, out DiagnosticDecoration decoration)) {
							return model;
						}
						diagnosticDecorations.Add(decoration);
					}
					model.DiagnosticDecorations = diagnosticDecorations;
				}

				if (!TryReadInt32(data, ref offset, out int maxGutterIcons) ||
					!TryReadInt32(data, ref offset, out int linkedRectCount) ||
					linkedRectCount < 0) {
					return model;
				}
				model.MaxGutterIcons = maxGutterIcons;

				if (linkedRectCount > 0) {
					List<LinkedEditingRect> linkedEditingRects = RentPooledList(LinkedEditingRectListPool, linkedRectCount);
					for (int i = 0; i < linkedRectCount; i++) {
						if (!TryReadLinkedEditingRect(data, ref offset, out LinkedEditingRect rect)) {
							return model;
						}
						linkedEditingRects.Add(rect);
					}
					model.LinkedEditingRects = linkedEditingRects;
				}

				if (!TryReadInt32(data, ref offset, out int bracketRectCount) || bracketRectCount < 0) {
					return model;
				}
				if (bracketRectCount > 0) {
					List<BracketHighlightRect> bracketHighlightRects = RentPooledList(BracketHighlightRectListPool, bracketRectCount);
					for (int i = 0; i < bracketRectCount; i++) {
						if (!TryReadBracketHighlightRect(data, ref offset, out BracketHighlightRect rect)) {
							return model;
						}
						bracketHighlightRects.Add(rect);
					}
					model.BracketHighlightRects = bracketHighlightRects;
				}

				if (offset < data.Length) {
					int savedOffset = offset;
					if (TryReadScrollbarModel(data, ref offset, out ScrollbarModel verticalScrollbar) &&
						TryReadScrollbarModel(data, ref offset, out ScrollbarModel horizontalScrollbar)) {
						model.VerticalScrollbar = verticalScrollbar;
						model.HorizontalScrollbar = horizontalScrollbar;
					} else {
						offset = savedOffset;
					}
				}
				if (TryReadInt32(data, ref offset, out int gutterStickyRaw)) {
					model.GutterSticky = gutterStickyRaw != 0;
				}
				if (TryReadInt32(data, ref offset, out int gutterVisibleRaw)) {
					model.GutterVisible = gutterVisibleRaw != 0;
				}
				return model;
			} finally {
				NativeMethods.FreeBinaryData(payloadPtr);
			}
		}

		private static string[] CreateSharedAsciiChars() {
			var cache = new string[128];
			for (int i = 0; i < cache.Length; i++) {
				cache[i] = ((char)i).ToString();
			}
			return cache;
		}

		private static bool TryGetSharedAsciiString(ReadOnlySpan<byte> bytes, out string value) {
			value = string.Empty;
			if (bytes.Length == 1) {
				byte single = bytes[0];
				if (single < SharedAsciiChars.Length) {
					value = SharedAsciiChars[single];
					return true;
				}
				return false;
			}

			if (bytes.Length <= 0 || bytes.Length > 31) {
				return false;
			}

			ulong a = (ulong)(byte)bytes.Length;
			ulong b = 0UL;
			ulong c = 0UL;
			ulong d = 0UL;
			for (int i = 0; i < bytes.Length; i++) {
				byte current = bytes[i];
				if (current >= 0x80) {
					return false;
				}
				if (i < 7) {
					a |= (ulong)current << ((i + 1) * 8);
				} else if (i < 15) {
					b |= (ulong)current << ((i - 7) * 8);
				} else if (i < 23) {
					c |= (ulong)current << ((i - 15) * 8);
				} else {
					d |= (ulong)current << ((i - 23) * 8);
				}
			}

			var key = new ShortAsciiKey(a, b, c, d);
			if (SharedShortAsciiStrings.TryGetValue(key, out string? cached)) {
				value = cached;
				return true;
			}

			string created = Encoding.ASCII.GetString(bytes);
			if (SharedShortAsciiStrings.Count >= 4096) {
				SharedShortAsciiStrings.Clear();
			}
			SharedShortAsciiStrings.TryAdd(key, created);
			value = created;
			return true;
		}

		private static bool IsAscii(ReadOnlySpan<byte> bytes) {
			for (int i = 0; i < bytes.Length; i++) {
				if (bytes[i] >= 0x80) {
					return false;
				}
			}
			return true;
		}

		internal static void RecycleRenderModel(EditorRenderModel? model) {
			if (!model.HasValue) {
				return;
			}

			RecycleRenderModel(model.Value);
		}

		internal static void RecycleRenderModel(EditorRenderModel model) {
			ReturnVisualLineList(model.VisualLines);
			ReturnPooledList(GutterIconListPool, model.GutterIcons, MaxPooledGutterIconListCapacity, EmptyGutterIcons);
			ReturnPooledList(FoldMarkerListPool, model.FoldMarkers, MaxPooledFoldMarkerListCapacity, EmptyFoldMarkers);
			ReturnPooledList(SelectionRectListPool, model.SelectionRects, MaxPooledSelectionRectListCapacity, EmptySelectionRects);
			ReturnPooledList(GuideSegmentListPool, model.GuideSegments, MaxPooledGuideSegmentListCapacity, EmptyGuideSegments);
			ReturnPooledList(DiagnosticDecorationListPool, model.DiagnosticDecorations, MaxPooledDiagnosticDecorationListCapacity, EmptyDiagnosticDecorations);
			ReturnPooledList(LinkedEditingRectListPool, model.LinkedEditingRects, MaxPooledLinkedEditingRectListCapacity, EmptyLinkedEditingRects);
			ReturnPooledList(BracketHighlightRectListPool, model.BracketHighlightRects, MaxPooledBracketHighlightRectListCapacity, EmptyBracketHighlightRects);
		}

		private static List<T> RentPooledList<T>(ConcurrentBag<List<T>> pool, int capacity) {
			if (pool.TryTake(out List<T>? list)) {
				list.Clear();
				if (list.Capacity < capacity) {
					list.Capacity = capacity;
				}
				return list;
			}

			return new List<T>(capacity);
		}

		internal static List<VisualRun> RentVisualRunList(int capacity) {
			return RentPooledList(VisualRunListPool, capacity);
		}

		internal static void RecycleVisualRunList(List<VisualRun>? runs) {
			ReturnPooledList(VisualRunListPool, runs, MaxPooledVisualRunListCapacity, EmptyVisualRuns);
		}

		private static void ReturnVisualLineList(List<VisualLine>? lines) {
			if (lines == null || ReferenceEquals(lines, EmptyVisualLines)) {
				return;
			}

			for (int i = 0; i < lines.Count; i++) {
				RecycleVisualRunList(lines[i].Runs);
			}

			ReturnPooledList(VisualLineListPool, lines, MaxPooledVisualLineListCapacity, EmptyVisualLines);
		}

		private static void ReturnPooledList<T>(ConcurrentBag<List<T>> pool, List<T>? list, int maxCapacity, List<T> sentinel) {
			if (list == null || ReferenceEquals(list, sentinel)) {
				return;
			}

			list.Clear();
			if (list.Capacity > maxCapacity) {
				return;
			}

			pool.Add(list);
		}

		internal static unsafe TextEditResult ParseTextEditResult(IntPtr payloadPtr, UIntPtr payloadSize) {
			int payloadLength = GetPayloadLength(payloadPtr, payloadSize);
			if (payloadLength == 0) {
				return TextEditResult.Empty;
			}
			try {
				ReadOnlySpan<byte> data = new(payloadPtr.ToPointer(), payloadLength);
				int offset = 0;
				if (!TryReadInt32(data, ref offset, out int changedInt) || changedInt == 0) {
					return TextEditResult.Empty;
				}
				if (!TryReadInt32(data, ref offset, out int count) || count <= 0) {
					return TextEditResult.Empty;
				}

				List<TextChange> changes = new(count);
				for (int i = 0; i < count; i++) {
					if (!TryReadTextChange(data, ref offset, out TextChange change)) {
						break;
					}
					changes.Add(change);
				}
				if (changes.Count == 0) {
					return TextEditResult.Empty;
				}
				return new TextEditResult { Changes = changes };
			} finally {
				NativeMethods.FreeBinaryData(payloadPtr);
			}
		}

		internal static unsafe KeyEventResult ParseKeyEventResult(IntPtr payloadPtr, UIntPtr payloadSize) {
			KeyEventResult result = new();
			int payloadLength = GetPayloadLength(payloadPtr, payloadSize);
			if (payloadLength == 0) {
				return result;
			}
			try {
				ReadOnlySpan<byte> data = new(payloadPtr.ToPointer(), payloadLength);
				int offset = 0;
				if (!TryReadInt32(data, ref offset, out int handled) ||
					!TryReadInt32(data, ref offset, out int contentChanged) ||
					!TryReadInt32(data, ref offset, out int cursorChanged) ||
					!TryReadInt32(data, ref offset, out int selectionChanged) ||
					!TryReadInt32(data, ref offset, out int hasEdit)) {
					return result;
				}

				result.Handled = handled != 0;
				result.ContentChanged = contentChanged != 0;
				result.CursorChanged = cursorChanged != 0;
				result.SelectionChanged = selectionChanged != 0;

				if (hasEdit != 0 && TryReadInt32(data, ref offset, out int count) && count > 0) {
					List<TextChange> changes = new(count);
					for (int i = 0; i < count; i++) {
						if (!TryReadTextChange(data, ref offset, out TextChange change)) {
							break;
						}
						changes.Add(change);
					}
					if (changes.Count > 0) {
						result.EditResult = new TextEditResult { Changes = changes };
					}
				}
				return result;
			} finally {
				NativeMethods.FreeBinaryData(payloadPtr);
			}
		}

		internal static unsafe GestureResult ParseGestureResult(IntPtr payloadPtr, UIntPtr payloadSize) {
			GestureResult result = new();
			int payloadLength = GetPayloadLength(payloadPtr, payloadSize);
			if (payloadLength == 0) {
				return result;
			}
			try {
				ReadOnlySpan<byte> data = new(payloadPtr.ToPointer(), payloadLength);
				int offset = 0;
				if (!TryReadInt32(data, ref offset, out int gestureTypeValue)) {
					return result;
				}
				result.Type = ToGestureType(gestureTypeValue);
				result.TapPoint = new PointF(0, 0);
				switch (result.Type) {
					case GestureType.TAP:
					case GestureType.DOUBLE_TAP:
					case GestureType.LONG_PRESS:
					case GestureType.DRAG_SELECT:
					case GestureType.CONTEXT_MENU:
						if (TryReadFloat(data, ref offset, out float tx) && TryReadFloat(data, ref offset, out float ty)) {
							result.TapPoint = new PointF(tx, ty);
						}
						break;
				}

				if (!TryReadInt32(data, ref offset, out int cursorLine) ||
					!TryReadInt32(data, ref offset, out int cursorColumn) ||
					!TryReadInt32(data, ref offset, out int hasSelectionInt) ||
					!TryReadInt32(data, ref offset, out int selStartLine) ||
					!TryReadInt32(data, ref offset, out int selStartColumn) ||
					!TryReadInt32(data, ref offset, out int selEndLine) ||
					!TryReadInt32(data, ref offset, out int selEndColumn) ||
					!TryReadFloat(data, ref offset, out float viewScrollX) ||
					!TryReadFloat(data, ref offset, out float viewScrollY) ||
					!TryReadFloat(data, ref offset, out float viewScale)) {
					return result;
				}

				result.CursorPosition = new TextPosition { Line = cursorLine, Column = cursorColumn };
				result.HasSelection = hasSelectionInt != 0;
				result.Selection = new TextRange {
					Start = new TextPosition { Line = selStartLine, Column = selStartColumn },
					End = new TextPosition { Line = selEndLine, Column = selEndColumn }
				};
				result.ViewScrollX = viewScrollX;
				result.ViewScrollY = viewScrollY;
				result.ViewScale = viewScale;
				result.HitTarget = new HitTarget { Type = HitTargetType.NONE };

				if (TryReadInt32(data, ref offset, out int hitType) &&
					TryReadInt32(data, ref offset, out int hitLine) &&
					TryReadInt32(data, ref offset, out int hitColumn) &&
					TryReadInt32(data, ref offset, out int hitIconId) &&
					TryReadInt32(data, ref offset, out int hitColor)) {
					result.HitTarget = new HitTarget {
						Type = ToHitTargetType(hitType),
						Line = hitLine,
						Column = hitColumn,
						IconId = hitIconId,
						ColorValue = hitColor
					};
				}
				if (TryReadInt32(data, ref offset, out int needsEdgeScrollInt)) {
					result.NeedsEdgeScroll = needsEdgeScrollInt != 0;
				}
				if (TryReadInt32(data, ref offset, out int needsFlingInt)) {
					result.NeedsFling = needsFlingInt != 0;
				}
				if (TryReadInt32(data, ref offset, out int needsAnimationInt)) {
					result.NeedsAnimation = needsAnimationInt != 0;
				}
				return result;
			} finally {
				NativeMethods.FreeBinaryData(payloadPtr);
			}
		}

		internal static unsafe ScrollMetrics ParseScrollMetrics(IntPtr payloadPtr, UIntPtr payloadSize) {
			ScrollMetrics result = new() { Scale = 1.0f };
			int payloadLength = GetPayloadLength(payloadPtr, payloadSize);
			if (payloadLength == 0) {
				return result;
			}
			try {
				ReadOnlySpan<byte> data = new(payloadPtr.ToPointer(), payloadLength);
				int offset = 0;
				if (!TryReadFloat(data, ref offset, out float scale) ||
					!TryReadFloat(data, ref offset, out float scrollX) ||
					!TryReadFloat(data, ref offset, out float scrollY) ||
					!TryReadFloat(data, ref offset, out float maxScrollX) ||
					!TryReadFloat(data, ref offset, out float maxScrollY) ||
					!TryReadFloat(data, ref offset, out float contentWidth) ||
					!TryReadFloat(data, ref offset, out float contentHeight) ||
					!TryReadFloat(data, ref offset, out float viewportWidth) ||
					!TryReadFloat(data, ref offset, out float viewportHeight) ||
					!TryReadFloat(data, ref offset, out float textAreaX) ||
					!TryReadFloat(data, ref offset, out float textAreaWidth) ||
					!TryReadInt32(data, ref offset, out int canScrollXInt) ||
					!TryReadInt32(data, ref offset, out int canScrollYInt)) {
					return result;
				}

				result.Scale = scale;
				result.ScrollX = scrollX;
				result.ScrollY = scrollY;
				result.MaxScrollX = maxScrollX;
				result.MaxScrollY = maxScrollY;
				result.ContentWidth = contentWidth;
				result.ContentHeight = contentHeight;
				result.ViewportWidth = viewportWidth;
				result.ViewportHeight = viewportHeight;
				result.TextAreaX = textAreaX;
				result.TextAreaWidth = textAreaWidth;
				result.CanScrollXInt = canScrollXInt;
				result.CanScrollYInt = canScrollYInt;
				return result;
			} finally {
				NativeMethods.FreeBinaryData(payloadPtr);
			}
		}

	}
}
