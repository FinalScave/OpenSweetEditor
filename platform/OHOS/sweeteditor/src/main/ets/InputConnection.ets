import { inputMethod } from '@kit.IMEKit';
import hilog from '@ohos.hilog';
import { EditorActionResult } from './core/CoreAction';
import { CaretAffinity } from './core/CoreFoundation';
import {
  ImeCommand,
  ImeCommandBatch,
  ImeCommandKind,
  ImeCoordinateSpace,
  ImeHostAction,
  ImeMutationModel,
  ImeOffsetRange,
  ImeResultCode,
  ImeSelection,
  ImeState,
  ImeTextContext,
  ImeTextSource,
  ImeTextUnit
} from './core/CoreIme';
import { SweetEditor } from './SweetEditor';

const TAG = 'SweetEditor';
const HILOG_DOMAIN = 0x3D12;

function emptyImeState(): ImeState {
  return {
    resultCode: ImeResultCode.OK,
    sessionId: 0,
    stateRevision: 0,
    selection: {
      coordinateSpace: ImeCoordinateSpace.DOCUMENT,
      anchorUtf16: -1,
      activeUtf16: -1,
      affinity: CaretAffinity.DOWNSTREAM
    },
    compositionRange: {
      coordinateSpace: ImeCoordinateSpace.DOCUMENT,
      startUtf16: -1,
      endUtf16: -1
    }
  };
}

export class InputConnection {
  private readonly owner: SweetEditor;
  private readonly controller: inputMethod.InputMethodController = inputMethod.getController();
  private state: ImeState = emptyImeState();
  private lifecycleQueue: Promise<void> = Promise.resolve();
  private lifecycleVersion: number = 0;
  private registered: boolean = false;
  private attached: boolean = false;
  private wantsAttachment: boolean = false;
  private wantsKeyboard: boolean = false;
  private keyboardRecoveryAttempted: boolean = false;
  private keyboardVisible: boolean = false;
  private windowId: number = -1;
  private editorGlobalX: number = 0;
  private editorGlobalY: number = 0;
  private syncScheduled: boolean = false;
  private textSyncPending: boolean = false;
  private cursorSyncPending: boolean = false;

  private readonly onInsertText = (text: string): void => this.commitText(text);
  private readonly onDeleteLeft = (length: number): void => this.deleteSurrounding(length, 0);
  private readonly onDeleteRight = (length: number): void => this.deleteSurrounding(0, length);
  private readonly onMoveCursor = (direction: inputMethod.Direction): void => this.moveCursor(direction, false);
  private readonly onSelectByMovement = (movement: inputMethod.Movement): void => {
    this.moveCursor(movement.direction, true);
  };
  private readonly onSelectByRange = (range: inputMethod.Range): void => this.setSelection(range);
  private readonly onFunctionKey = (functionKey: inputMethod.FunctionKey): void => {
    if (this.isActive()) {
      this.owner.handleInputMethodFunctionKey(functionKey);
    }
  };
  private readonly onExtendAction = (action: inputMethod.ExtendAction): void => this.handleExtendAction(action);
  private readonly onKeyboardStatus = (status: inputMethod.KeyboardStatus): void => {
    if (status === inputMethod.KeyboardStatus.SHOW) {
      this.keyboardVisible = true;
    } else {
      this.keyboardVisible = false;
    }
  };
  private readonly onSetPreviewText = (text: string, range: inputMethod.Range): void => {
    this.updateComposition(text, range);
  };
  private readonly onFinishTextPreview = (): void => this.finishComposition();
  private readonly onGetLeftTextOfCursor = (length: number): string => this.getTextBeforeCursor(length);
  private readonly onGetRightTextOfCursor = (length: number): string => this.getTextAfterCursor(length);
  private readonly onGetTextIndexAtCursor = (): number => this.getTextIndexAtCursor();

  constructor(owner: SweetEditor) {
    this.owner = owner;
  }

