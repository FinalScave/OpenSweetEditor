# IME Regression Matrix

This matrix is the shared acceptance checklist for SweetEditor IME behavior. It complements the [platform implementation standard](platform-implementation-standard.md): core tests verify protocol semantics, while platform adapters must still verify the native event sequences they receive from each OS IME.

## Protocol Invariants

- Native IME events enter core through exactly one semantic path per update: `ImeCommandMessage` for command-style operations, or `ImeTextUpdateMessage` for native text-window snapshots and patches.
- `ImeMarkedRangeRole::PREEDIT` only represents real editable platform composition / marked / preedit text.
- `ImeMarkedRangeRole::SYSTEM_MARK` only represents platform candidate, correction, highlight, or current-word target ranges.
- Surrounding text requests, candidate context requests, cursor-rectangle requests, keyboard language, and cursor movement into a word do not create editor preedit.
- Document ranges use document coordinates. Input-context and text-update offsets are relative to the related `documentStartOffset`.
- Every non-null `EditorActionResult` returned by an IME handler is dispatched once through the platform's unified result dispatcher.
- Read-only mode blocks text mutation and finishes or cancels any active platform composition; it is not implemented by disabling system IME support.

## Coverage Labels

| Label | Meaning |
|---|---|
| Core automated | Covered by core regression tests under `tests/core/editor` or C API smoke tests |
| Platform acceptance | Must be verified through the platform adapter's native IME path, manually or through platform automation |
| Trace evidence | Native before/after event evidence is useful when the platform has known event-order differences |

## Semantic Matrix

| ID | Scenario | Native signal | Core path | Expected behavior | Required coverage |
|---|---|---|---|---|---|
| IME-01 | Plain text commit | Direct text input or `commitText` equivalent | `COMMIT_TEXT` command or text-update insert | Text is inserted once at the reported selection; no preedit or system mark remains unless reported by the platform | Core automated, platform acceptance |
| IME-02 | Visible preedit lifecycle | Platform declares composing / marked / preedit text | `SET_PREEDIT_TEXT`, marked range command, or text-update preedit | Visible IME composition range follows platform text and selection; updates replace the previous preedit range | Core automated, platform acceptance |
| IME-03 | Commit active preedit | Platform commits while preedit is active | `COMMIT_TEXT` or text-update commit/clear | Commit replaces the active preedit exactly once, clears visible preedit, and leaves the cursor at the platform-reported position | Core automated, platform acceptance |
| IME-04 | Finish or cancel composition | Native finish/cancel event | finish/cancel command or text-update clear | Platform composition is ended without stale preedit rendering or stale system mark state | Core automated, platform acceptance |
| IME-05 | Text-window snapshot replacement | Native full editing value or surrounding text window changes | `ImeTextUpdateMessage` snapshot or patch | Replacement is resolved relative to `documentStartOffset`; stale context requests resynchronization instead of corrupting document text | Core automated, platform acceptance |
| IME-06 | Candidate commit then delete to empty | Type `hello`, accept the candidate, then repeatedly delete | Command or text-update, depending on platform | Text transitions `hello` -> `hell` -> `hel` -> `he` -> `h` -> empty; delete never only moves the cursor, never reinserts prefix text, and never leaves an undeletable character | Core automated, platform acceptance, trace evidence on regressions |
| IME-07 | Candidate replaces system-marked word | Click `enabled`, accept `enables` | `SYSTEM_MARK` plus later commit or text-update replacement | Only the target word changes, for example `boolean enabled()` -> `boolean enables()`; it must never become `booleaenables()`, duplicate prefixes/suffixes/parentheses, or leave stale highlights | Core automated, platform acceptance, trace evidence on regressions |
| IME-08 | Single-character candidate replacement | Candidate replaces a system-marked range with one character | Commit or text-update replacement over `SYSTEM_MARK` | Replacement consumes the intended range once and clears the mark when the platform reports it finished | Core automated |
| IME-09 | Word-middle input and candidate update | Cursor is inside a word when composition or candidate replacement starts | Command or text-update with explicit range/context | Core resolves the target range without assuming the cursor is at the word end; prefix and suffix text remain correct | Core automated, platform acceptance |
| IME-10 | Deletion over preedit or system mark | Backspace/delete while a marked range exists | delete command or text-update deletion | Preedit shrinks or is replaced according to the platform event; system mark guides the target but does not behave as hidden committed text | Core automated, platform acceptance |
| IME-11 | Selection and cursor synchronization | Native IME moves selection or cursor | selection command or text-update selection | Core selection matches the reported coordinate space, and later commits/deletes use that selection instead of stale local state | Core automated, platform acceptance |
| IME-12 | Stale input context | Platform sends an old context id/revision | Command or text-update with stale context | Core requests resynchronization and avoids applying the stale edit as if it targeted current document text | Core automated |
| IME-13 | Candidate context without composition | IME asks for surrounding text, candidate context, or cursor rectangle | Query APIs plus optional `SYSTEM_MARK` only if platform declares a target | No editor preedit is created only because context was requested | Core automated, platform acceptance |
| IME-14 | Read-only transition with active IME | Editor becomes read-only while native composition is active | Platform finish/cancel plus blocked edit command | Active platform composition is ended; later IME edit requests do not mutate the document | Platform acceptance |
| IME-15 | Composition rendering | Active preedit appears in render model | Render model range effects | `PREEDIT` renders as `IME_COMPOSITION`; `SYSTEM_MARK` is not rendered as visible composition underline | Core automated, platform acceptance |
| IME-16 | Undo boundary for composition | Multiple preedit updates followed by commit | Preedit update sequence plus commit | Intermediate preedit updates collapse into the expected undoable edit rather than many committed edits | Core automated |

## Platform Acceptance Matrix

| Platform | Native API surface | Minimum acceptance evidence |
|---|---|---|
| Android | `InputConnection`, extracted text, surrounding text | Verify `setComposingText`, `setComposingRegion`, `commitText`, `deleteSurroundingText`, and `setSelection` across IME-02, IME-06, IME-07, IME-10, and IME-11 |
| Flutter | `TextInputClient`, `TextEditingValue`, text deltas when enabled | Verify snapshot/patch ownership, composing role selection, unified result dispatch, and no stale session/widget state across IME-02, IME-06, IME-07, and IME-11 |
| OHOS | IME Kit | Verify composing/preedit callback ranges and candidate replacement coordinate mapping across IME-02, IME-07, IME-09, and IME-11; capture native evidence for platform keyboards with known candidate quirks |
| Swing | `InputMethodEvent`, `InputMethodRequests` | Verify composed-text segments, committed-character count, candidate context, and cursor rectangles across IME-02, IME-03, IME-10, and IME-13 |
| WinForms | TSF / IMM | Verify composition ranges, committed strings, deletion, and finish/cancel behavior across IME-02, IME-03, IME-04, and IME-10 |
| Apple | `UITextInput` / `NSTextInputClient` | Verify marked text ranges, selected ranges, replacement ranges, and coordinate-space conversion across IME-02, IME-03, IME-09, and IME-11 |

When an IME change is platform-specific, the change record should state which matrix cases were exercised, the OS and keyboard used for manual checks, and whether the adapter entered core through `ImeCommandMessage` or `ImeTextUpdateMessage`.
