package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.core.adornment.DiagnosticItem;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.decoration.DecorationContext;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationReceiver;
import com.qiplat.sweeteditor.decoration.DecorationResult;
import com.qiplat.sweeteditor.decoration.DecorationType;

import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Demo DecorationProvider — demonstrates synchronous, asynchronous, and progressive delivery modes.
 *
 * 1) Synchronous push for InlayHint + PhantomText (lightweight computation).
 * 2) Asynchronous push for simulated diagnostics (simulated 500ms LSP delay).
 */
public class DemoDecorationProvider implements DecorationProvider {

    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    @Override
    public EnumSet<DecorationType> getCapabilities() {
        return EnumSet.of(
                DecorationType.INLAY_HINT,
                DecorationType.PHANTOM_TEXT,
                DecorationType.DIAGNOSTIC
        );
    }

    @Override
    public void provideDecorations(DecorationContext context, DecorationReceiver receiver) {
        System.out.println("[DemoProvider] provideDecorations: visible="
                + context.visibleStartLine + "-" + context.visibleEndLine);

        // -- Synchronous push: InlayHint + PhantomText --
        Map<Integer, List<InlayHint>> hints = new HashMap<>();
        hints.put(44, Arrays.asList(
                InlayHint.text(15, "level: "),
                InlayHint.text(37, "msg: ")
        ));
        hints.put(45, Collections.singletonList(InlayHint.text(35, "line: ")));
        hints.put(10, Arrays.asList(
                InlayHint.color(30, (int) 0xFF4CAF50),
                InlayHint.color(35, (int) 0xFF2196F3),
                InlayHint.color(40, (int) 0xFFFF9800),
                InlayHint.color(45, (int) 0xFFF44336)
        ));

        Map<Integer, List<PhantomText>> phantoms = new HashMap<>();
        phantoms.put(13, Collections.singletonList(new PhantomText(2, " // end class Logger")));
        phantoms.put(39, Collections.singletonList(new PhantomText(1, " // end tokenize")));
        phantoms.put(48, Collections.singletonList(new PhantomText(1, " // end main")));

        receiver.accept(new DecorationResult.Builder()
                .inlayHints(hints)
                .phantomTexts(phantoms)
                .build());

        System.out.println("[DemoProvider] 同步推送完毕: InlayHint + PhantomText");

        // -- Asynchronous push: simulate LSP diagnostics with 500ms delay --
        executor.submit(() -> {
            try {
                Thread.sleep(500);
            } catch (InterruptedException ignored) {
            }

            if (receiver.isCancelled()) {
                System.out.println("[DemoProvider] 异步 Diagnostic 已取消");
                return;
            }

            Map<Integer, List<DiagnosticItem>> diags = new HashMap<>();
            diags.put(9, Collections.singletonList(new DiagnosticItem(13, 5, 0, 0)));
            diags.put(16, Collections.singletonList(new DiagnosticItem(8, 4, 1, 0)));
            diags.put(22, Collections.singletonList(new DiagnosticItem(4, 3, 3, 0)));
            diags.put(44, Collections.singletonList(new DiagnosticItem(38, 20, 2, 0)));
            diags.put(45, Collections.singletonList(new DiagnosticItem(4, 4, 1, (int) 0xFFFF8C00)));
            diags.put(46, Arrays.asList(
                    new DiagnosticItem(17, 10, 2, 0),
                    new DiagnosticItem(31, 6, 0, 0)
            ));

            receiver.accept(new DecorationResult.Builder()
                    .diagnostics(diags)
                    .build());

            System.out.println("[DemoProvider] 异步推送完毕: Diagnostic（延迟 500ms）");
        });
    }
}