  private register(): void {
    if (this.registered) {
      return;
    }
    this.registered = true;
    try {
      this.controller.on('insertText', this.onInsertText);
      this.controller.on('deleteLeft', this.onDeleteLeft);
      this.controller.on('deleteRight', this.onDeleteRight);
      this.controller.on('moveCursor', this.onMoveCursor);
      this.controller.on('selectByMovement', this.onSelectByMovement);
      this.controller.on('selectByRange', this.onSelectByRange);
      this.controller.on('sendFunctionKey', this.onFunctionKey);
      this.controller.on('handleExtendAction', this.onExtendAction);
      this.controller.on('sendKeyboardStatus', this.onKeyboardStatus);
      this.controller.on('setPreviewText', this.onSetPreviewText);
      this.controller.on('finishTextPreview', this.onFinishTextPreview);
      this.controller.on('getLeftTextOfCursor', this.onGetLeftTextOfCursor);
      this.controller.on('getRightTextOfCursor', this.onGetRightTextOfCursor);
      this.controller.on('getTextIndexAtCursor', this.onGetTextIndexAtCursor);
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'register input callbacks failed %{public}s', `${error}`);
      this.unregister();
    }
  }

  dispose(): void {
    this.wantsAttachment = false;
    this.wantsKeyboard = false;
    this.keyboardVisible = false;
    this.lifecycleVersion++;
    this.closeOwnedSession();
    this.enqueueDetach(true);
    this.unregister();
  }

  onFocus(): void {
    if (this.wantsAttachment) {
      this.scheduleAttach();
    }
  }

  onBlur(): void {
    this.wantsAttachment = false;
    this.wantsKeyboard = false;
    this.keyboardVisible = false;
    this.lifecycleVersion++;
    this.closeOwnedSession();
    this.enqueueDetach(true);
  }

  showSoftKeyboard(): void {
    this.wantsAttachment = true;
    this.wantsKeyboard = true;
    this.keyboardRecoveryAttempted = false;
    this.scheduleAttach();
  }

  updateWindowId(windowId: number): void {
    this.windowId = windowId;
    if (this.attached) {
      this.controller.setCallingWindow(windowId).catch(() => {});
    }
  }

  updateEditorOrigin(x: number, y: number): void {
    this.editorGlobalX = x;
    this.editorGlobalY = y;
    this.requestCursorSync();
  }

  requestCursorSync(): void {
    this.scheduleSync(false, true);
  }

  synchronize(result: EditorActionResult): void {
    if (result.imeHostAction !== ImeHostAction.NONE) {
      this.handleHostAction(result.imeHostAction);
      return;
    }

    if (this.isActive()) {
      const next = result.imeState;
      if (next.resultCode !== ImeResultCode.OK || next.sessionId !== this.state.sessionId) {
        this.restartSession();
        return;
      }
      this.state = next;
    }

    const textChanged = result.textChanges.length > 0 || result.cursorChanged || result.selectionChanged ||
      result.compositionChanged;
    const cursorChanged = textChanged || result.scrollChanged || result.scaleChanged;
    this.scheduleSync(textChanged, cursorChanged);
  }

  private unregister(): void {
    if (!this.registered) {
      return;
    }
    try {
      this.controller.off('insertText', this.onInsertText);
      this.controller.off('deleteLeft', this.onDeleteLeft);
      this.controller.off('deleteRight', this.onDeleteRight);
      this.controller.off('moveCursor', this.onMoveCursor);
      this.controller.off('selectByMovement', this.onSelectByMovement);
      this.controller.off('selectByRange', this.onSelectByRange);
      this.controller.off('sendFunctionKey', this.onFunctionKey);
      this.controller.off('handleExtendAction', this.onExtendAction);
      this.controller.off('sendKeyboardStatus', this.onKeyboardStatus);
      this.controller.off('setPreviewText', this.onSetPreviewText);
      this.controller.off('finishTextPreview', this.onFinishTextPreview);
      this.controller.off('getLeftTextOfCursor', this.onGetLeftTextOfCursor);
      this.controller.off('getRightTextOfCursor', this.onGetRightTextOfCursor);
      this.controller.off('getTextIndexAtCursor', this.onGetTextIndexAtCursor);
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'unregister input callbacks failed %{public}s', `${error}`);
    }
    this.registered = false;
  }

  private scheduleAttach(): void {
    const version = this.lifecycleVersion;
    setTimeout(() => {
      if (version === this.lifecycleVersion && this.wantsAttachment) {
        this.enqueueAttach();
      }
    }, 0);
  }

  private enqueueAttach(): void {
    const version = this.lifecycleVersion;
    // Serialize controller operations and discard work queued for an obsolete focus lifecycle.
    this.lifecycleQueue = this.lifecycleQueue.then(async (): Promise<void> => {
      if (version !== this.lifecycleVersion || !this.wantsAttachment) {
        return;
      }
      if (this.attached) {
        if (!this.beginSession()) {
          this.closeBrokenAttachment(true);
          return;
        }
        if (this.wantsKeyboard) {
          try {
            await this.controller.showTextInput(inputMethod.RequestKeyboardReason.TOUCH);
          } catch (error) {
            hilog.error(HILOG_DOMAIN, TAG, 'show input method failed %{public}s', `${error}`);
            await this.recoverFailedKeyboardRequest(version);
            return;
          }
          if (version === this.lifecycleVersion) {
            this.keyboardVisible = true;
            this.wantsKeyboard = false;
          }
        }
        return;
      }

      if (!this.beginSession()) {
        return;
      }
      const textConfig = this.buildTextConfig();
      if (textConfig === null) {
        this.closeOwnedSession();
        return;
      }

      try {
        await this.controller.attach(false, textConfig);
      } catch (error) {
        hilog.error(HILOG_DOMAIN, TAG, 'attach input method failed %{public}s', `${error}`);
        if (version === this.lifecycleVersion) {
          this.closeBrokenAttachment(false);
        }
        return;
      }
      if (version !== this.lifecycleVersion || !this.wantsAttachment) {
        await this.controller.detach().catch(() => {});
        this.attached = false;
        return;
      }
      this.attached = true;
      // Real devices only deliver editor callbacks reliably when registration follows attachment.
      this.unregister();
      this.register();
      if (!this.registered) {
        this.closeBrokenAttachment(false);
        return;
      }
      if (this.windowId >= 0) {
        this.controller.setCallingWindow(this.windowId).catch(() => {});
      }
      if (this.wantsKeyboard) {
        try {
          await this.controller.showTextInput(inputMethod.RequestKeyboardReason.TOUCH);
        } catch (error) {
          hilog.error(HILOG_DOMAIN, TAG, 'show input method failed %{public}s', `${error}`);
          await this.recoverFailedKeyboardRequest(version);
          return;
        }
        if (version !== this.lifecycleVersion) {
          return;
        }
        this.keyboardVisible = true;
        this.wantsKeyboard = false;
      }
      this.scheduleSync(true, true);
    }).catch((error: Error) => {
      hilog.error(HILOG_DOMAIN, TAG, 'input method lifecycle failed %{public}s', `${error}`);
    });
  }

  private enqueueDetach(hideKeyboard: boolean): void {
    this.lifecycleQueue = this.lifecycleQueue.then(async (): Promise<void> => {
      if (hideKeyboard) {
        await this.controller.hideTextInput().catch(() => {});
      }
      await this.controller.detach().catch(() => {});
      this.attached = false;
    }).catch(() => {
      this.attached = false;
    });
  }

  private closeBrokenAttachment(hideKeyboard: boolean): void {
    this.wantsAttachment = false;
    this.wantsKeyboard = false;
    this.keyboardVisible = false;
    this.attached = false;
    this.lifecycleVersion++;
    this.closeOwnedSession();
    this.unregister();
    this.enqueueDetach(hideKeyboard);
  }

  private async recoverFailedKeyboardRequest(version: number): Promise<void> {
    if (version !== this.lifecycleVersion || !this.wantsAttachment) {
      return;
    }
    if (this.keyboardRecoveryAttempted) {
      this.closeBrokenAttachment(false);
      return;
    }
    // A failed show request gets one full detach/attach recovery before the binding is closed.
    this.keyboardRecoveryAttempted = true;
    this.keyboardVisible = false;
    this.attached = false;
    this.closeOwnedSession();
    this.unregister();
    await this.controller.detach().catch(() => {});
    if (version === this.lifecycleVersion && this.wantsAttachment) {
      this.enqueueAttach();
    }
  }

  private beginSession(): boolean {
    if (this.isActive()) {
      return true;
    }
    const core = this.owner.getEditorCore();
    if (core === null) {
      hilog.error(HILOG_DOMAIN, TAG, 'begin IME session failed: editor core is unavailable');
      return false;
    }
    if (core.isReadOnly()) {
      return false;
    }
    const next = core.beginImeSession(ImeMutationModel.COMMAND);
    if (next.resultCode !== ImeResultCode.OK || next.sessionId === 0) {
      hilog.error(HILOG_DOMAIN, TAG, 'begin IME session failed: result=%{public}d session=%{public}d',
        next.resultCode, next.sessionId);
      return false;
    }
    this.state = next;
    return true;
  }

  private closeOwnedSession(): void {
    if (!this.isActive()) {
      return;
    }
    const sessionId = this.state.sessionId;
    this.state = emptyImeState();
    const core = this.owner.getEditorCore();
    if (core !== null) {
      this.owner.dispatchEditorActionResult(core.endImeSession(sessionId));
    }
  }

  private handleHostAction(action: ImeHostAction): void {
    const hadComposition = this.hasComposition();
    this.state = emptyImeState();
    if (action === ImeHostAction.CLOSE_SESSION) {
      this.wantsAttachment = false;
      this.wantsKeyboard = false;
      this.keyboardVisible = false;
      this.lifecycleVersion++;
      this.enqueueDetach(true);
      return;
    }
    this.restartSession(hadComposition);
  }

  private restartSession(resetNativeComposition: boolean = this.hasComposition()): void {
    const shouldReattach = this.wantsAttachment;
    const pendingKeyboardRequest = this.wantsKeyboard;
    const shouldShowKeyboard = this.keyboardVisible || pendingKeyboardRequest;
    this.state = emptyImeState();
    this.wantsAttachment = shouldReattach;
    this.wantsKeyboard = resetNativeComposition ? shouldShowKeyboard : pendingKeyboardRequest;
    const version = ++this.lifecycleVersion;
    if (!resetNativeComposition) {
      setTimeout(() => {
        if (version !== this.lifecycleVersion || !this.wantsAttachment) {
          return;
        }
        if (!this.attached) {
          this.enqueueAttach();
          return;
        }
        if (this.beginSession()) {
          this.scheduleSync(true, true);
        }
      }, 0);
      return;
    }
    this.lifecycleQueue = this.lifecycleQueue.then(async (): Promise<void> => {
      await this.controller.detach().catch(() => {});
      this.attached = false;
      if (version === this.lifecycleVersion && this.wantsAttachment) {
        this.enqueueAttach();
      }
    }).catch(() => {
      this.attached = false;
    });
  }

  private buildTextConfig(): inputMethod.TextConfig | null {
    const context = this.context(ImeTextSource.EDITING, 0, 0);
    if (context === null) {
      return null;
    }
    const selection = this.selectionRange(this.state.selection, context.totalLengthUtf16);
    const config: inputMethod.TextConfig = {
      inputAttribute: {
        textInputType: inputMethod.TextInputType.MULTILINE,
        enterKeyType: inputMethod.EnterKeyType.NONE
      },
      cursorInfo: this.buildCursorInfo(),
      selection: selection
    };
    if (this.windowId >= 0) {
      config.windowId = this.windowId;
    }
    return config;
  }

  private buildCursorInfo(): inputMethod.CursorInfo {
    const rect = this.owner.getCursorRect();
    return {
      left: this.editorGlobalX + rect.x,
      top: this.editorGlobalY + rect.y,
      width: 1,
      height: Math.max(1, rect.height)
    };
  }

  private scheduleSync(text: boolean, cursor: boolean): void {
    if (!this.attached || !this.isActive()) {
      return;
    }
    this.textSyncPending = this.textSyncPending || text;
    this.cursorSyncPending = this.cursorSyncPending || cursor;
    if (this.syncScheduled) {
      return;
    }
    this.syncScheduled = true;
    setTimeout(() => {
      const syncText = this.textSyncPending;
      const syncCursor = this.cursorSyncPending;
      this.textSyncPending = false;
      this.cursorSyncPending = false;
      this.syncScheduled = false;
      this.syncPlatformState(syncText, syncCursor);
    }, 0);
  }

  private syncPlatformState(syncText: boolean, syncCursor: boolean): void {
    if (!this.attached || !this.refreshState()) {
      return;
    }
    const version = this.lifecycleVersion;
    if (syncText) {
      const context = this.context(ImeTextSource.EDITING, 0, -1);
      if (context !== null) {
        const selection = this.selectionRange(context.selection, context.totalLengthUtf16);
        this.controller.changeSelection(context.text, selection.start, selection.end).catch((error: Error) => {
          this.handlePlatformSyncFailure(version, 'changeSelection', error);
        });
      }
    }
    if (version !== this.lifecycleVersion || !this.attached) {
      return;
    }
    if (syncCursor) {
      this.controller.updateCursor(this.buildCursorInfo()).catch((error: Error) => {
        this.handlePlatformSyncFailure(version, 'updateCursor', error);
      });
    }
  }

  private handlePlatformSyncFailure(version: number, operation: string, error: Error): void {
    if (version !== this.lifecycleVersion || !this.attached) {
      return;
    }
    hilog.error(HILOG_DOMAIN, TAG, '%{public}s failed %{public}s', operation, `${error}`);
    this.closeBrokenAttachment(false);
  }

  private apply(commands: ImeCommand[]): void {
    if (!this.isActive() || commands.length === 0) {
      return;
    }
    const core = this.owner.getEditorCore();
    if (core === null) {
      return;
    }
    const batch = new ImeCommandBatch();
    batch.sessionId = this.state.sessionId;
    batch.commands = commands;
    this.owner.finishInputMethodAction(core.applyImeCommands(batch));
  }

  private refreshState(): boolean {
    if (!this.isActive()) {
      return false;
    }
    const core = this.owner.getEditorCore();
    if (core === null) {
      return false;
    }
    const next = core.getImeState(this.state.sessionId);
    if (next.resultCode !== ImeResultCode.OK || next.sessionId !== this.state.sessionId) {
      this.restartSession();
      return false;
    }
    this.state = next;
    return true;
  }

  private context(source: ImeTextSource, start: number, length: number): ImeTextContext | null {
    if (!this.isActive()) {
      return null;
    }
    const core = this.owner.getEditorCore();
    if (core === null) {
      return null;
    }
    const context = core.getImeContext(this.state.sessionId, source, start, length);
    if (context.resultCode !== ImeResultCode.OK) {
      this.restartSession();
      return null;
    }
    return context;
  }

  private commitText(text: string): void {
    const command = new ImeCommand();
    command.kind = ImeCommandKind.COMMIT_TEXT;
    command.text = text;
    this.apply([command]);
  }

  private updateComposition(text: string, range: inputMethod.Range): void {
    if (!this.refreshState()) {
      return;
    }
    const context = this.context(ImeTextSource.EDITING, 0, 0);
    const documentRange = this.normalizedRange(range);
    if (context === null || documentRange === null || documentRange.endUtf16 > context.totalLengthUtf16) {
      return;
    }

    const commands: ImeCommand[] = [];
    const update = new ImeCommand();
    update.kind = ImeCommandKind.UPDATE_COMPOSITION;
    update.text = text;

    if (!this.hasComposition()) {
      update.targetRange = documentRange;
    } else {
      const composition = this.state.compositionRange;
      const isWholeComposition = documentRange.startUtf16 === composition.startUtf16 &&
        documentRange.endUtf16 === composition.endUtf16;
      if (!isWholeComposition) {
        const finish = new ImeCommand();
        finish.kind = ImeCommandKind.FINISH_COMPOSITION;
        commands.push(finish);
        update.targetRange = documentRange;
      }
    }

    commands.push(update);
    this.apply(commands);
  }

  private finishComposition(): void {
    if (!this.refreshState() || !this.hasComposition()) {
      return;
    }
    const command = new ImeCommand();
    command.kind = ImeCommandKind.FINISH_COMPOSITION;
    this.apply([command]);
  }

  private deleteSurrounding(before: number, after: number): void {
    const deleteBefore = Math.max(0, Math.trunc(before));
    const deleteAfter = Math.max(0, Math.trunc(after));
    if (deleteBefore === 0 && deleteAfter === 0) {
      return;
    }
    const command = new ImeCommand();
    command.kind = ImeCommandKind.DELETE_SURROUNDING;
    command.deleteBefore = deleteBefore;
    command.deleteAfter = deleteAfter;
    command.textUnit = ImeTextUnit.UTF16_CODE_UNIT;
    this.apply([command]);
  }

  private moveCursor(direction: inputMethod.Direction, extendSelection: boolean): void {
    if (!this.isActive()) {
      return;
    }
    const core = this.owner.getEditorCore();
    if (core === null) {
      return;
    }
    let result: EditorActionResult | null = null;
    switch (direction) {
      case inputMethod.Direction.CURSOR_LEFT:
        result = core.moveCursorLeft(extendSelection);
        break;
      case inputMethod.Direction.CURSOR_RIGHT:
        result = core.moveCursorRight(extendSelection);
        break;
      case inputMethod.Direction.CURSOR_UP:
        result = core.moveCursorUp(extendSelection);
        break;
      case inputMethod.Direction.CURSOR_DOWN:
        result = core.moveCursorDown(extendSelection);
        break;
      default:
        return;
    }
    this.owner.finishInputMethodAction(result);
  }

  private setSelection(range: inputMethod.Range): void {
    if (!this.refreshState()) {
      return;
    }
    const context = this.context(ImeTextSource.EDITING, 0, 0);
    const documentRange = this.normalizedRange(range);
    if (context === null || documentRange === null || documentRange.endUtf16 > context.totalLengthUtf16) {
      return;
    }
    const command = new ImeCommand();
    command.kind = ImeCommandKind.SET_SELECTION;
    command.selectionAfter = this.selection(ImeCoordinateSpace.DOCUMENT,
      documentRange.startUtf16, documentRange.endUtf16);
    this.apply([command]);
  }

  private handleExtendAction(action: inputMethod.ExtendAction): void {
    if (!this.isActive()) {
      return;
    }
    switch (action) {
      case inputMethod.ExtendAction.SELECT_ALL:
        this.owner.selectAll();
        break;
      case inputMethod.ExtendAction.CUT:
        this.owner.cutToClipboard();
        break;
      case inputMethod.ExtendAction.COPY:
        this.owner.copyToClipboard();
        break;
      case inputMethod.ExtendAction.PASTE:
        this.owner.pasteFromClipboard();
        break;
      default:
        break;
    }
  }

  private getTextBeforeCursor(length: number): string {
    if (!this.refreshState() || !this.hasSelection()) {
      return '';
    }
    const end = Math.min(this.state.selection.anchorUtf16, this.state.selection.activeUtf16);
    const requestedLength = Math.max(0, Math.trunc(length));
    const start = Math.max(0, end - requestedLength);
    const context = this.context(ImeTextSource.EDITING, start, end - start);
    return context === null ? '' : context.text;
  }

  private getTextAfterCursor(length: number): string {
    if (!this.refreshState() || !this.hasSelection()) {
      return '';
    }
    const start = Math.max(this.state.selection.anchorUtf16, this.state.selection.activeUtf16);
    const requestedLength = Math.max(0, Math.trunc(length));
    const context = this.context(ImeTextSource.EDITING, start, requestedLength);
    return context === null ? '' : context.text;
  }

  private getTextIndexAtCursor(): number {
    if (!this.refreshState() || !this.hasSelection()) {
      return 0;
    }
    return this.state.selection.activeUtf16;
  }

  private normalizedRange(range: inputMethod.Range): ImeOffsetRange | null {
    if (!Number.isFinite(range.start) || !Number.isFinite(range.end)) {
      return null;
    }
    const start = Math.trunc(Math.min(range.start, range.end));
    const end = Math.trunc(Math.max(range.start, range.end));
    if (start < 0) {
      return null;
    }
    return this.range(ImeCoordinateSpace.DOCUMENT, start, end);
  }

  private range(coordinateSpace: ImeCoordinateSpace, start: number, end: number): ImeOffsetRange {
    return { coordinateSpace: coordinateSpace, startUtf16: start, endUtf16: end };
  }

  private selection(coordinateSpace: ImeCoordinateSpace, anchor: number, active: number): ImeSelection {
    return {
      coordinateSpace: coordinateSpace,
      anchorUtf16: anchor,
      activeUtf16: active,
      affinity: CaretAffinity.DOWNSTREAM
    };
  }

  private selectionRange(selection: ImeSelection, totalLength: number): inputMethod.Range {
    if (selection.anchorUtf16 < 0 || selection.activeUtf16 < 0) {
      return { start: 0, end: 0 };
    }
    const start = Math.max(0, Math.min(selection.anchorUtf16, selection.activeUtf16, totalLength));
    const end = Math.max(start, Math.min(Math.max(selection.anchorUtf16, selection.activeUtf16), totalLength));
    return { start: start, end: end };
  }

  private isActive(): boolean {
    return this.state.sessionId !== 0;
  }

  private hasSelection(): boolean {
    return this.state.selection.anchorUtf16 >= 0 && this.state.selection.activeUtf16 >= 0;
  }

  private hasComposition(): boolean {
    return this.state.compositionRange.startUtf16 >= 0 && this.state.compositionRange.endUtf16 >= 0;
  }
}
