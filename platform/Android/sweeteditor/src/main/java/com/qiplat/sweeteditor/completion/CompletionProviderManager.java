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
    private int displayedGeneration = -1;
    private boolean requestActive = false;
    private final List<CompletionItem> mergedItems = new ArrayList<>();

    private CompletionContext.TriggerKind lastTriggerKind = CompletionContext.TriggerKind.INVOKED;
    @Nullable private String lastTriggerChar;
    private final Runnable refreshRunnable = () -> executeRefresh(lastTriggerKind, lastTriggerChar, generation);

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
        invalidate();
        if (providers.isEmpty()) {
            if (listener != null) listener.onCompletionDismissed();
            return;
        }

        requestActive = true;
        lastTriggerKind = triggerKind;
        lastTriggerChar = triggerCharacter;

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
        invalidate();
        if (listener != null) {
            listener.onCompletionDismissed();
        }
    }

    public void invalidate() {
        mainHandler.removeCallbacks(refreshRunnable);
        generation++;
        cancelAllReceivers();
        mergedItems.clear();
        displayedGeneration = -1;
        requestActive = false;
    }

    public boolean isActive() {
        return requestActive;
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
        invalidate();
        requestActive = !items.isEmpty();
        displayedGeneration = requestActive ? generation : -1;
        mergedItems.addAll(items);
        if (listener != null) {
            listener.onCompletionItemsUpdated(Collections.unmodifiableList(new ArrayList<>(mergedItems)));
        }
    }

    public boolean consumeDisplayedGeneration() {
        boolean current = requestActive && displayedGeneration == generation;
        invalidate();
        return current;
    }

    // ==================== Internal Implementation ====================

    private void executeRefresh(@NonNull CompletionContext.TriggerKind triggerKind,
                                @Nullable String triggerCharacter, int requestGeneration) {
        if (!requestActive || requestGeneration != generation) return;
        mergedItems.clear();

        CompletionContext context = buildContext(triggerKind, triggerCharacter);
        if (context == null) {
            dismiss();
            return;
        }

        for (CompletionProvider provider : providers) {
            ManagedReceiver receiver = new ManagedReceiver(requestGeneration);
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
        return new CompletionContext(
                triggerKind,
                triggerCharacter,
                cursor,
                lineText,
                wordRange,
                editor.getLanguageConfiguration(),
                editor.getMetadata());
    }

    private void onProviderResult(@NonNull CompletionResult result, int receiverGeneration) {
        if (!requestActive || receiverGeneration != generation) return;

        mergedItems.addAll(result.items);
        // Sort by sortKey (null values go to the end)
        mergedItems.sort((a, b) -> {
            String sa = a.sortKey != null ? a.sortKey : a.label;
            String sb = b.sortKey != null ? b.sortKey : b.label;
            return sa.compareTo(sb);
        });

        if (mergedItems.isEmpty()) {
            if (listener != null) listener.onCompletionDismissed();
        } else {
            displayedGeneration = generation;
            if (listener != null) {
                listener.onCompletionItemsUpdated(Collections.unmodifiableList(new ArrayList<>(mergedItems)));
            }
        }
    }

    // ==================== ManagedReceiver ====================

    private class ManagedReceiver implements CompletionReceiver {
        private final int receiverGeneration;
        private volatile boolean cancelled = false;

        ManagedReceiver(int receiverGeneration) {
            this.receiverGeneration = receiverGeneration;
        }

        void cancel() {
            cancelled = true;
        }

        @Override
        public boolean accept(@NonNull CompletionResult result) {
            if (cancelled || receiverGeneration != generation) return false;
            mainHandler.post(() -> onProviderResult(result, receiverGeneration));
            return true;
        }

        @Override
        public boolean isCancelled() {
            return cancelled || receiverGeneration != generation;
        }
    }
}
