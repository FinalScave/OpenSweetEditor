package com.qiplat.sweeteditor.demo;

import android.util.Log;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.completion.CompletionContext;
import com.qiplat.sweeteditor.completion.CompletionItem;
import com.qiplat.sweeteditor.completion.CompletionProvider;
import com.qiplat.sweeteditor.completion.CompletionReceiver;
import com.qiplat.sweeteditor.completion.CompletionResult;

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
            Log.d(TAG, "Asynchronous push: " + items.size() + " keyword/identifier candidates (200ms delay)");
        });
    }
}
