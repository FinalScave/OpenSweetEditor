package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.completion.CompletionContext;
import com.qiplat.sweeteditor.completion.CompletionItem;
import com.qiplat.sweeteditor.completion.CompletionProvider;
import com.qiplat.sweeteditor.completion.CompletionReceiver;
import com.qiplat.sweeteditor.completion.CompletionResult;

import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Demo CompletionProvider — demonstrates both synchronous and asynchronous completion modes.
 *
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
                    new CompletionItem.Builder("length")
                            .detail("size_t")
                            .kind(CompletionItem.KIND_PROPERTY)
                            .insertText("length()")
                            .sortKey("a_length")
                            .build(),
                    new CompletionItem.Builder("push_back")
                            .detail("void push_back(T)")
                            .kind(CompletionItem.KIND_FUNCTION)
                            .insertText("push_back()")
                            .sortKey("b_push_back")
                            .build(),
                    new CompletionItem.Builder("begin")
                            .detail("iterator")
                            .kind(CompletionItem.KIND_FUNCTION)
                            .insertText("begin()")
                            .sortKey("c_begin")
                            .build(),
                    new CompletionItem.Builder("end")
                            .detail("iterator")
                            .kind(CompletionItem.KIND_FUNCTION)
                            .insertText("end()")
                            .sortKey("d_end")
                            .build(),
                    new CompletionItem.Builder("size")
                            .detail("size_t")
                            .kind(CompletionItem.KIND_FUNCTION)
                            .insertText("size()")
                            .sortKey("e_size")
                            .build()
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
                    new CompletionItem.Builder("std::string")
                            .detail("class")
                            .kind(CompletionItem.KIND_CLASS)
                            .insertText("std::string")
                            .sortKey("a_string")
                            .build(),
                    new CompletionItem.Builder("std::vector")
                            .detail("template class")
                            .kind(CompletionItem.KIND_CLASS)
                            .insertText("std::vector<>")
                            .sortKey("b_vector")
                            .build(),
                    new CompletionItem.Builder("std::cout")
                            .detail("ostream")
                            .kind(CompletionItem.KIND_VARIABLE)
                            .insertText("std::cout")
                            .sortKey("c_cout")
                            .build(),
                    new CompletionItem.Builder("if")
                            .detail("snippet")
                            .kind(CompletionItem.KIND_SNIPPET)
                            .insertText("if (${1:condition}) {\n\t$0\n}")
                            .insertTextFormat(CompletionItem.INSERT_TEXT_FORMAT_SNIPPET)
                            .sortKey("d_if")
                            .build(),
                    new CompletionItem.Builder("for")
                            .detail("snippet")
                            .kind(CompletionItem.KIND_SNIPPET)
                            .insertText("for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i}) {\n\t$0\n}")
                            .insertTextFormat(CompletionItem.INSERT_TEXT_FORMAT_SNIPPET)
                            .sortKey("e_for")
                            .build(),
                    new CompletionItem.Builder("class")
                            .detail("snippet — class definition")
                            .kind(CompletionItem.KIND_SNIPPET)
                            .insertText("class ${1:ClassName} {\npublic:\n\t${1:ClassName}() {$2}\n\t~${1:ClassName}() {$3}\n$0\n};")
                            .insertTextFormat(CompletionItem.INSERT_TEXT_FORMAT_SNIPPET)
                            .sortKey("f_class")
                            .build(),
                    new CompletionItem.Builder("return")
                            .detail("keyword")
                            .kind(CompletionItem.KIND_KEYWORD)
                            .insertText("return ")
                            .sortKey("g_return")
                            .build()
            );
            receiver.accept(new CompletionResult(items, false));
            System.out.println("[DemoCompletionProvider] 异步推送: " + items.size() + " 个关键字/标识符候选（延迟 200ms）");
        });
    }
}
