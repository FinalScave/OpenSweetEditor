# IME Regression Matrix

This matrix is the shared acceptance checklist for SweetEditor IME behavior. It complements the [integration implementation standard](platform-implementation-standard.md): Core tests verify protocol semantics, while integration adapters must still verify the native event sequences produced by each OS IME.

## Protocol Invariants

- A Core session has one fixed `ImeMutationModel`: command adapters submit `ImeCommandBatch`, while Flutter delta input submits `ImeTextUpdateBatch`. A native input connection may sequentially host multiple Core session generations.
- Core is authoritative for document text, selection, composition, history, session lifecycle, and recovery. An adapter keeps only native connection identity and, for `TEXT_UPDATE`, one finite editing-buffer shadow.
- One native callback or Flutter delta list becomes one ordered atomic batch and is dispatched exactly once.
- All IME text offsets use UTF-16 code units and an explicit `ImeCoordinateSpace`. `DOCUMENT`, `EDITING_BUFFER`, `CONTEXT_SLICE`, and `COMPOSITION` offsets are never mixed implicitly.
- Stale session identifiers and stale text-update revisions apply zero mutations. Adapters follow `ImeHostAction` and do not replay, infer, or rewrite rejected input.
- `ImeState` is the authoritative post-operation state. `ImeTextContext` is a read-only finite query and never creates composition.
- Full editing-value snapshots initialize a Flutter connection, rebind a Core session, or perform an explicit synchronization. They are never diffed into mutations; enabled Flutter targets use native deltas and preserve patch identity.
- Missing ranges and selections use the canonical `(-1, -1)` representation. A valid collapsed composition range remains distinct from a missing range.
- Ordinary editor Backspace/Delete uses grapheme semantics. Only the native surrounding-delete command uses its explicit `ImeTextUnit`.
- Read-only transitions close the editable session. External Core actions that change TextUpdate editing state prefer `SYNC_EDITING_STATE` on the existing connection and close or restart only when the current generation cannot continue.

## Coverage Labels

| Label | Meaning |
|---|---|
| Core automated | Covered by Core regression tests under `tests/core/editor` or C API smoke tests |
| Integration acceptance | Must be verified through the integration adapter's native IME path, manually or through target automation |
| Trace evidence | Native before/after event evidence is required when event ordering, rebinding, or candidate behavior differs by target |

## Semantic Matrix

