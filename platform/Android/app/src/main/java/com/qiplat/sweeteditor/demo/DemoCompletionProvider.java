package com.qiplat.sweeteditor.demo;

import android.util.Log;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.completion.CompletionContext;
import com.qiplat.sweeteditor.completion.CompletionItem;
import com.qiplat.sweeteditor.completion.CompletionProvider;
import com.qiplat.sweeteditor.completion.CompletionReceiver;
import com.qiplat.sweeteditor.completion.CompletionResult;
import com.qiplat.sweeteditor.core.foundation.TextEdit;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Demo CompletionProvider — demonstrates synchronous + asynchronous two completion modes.
 *
 * 1) Synchronous: immediately returns member completion candidates when "." is typed
 * 2) Asynchronous: manually triggered / other scenarios delay 200ms to simulate LSP request
 */
public class DemoCompletionProvider implements CompletionProvider {

    private static final String TAG = "DemoCompletionProvider";
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private static final Set<String> TRIGGER_CHARS = new HashSet<>(Arrays.asList(".", ":"));

    @Override
    public boolean isTriggerCharacter(@NonNull String ch) {
        return TRIGGER_CHARS.contains(ch);
    }

    @Override
    public void provideCompletions(@NonNull CompletionContext context, @NonNull CompletionReceiver receiver) {
        Log.d(TAG, "provideCompletions: kind=" + context.triggerKind
                + " trigger='" + context.triggerCharacter + "'"
                + " cursor=" + context.cursorPosition.line + ":" + context.cursorPosition.column);

        if (context.triggerKind == CompletionContext.TriggerKind.CHARACTER
                && ".".equals(context.triggerCharacter)) {
            // ── Synchronous push: member completion (simulates prompt after "obj.") ──
            List<CompletionItem> items = Arrays.asList(
                    new CompletionItem() {{ label = "length"; detail = "size_t"; kind = CompletionItem.KIND_PROPERTY; insertText = "length()"; sortKey = "a_length"; }},
                    new CompletionItem() {{ label = "push_back"; detail = "void push_back(T)"; kind = CompletionItem.KIND_FUNCTION; insertText = "push_back()"; sortKey = "b_push_back"; }},
                    new CompletionItem() {{ label = "begin"; detail = "iterator"; kind = CompletionItem.KIND_FUNCTION; insertText = "begin()"; sortKey = "c_begin"; }},
                    new CompletionItem() {{ label = "end"; detail = "iterator"; kind = CompletionItem.KIND_FUNCTION; insertText = "end()"; sortKey = "d_end"; }},
                    new CompletionItem() {{ label = "size"; detail = "size_t"; kind = CompletionItem.KIND_FUNCTION; insertText = "size()"; sortKey = "e_size"; }}
            );
            receiver.accept(new CompletionResult(items, false));
            Log.d(TAG, "Synchronous push: " + items.size() + " member candidates");
            return;
        }

        // ── Asynchronous push: keyword / identifier completion (simulate LSP delay 200ms) ──
        executor.submit(() -> {
            try {
                Thread.sleep(200);
            } catch (InterruptedException ignored) {
            }

            if (receiver.isCancelled()) {
                Log.d(TAG, "Asynchronous completion cancelled");
                return;
            }

            List<CompletionItem> items = Arrays.asList(
                    new CompletionItem() {{
                        label = "std::string";
                        detail = "class";
                        kind = CompletionItem.KIND_CLASS;
                        insertText = "std::string";
                        sortKey = "a_string";
                    }},
                    new CompletionItem() {{
                        label = "std::vector";
                        detail = "template class";
                        kind = CompletionItem.KIND_CLASS;
                        insertText = "std::vector<>";
                        sortKey = "b_vector";
                    }},
                    new CompletionItem() {{
                        label = "std::cout";
                        detail = "ostream";
                        kind = CompletionItem.KIND_VARIABLE;
                        insertText = "std::cout";
                        sortKey = "c_cout";
                    }},
                    new CompletionItem() {{
                        label = "if";
                        detail = "snippet";
                        kind = CompletionItem.KIND_SNIPPET;
                        insertText = "if (${1:condition}) {\n\t$0\n}";
                        insertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
                        sortKey = "d_if";
                    }},
                    new CompletionItem() {{
                        label = "for";
                        detail = "snippet";
                        kind = CompletionItem.KIND_SNIPPET;
                        insertText = "for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i}) {\n\t$0\n}";
                        insertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
                        sortKey = "e_for";
                    }},
                    new CompletionItem() {{
                        label = "class";
                        detail = "snippet — class definition";
                        kind = CompletionItem.KIND_SNIPPET;
                        insertText = "class ${1:ClassName} {\npublic:\n\t${1:ClassName}() {$2}\n\t~${1:ClassName}() {$3}\n$0\n};";
                        insertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
                        sortKey = "f_class";
                    }},
                    new CompletionItem() {{
                        label = "return";
                        detail = "keyword";
                        kind = CompletionItem.KIND_KEYWORD;
                        insertText = "return ";
                        sortKey = "g_return";
                    }}
            );

            List<CompletionItem> acceptedItems = new ArrayList<>();

            TextRange replacementRange = getIdentifierRange(context);
            String pattern = replacementRange == null
                    ? ""
                    : context.lineText.substring(replacementRange.start.column, context.cursorPosition.column);
            for (CompletionItem item : items) {
                if (pattern.isEmpty()) {
                    break;
                }

                if (item.label.startsWith(pattern) || item.insertText.startsWith(pattern)) {
                    item.textEdit = new TextEdit(replacementRange, item.insertText);
                    acceptedItems.add(item);
                }
            }

            receiver.accept(new CompletionResult(Collections.unmodifiableList(acceptedItems), false));
            Log.d(TAG, "Asynchronous push: " + items.size() + " keyword/identifier candidates (200ms delay)");
        });
    }

    private static TextRange getIdentifierRange(CompletionContext context) {
        TextRange range = context.wordRange;
        int line = context.cursorPosition.line;
        int cursorColumn = context.cursorPosition.column;
        int startColumn = range.start.column;
        int endColumn = range.end.column;
        if (range.start.line != line || range.end.line != line
                || startColumn < 0 || startColumn >= endColumn
                || cursorColumn < startColumn || cursorColumn > endColumn
                || endColumn > context.lineText.length()) {
            return null;
        }
        for (int column = startColumn; column < endColumn; column++) {
            if (!isWordChar(context.lineText.charAt(column))) {
                return null;
            }
        }
        return range;
    }

    private static boolean isWordChar(char ch) {
        return (ch >= 'a' && ch <= 'z')
                || (ch >= 'A' && ch <= 'Z')
                || (ch >= '0' && ch <= '9')
                || ch == '_'
                || ch > 0x7F;
    }
}
