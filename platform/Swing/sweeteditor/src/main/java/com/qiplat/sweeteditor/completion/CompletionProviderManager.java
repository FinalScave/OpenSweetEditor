package com.qiplat.sweeteditor.completion;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import javax.swing.*;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Completion provider manager (Swing version), reusing Swing Timer debounce + EDT scheduling.
 */
public class CompletionProviderManager {

    private static final int DEBOUNCE_CHARACTER_MS = 50;
    private static final int DEBOUNCE_INVOKED_MS = 0;

    public interface CompletionUpdateListener {
        void onCompletionItemsUpdated(List<CompletionItem> items);
        void onCompletionDismissed();
    }

    private final CopyOnWriteArrayList<CompletionProvider> providers = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<CompletionProvider, ManagedReceiver> activeReceivers = new ConcurrentHashMap<>();
    private final SweetEditor editor;

    private CompletionUpdateListener listener;
    private volatile int generation = 0;
    private final List<CompletionItem> mergedItems = new ArrayList<>();

    private Timer debounceTimer;
    private CompletionContext.TriggerKind lastTriggerKind = CompletionContext.TriggerKind.INVOKED;
    private String lastTriggerChar;

    public CompletionProviderManager(SweetEditor editor) {
        this.editor = editor;
    }

    public void setListener(CompletionUpdateListener listener) {
        this.listener = listener;
    }

    public void addProvider(CompletionProvider provider) {
        providers.addIfAbsent(provider);
    }

    public void removeProvider(CompletionProvider provider) {
        providers.remove(provider);
        ManagedReceiver receiver = activeReceivers.remove(provider);
        if (receiver != null) receiver.cancel();
    }

    public void triggerCompletion(CompletionContext.TriggerKind triggerKind, String triggerCharacter) {
        if (providers.isEmpty()) return;

        lastTriggerKind = triggerKind;
        lastTriggerChar = triggerCharacter;

        if (debounceTimer != null) {
            debounceTimer.stop();
        }
        int delay = triggerKind == CompletionContext.TriggerKind.INVOKED ? DEBOUNCE_INVOKED_MS : DEBOUNCE_CHARACTER_MS;
        debounceTimer = new Timer(delay, e -> executeRefresh(lastTriggerKind, lastTriggerChar));
        debounceTimer.setRepeats(false);
        debounceTimer.start();
    }

    public void dismiss() {
        if (debounceTimer != null) debounceTimer.stop();
        generation++;
        cancelAllReceivers();
        mergedItems.clear();
        if (listener != null) listener.onCompletionDismissed();
    }

    public boolean isTriggerCharacter(String ch) {
        for (CompletionProvider provider : providers) {
            if (provider.isTriggerCharacter(ch)) return true;
        }
        return false;
    }

    public void showItems(List<CompletionItem> items) {
        if (debounceTimer != null) debounceTimer.stop();
        generation++;
        cancelAllReceivers();
        mergedItems.clear();
        mergedItems.addAll(items);
        if (listener != null) {
            listener.onCompletionItemsUpdated(Collections.unmodifiableList(new ArrayList<>(mergedItems)));
        }
    }

    private void executeRefresh(CompletionContext.TriggerKind triggerKind, String triggerCharacter) {
        final int currentGen = ++generation;
        cancelAllReceivers();
        mergedItems.clear();

        CompletionContext context = buildContext(triggerKind, triggerCharacter);
        if (context == null) {
            dismiss();
            return;
        }

        for (CompletionProvider provider : providers) {
            ManagedReceiver receiver = new ManagedReceiver(provider, currentGen);
            activeReceivers.put(provider, receiver);
            try {
                provider.provideCompletions(context, receiver);
            } catch (Exception e) {
                System.err.println("CompletionProvider error: " + e.getMessage());
            }
        }
    }

    private void cancelAllReceivers() {
        for (ManagedReceiver receiver : activeReceivers.values()) {
            receiver.cancel();
        }
        activeReceivers.clear();
    }

    private CompletionContext buildContext(CompletionContext.TriggerKind triggerKind, String triggerCharacter) {
        int[] pos = editor.getCursorPosition();
        if (pos == null) return null;
        TextPosition cursor = new TextPosition();
        cursor.line = pos[0];
        cursor.column = pos[1];

        Document doc = editor.getDocument();
        String lineText = (doc != null) ? doc.getLineText(cursor.line) : "";
        if (lineText == null) lineText = "";

        TextRange wordRange = new TextRange();
        int[] wr = editor.getWordRangeAtCursor();
        wordRange.start = new TextPosition(wr[0], wr[1]);
        wordRange.end = new TextPosition(wr[2], wr[3]);
        return new CompletionContext(triggerKind, triggerCharacter, cursor, lineText, wordRange, editor.getLanguageConfiguration());
    }

    private void onProviderResult(CompletionProvider provider, CompletionResult result, int receiverGeneration) {
        if (receiverGeneration != generation) return;

        mergedItems.addAll(result.items);
        mergedItems.sort((a, b) -> {
            String sa = a.getSortKey() != null ? a.getSortKey() : a.getLabel();
            String sb = b.getSortKey() != null ? b.getSortKey() : b.getLabel();
            return sa.compareTo(sb);
        });

        if (mergedItems.isEmpty()) {
            if (listener != null) listener.onCompletionDismissed();
        } else {
            if (listener != null) {
                listener.onCompletionItemsUpdated(Collections.unmodifiableList(new ArrayList<>(mergedItems)));
            }
        }
    }

    private class ManagedReceiver implements CompletionReceiver {
        private final CompletionProvider provider;
        private final int receiverGeneration;
        private volatile boolean cancelled = false;

        ManagedReceiver(CompletionProvider provider, int receiverGeneration) {
            this.provider = provider;
            this.receiverGeneration = receiverGeneration;
        }

        void cancel() { cancelled = true; }

        @Override
        public boolean accept(CompletionResult result) {
            if (cancelled || receiverGeneration != generation) return false;
            SwingUtilities.invokeLater(() -> onProviderResult(provider, result, receiverGeneration));
            return true;
        }

        @Override
        public boolean isCancelled() {
            return cancelled || receiverGeneration != generation;
        }
    }
}