| ID | Scenario | Protocol path | Expected behavior | Required coverage |
|---|---|---|---|---|
| IME-01 | Session lifecycle | Begin, query, mutate, and end one fixed-model session | Session identifiers are nonzero and unique; an ended or replaced session cannot mutate the editor | Core automated, integration acceptance |
| IME-02 | Plain text commit | `COMMIT_TEXT` command or insertion text-update step | Text is inserted once at the authoritative selection and no composition remains unless explicitly reported | Core automated, integration acceptance |
| IME-03 | Begin and update composition | `BEGIN_COMPOSITION` / `UPDATE_COMPOSITION` or delta steps with valid `composition_after` | Provisional text lives in the document, the authoritative composition range follows it, and updates replace it once | Core automated, integration acceptance |
| IME-04 | Commit active composition | Commit command or text-update step clearing composition | The active composition is replaced exactly once, composition becomes absent, and selection matches `ImeState` | Core automated, integration acceptance |
| IME-05 | Finish and cancel | `FINISH_COMPOSITION` or `CANCEL_COMPOSITION` | Finish keeps current text as committed; cancel restores the captured baseline; neither leaves stale composition effects | Core automated, integration acceptance |
| IME-06 | Atomic multi-operation callback | Ordered `ImeCommandBatch` or `ImeTextUpdateBatch` | All steps apply as one transaction and one undo boundary; a rejected step does not leave a partial batch | Core automated |
| IME-07 | Candidate commit then delete | Commit `hello`, then repeatedly delete | Text reaches empty without cursor-only deletion, prefix reinsertion, duplicate text, or an undeletable final character | Core automated, integration acceptance, trace evidence on regressions |
| IME-08 | Candidate replaces text around a word-middle caret | Native API supplies an explicit replacement patch/range | Only the reported target changes; Core and adapter do not infer a word range from text content | Core automated, integration acceptance, trace evidence on regressions |
| IME-09 | Selection direction and affinity | Selection command or non-text delta | Anchor/active direction and collapsed caret affinity round-trip; later mutation uses the returned authoritative selection | Core automated, integration acceptance |
| IME-10 | Collapsed active composition | Valid `(n, n)` composition range | Composition remains active and distinct from canonical missing range until an explicit later transition | Core automated, conditional integration acceptance |
| IME-11 | Stale session or revision | Old session id, or old `expected_state_revision` in a text-update batch | Core returns mismatch/rejection, applies zero mutations, and supplies recovery/host action without adapter replay | Core automated |
| IME-12 | Text-update patch chain | Multiple Flutter deltas in one callback | Each step's `old_text` equals the previous accepted step output; insert/delete/replace identity and list order are preserved | Core automated, Flutter acceptance |
| IME-13 | Snapshot received during an active Flutter session | Text-changing `updateEditingValue` instead of deltas | Adapter treats it as a protocol error, never computes a common-prefix/suffix diff, and safely closes or restarts | Flutter acceptance |
| IME-14 | Finite editing-buffer boundary | Query and delta near either safe boundary | Context remains bounded; unsafe edits request recovery rather than truncating, shifting, or duplicating document text | Core automated, Flutter acceptance |
| IME-15 | Surrounding deletion units | Native `DELETE_SURROUNDING` in UTF-16 or Unicode-code-point units | The exact requested unit is honored; ordinary hardware Backspace/Delete still removes a grapheme | Core automated, integration acceptance |
| IME-16 | Context slices | `getImeContext` for `EDITING`, `COMMITTED`, or `EDITING_BUFFER` | Slice start and total UTF-16 length are correct; selection/composition are returned only when representable in the slice; queries do not mutate state | Core automated, integration acceptance |
| IME-17 | Core-driven synchronization or session end | External edit, selection move, or undo/redo returns Sync for TextUpdate; read-only, document rebind, or protocol recovery returns Close/Restart | Sync preserves the session and writes back the authoritative finite buffer; Close/Restart cleanup is not ended twice and delayed callbacks from the old generation are ignored | Core automated, integration acceptance, trace evidence |
| IME-18 | Rendering and undo | Multi-line composition updates followed by commit/cancel | Composition effect tracks the authoritative range across lines and the full composition lifecycle has the intended single undo boundary | Core automated, integration acceptance |

## Integration Acceptance Matrix

| Implementation | Native API surface | Minimum acceptance evidence |
|---|---|---|
| Android | `InputConnection`, extracted text, surrounding text | Verify composing text/region, commit, selection, both surrounding-delete unit APIs, connection rebinding, candidate replacement, and background/foreground recovery |
| Apple | `UITextInput` / `NSTextInputClient` | Verify marked text, marked-relative and document-relative replacement, selection direction, finish/cancel, geometry, and focus rebinding |
| Swing | `InputMethodEvent`, `InputMethodRequests` | Verify mixed committed/composed segments in one event, committed-text context, selected text, cursor rectangle, cancel, and focus rebinding |
| WinForms | TSF / IMM | Verify composition/result strings, replacement ranges, selection, delete, finish/cancel, focus rebinding, and stale native callbacks |
| Avalonia | `TextInputMethodClient`, immutable input contexts | Verify preedit callbacks, commit, nullable preedit cursor, selection/surrounding cache consistency, context replacement, and Android input-pane lifecycle |
| OHOS | IME Kit | Verify attach/detach ordering, composition, commit, selection, surrounding text/delete, candidate replacement, and background/foreground generation handling |
| Flutter | `DeltaTextInputClient`, `TextEditingDelta` | Verify finite-buffer initialization, insertion/deletion/replacement/non-text deltas, multi-delta atomicity, affinity, candidate commit/delete, snapshot rejection, same-connection synchronization without keyboard relaunch on ordinary taps, and generation isolation for true Close/Restart |

The Web package exports the six Core IME C APIs but does not include a browser input adapter. Browser acceptance belongs to the host adapter that maps composition, `beforeinput`, selection, and lifecycle events into one of the shared session models.

When an IME change is implementation-specific, the change record should state the exercised matrix cases, OS and keyboard, mutation model, native callback sequence, session/revision transitions, and any `ImeHostAction`.
