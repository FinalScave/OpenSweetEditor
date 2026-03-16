package com.qiplat.sweeteditor.completion;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Completion provider manager, aligned with DecorationProviderManager architecture.
 * <p>Responsibilities: Provider registration/removal, generation + cancel + debounce,
 * building CompletionContext, dispatching requests, merging/sorting/filtering results, driving panel updates.</p>
 */
public class CompletionProviderManager {

    private static final String TAG = "CompletionMgr";
    private static final long DEBOUNCE_CHARACTER_MS = 50;
    private static final long DEBOUNCE_INVOKED_MS = 0;

    public interface CompletionUpdateListener {
        void onCompletionItemsUpdated(@NonNull List<CompletionItem> items);
        void onCompletionDismissed();
    }

    private final CopyOnWriteArrayList<CompletionProvider> providers = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<CompletionProvider, ManagedReceiver> activeReceivers = new ConcurrentHashMap<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final SweetEditor editor;

    @Nullable private CompletionUpdateListener listener;
    private volatile int generation = 0;
    private final List<CompletionItem> mergedItems = new ArrayList<>();

    private CompletionContext.TriggerKind lastTriggerKind = CompletionContext.TriggerKind.INVOKED;
    @Nullable private String lastTriggerChar;
    private final Runnable refreshRunnable = () -> executeRefresh(lastTriggerKind, lastTriggerChar);

    public CompletionProviderManager(@NonNull SweetEditor editor) {
        this.editor = editor;
    }

    public void setListener(@Nullable CompletionUpdateListener listener) {
        this.listener = listener;
    }

    // ==================== Provider Registration/Removal ====================

    public void addProvider(@NonNull CompletionProvider provider) {
        providers.addIfAbsent(provider);
    }

    public void removeProvider(@NonNull CompletionProvider provider) {
        providers.remove(provider);
        ManagedReceiver receiver = activeReceivers.remove(provider);
        if (receiver != null) receiver.cancel();
    }

    // ==================== Trigger Completion ====================

    /**
     * Trigger completion request (with debounce).
     * @param triggerKind trigger kind
     * @param triggerCharacter trigger character (non-null for CHARACTER type)
     */
    public void triggerCompletion(@NonNull CompletionContext.TriggerKind triggerKind,
                                  @Nullable String triggerCharacter) {
        if (providers.isEmpty()) return;

        lastTriggerKind = triggerKind;
        lastTriggerChar = triggerCharacter;

        mainHandler.removeCallbacks(refreshRunnable);
        long delay = triggerKind == CompletionContext.TriggerKind.INVOKED ? DEBOUNCE_INVOKED_MS : DEBOUNCE_CHARACTER_MS;
        if (delay > 0) {
            mainHandler.postDelayed(refreshRunnable, delay);
        } else {
            mainHandler.post(refreshRunnable);
        }
    }

    /**
     * Cancel current completion request and dismiss the panel.
     */
    public void dismiss() {
        mainHandler.removeCallbacks(refreshRunnable);
        generation++;
        cancelAllReceivers();
        mergedItems.clear();
        if (listener != null) {
            listener.onCompletionDismissed();
        }
    }

    /**
     * Check if the input character is a trigger character for any provider.
     */
    public boolean isTriggerCharacter(@NonNull String ch) {
        for (CompletionProvider provider : providers) {
            if (provider.isTriggerCharacter(ch)) return true;
        }
        return false;
    }

    // ==================== Direct Push API ====================

    /**
     * Externally push candidate list directly (bypassing provider flow).
     */
    public void showItems(@NonNull List<CompletionItem> items) {
        mainHandler.removeCallbacks(refreshRunnable);
        generation++;
        cancelAllReceivers();
        mergedItems.clear();
        mergedItems.addAll(items);
        if (listener != null) {
            listener.onCompletionItemsUpdated(Collections.unmodifiableList(new ArrayList<>(mergedItems)));
        }
    }

    // ==================== Internal Implementation ====================

    private void executeRefresh(@NonNull CompletionContext.TriggerKind triggerKind,
                                @Nullable String triggerCharacter) {
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
                Log.e(TAG, "Provider error: " + e.getMessage(), e);
            }
        }
    }

    private void cancelAllReceivers() {
        for (ManagedReceiver receiver : activeReceivers.values()) {
            receiver.cancel();
        }
        activeReceivers.clear();
    }

    @Nullable
    private CompletionContext buildContext(@NonNull CompletionContext.TriggerKind triggerKind,
                                          @Nullable String triggerCharacter) {
        TextPosition cursor = editor.getCursorPosition();
        if (cursor == null) return null;

        Document doc = editor.getDocument();
        String lineText = (doc != null) ? doc.getLineText(cursor.line) : "";
        if (lineText == null) lineText = "";

        TextRange wordRange = editor.getWordRangeAtCursor();
        return new CompletionContext(triggerKind, triggerCharacter, cursor, lineText, wordRange, editor.getLanguageConfiguration());
    }

    private void onProviderResult(@NonNull CompletionProvider provider,
                                  @NonNull CompletionResult result, int receiverGeneration) {
        if (receiverGeneration != generation) return;

        mergedItems.addAll(result.items);
        // Sort by sortKey (null values go to the end)
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

    // ==================== ManagedReceiver ====================

    private class ManagedReceiver implements CompletionReceiver {
        private final CompletionProvider provider;
        private final int receiverGeneration;
        private volatile boolean cancelled = false;

        ManagedReceiver(CompletionProvider provider, int receiverGeneration) {
            this.provider = provider;
            this.receiverGeneration = receiverGeneration;
        }

        void cancel() {
            cancelled = true;
        }

        @Override
        public boolean accept(@NonNull CompletionResult result) {
            if (cancelled || receiverGeneration != generation) return false;
            mainHandler.post(() -> onProviderResult(provider, result, receiverGeneration));
            return true;
        }

        @Override
        public boolean isCancelled() {
            return cancelled || receiverGeneration != generation;
        }
    }
}
