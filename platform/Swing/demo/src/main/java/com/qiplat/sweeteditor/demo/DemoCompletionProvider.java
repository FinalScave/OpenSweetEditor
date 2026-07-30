package com.qiplat.sweeteditor.demo;

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
 * Demo CompletionProvider — demonstrates both synchronous and asynchronous completion modes.
 * <p>
 * 1) Synchronous: when "." is typed, member completion candidates are returned immediately.
 * 2) Asynchronous: for manual trigger or other scenarios, waits 200ms to simulate an LSP request.
 */
public class DemoCompletionProvider implements CompletionProvider {

    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private static final Set<String> TRIGGER_CHARS = new HashSet<>(Arrays.asList(".", ":"));

    @Override
    public boolean isTriggerCharacter(String ch) {
        return TRIGGER_CHARS.contains(ch);
    }

    @Override
    public void provideCompletions(CompletionContext context, CompletionReceiver receiver) {
        System.out.println("[DemoCompletionProvider] provideCompletions: kind=" + context.triggerKind
                + " trigger='" + context.triggerCharacter + "'"
                + " cursor=" + context.cursorPosition.line + ":" + context.cursorPosition.column);

        if (context.triggerKind == CompletionContext.TriggerKind.CHARACTER
                && ".".equals(context.triggerCharacter)) {
            // -- Synchronous push: member completion --
            List<CompletionItem> items = Arrays.asList(
                    new CompletionItem() {{
                        label = "length";
                        detail = "size_t";
                        kind = CompletionItem.KIND_PROPERTY;
                        insertText = "length()";
                        sortKey = "a_length";
                    }},
                    new CompletionItem() {{
                        label = "push_back";
                        detail = "void push_back(T)";
                        kind = CompletionItem.KIND_FUNCTION;
                        insertText = "push_back()";
                        sortKey = "b_push_back";
                    }},
                    new CompletionItem() {{
                        label = "begin";
                        detail = "iterator";
                        kind = CompletionItem.KIND_FUNCTION;
                        insertText = "begin()";
                        sortKey = "c_begin";
                    }},
                    new CompletionItem() {{
                        label = "end";
                        detail = "iterator";
                        kind = CompletionItem.KIND_FUNCTION;
                        insertText = "end()";
                        sortKey = "d_end";
                    }},
                    new CompletionItem() {{
                        label = "size";
                        detail = "size_t";
                        kind = CompletionItem.KIND_FUNCTION;
                        insertText = "size()";
                        sortKey = "e_size";
                    }}
            );
            receiver.accept(new CompletionResult(items, false));
            System.out.println("[DemoCompletionProvider] 同步推送: " + items.size() + " 个成员候选");
            return;
        }

        // -- Asynchronous push: keyword / identifier completion --
        executor.submit(() -> {
            try {
                Thread.sleep(200);
            } catch (InterruptedException ignored) {
            }

            if (receiver.isCancelled()) {
                System.out.println("[DemoCompletionProvider] 异步补全已取消");
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
            System.out.println("[DemoCompletionProvider] 异步推送: " + acceptedItems.size() + " 个关键字/标识符候选（延迟 200ms）");
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
