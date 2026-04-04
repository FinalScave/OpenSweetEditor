package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.completion.CompletionContext;
import com.qiplat.sweeteditor.completion.CompletionItem;
import com.qiplat.sweeteditor.completion.CompletionProvider;
import com.qiplat.sweeteditor.completion.CompletionReceiver;
import com.qiplat.sweeteditor.completion.CompletionResult;

import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.stream.Collectors;

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

            Set<CompletionItem> acceptedItems = new HashSet<>();
            StringBuilder stringBuilder = new StringBuilder();

            for (CompletionItem item : items) {
                for (int index = 0; index < item.label.length(); index++) {
                    stringBuilder.append(item.label.charAt(index));
                    if (context.lineText.endsWith(stringBuilder.toString())) {
                        acceptedItems.add(item);
                    }
                }
                stringBuilder.delete(0, stringBuilder.length());
            }


            receiver.accept(new CompletionResult(acceptedItems.stream().toList(), false));
            System.out.println("[DemoCompletionProvider] 异步推送: " + acceptedItems.size() + " 个关键字/标识符候选（延迟 200ms）");
        });
    }
}
