import { resourceManager } from '@kit.LocalizationKit';
import { ErrorEvent, MessageEvents, util, worker } from '@kit.ArkTS';
import {
  ApplyMode,
  CodeLensItem,
  DecorationContext,
  DecorationProvider,
  DecorationReceiver,
  DecorationResult,
  DecorationResultBuilder,
  DecorationType,
  Document as EditorDocument,
  GutterIcon,
  InlayHint,
  StyleSpan
} from '@qiplat/sweeteditor';
import hilog from '@ohos.hilog';
import { DEMO_RAWFILE_SYNTAX_ROOT } from './DemoSamples';
import { DemoFileMetadata } from './DemoTypes';
import {
  DecorationWorkerAnalyzeMessage,
  DecorationWorkerResultMessage,
  LineDecorationItems
} from './DemoDecorationWorkerTypes';

const TAG = 'DemoDecoration';
const HILOG_DOMAIN = 0x3D12;
const DEFAULT_ANALYSIS_FILE_NAME: string = 'sample.cpp';
const DIAGNOSTIC_DELAY_MS: number = 500;
const WORKER_ANALYSIS_WARN_MS: number = 16;
const WORKER_SCRIPT_URL: string = 'demo/ets/workers/DemoDecorationWorker.ets';

interface PendingDecorationRequest {
  receiver: DecorationReceiver;
  startedAt: number;
}

export class DemoDecorationProvider implements DecorationProvider {
  private static readonly textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  private static syntaxJsons: string[] = [];
  private static initPromise: Promise<boolean> | null = null;

  private readonly documentProvider: () => EditorDocument | null;
  private workerInstance: worker.ThreadWorker | null = null;
  private workerDocumentFileName: string | null = null;
  private nextRequestId: number = 0;
  private readonly pendingRequests: Map<number, PendingDecorationRequest> = new Map();
  private readonly diagnosticTimerIds: Map<number, number> = new Map();

  constructor(documentProvider: () => EditorDocument | null) {
    this.documentProvider = documentProvider;
  }

  static async ensureSweetLineReady(manager: resourceManager.ResourceManager | null): Promise<boolean> {
    if (DemoDecorationProvider.syntaxJsons.length > 0) {
      return true;
    }
    if (DemoDecorationProvider.initPromise !== null) {
      return DemoDecorationProvider.initPromise;
    }
    if (manager === null) {
      return false;
    }
    const initTask = DemoDecorationProvider.loadSyntaxJsons(manager);
    DemoDecorationProvider.initPromise = initTask;
    try {
      return await initTask;
    } finally {
      DemoDecorationProvider.initPromise = null;
    }
  }

  getCapabilities(): Set<DecorationType> {
    return new Set<DecorationType>([
      DecorationType.SYNTAX_HIGHLIGHT,
      DecorationType.INDENT_GUIDE,
      DecorationType.FOLD_REGION,
      DecorationType.INLAY_HINT,
      DecorationType.DIAGNOSTIC,
      DecorationType.SEPARATOR_GUIDE,
      DecorationType.GUTTER_ICON,
      DecorationType.CODELENS
    ]);
  }

  provideDecorations(context: DecorationContext, receiver: DecorationReceiver): void {
    if (DemoDecorationProvider.syntaxJsons.length === 0) {
      receiver.accept(this.buildEmptyResult());
      return;
    }

    const editorDocument = this.documentProvider();
    if (editorDocument === null) {
      receiver.accept(this.buildEmptyResult());
      return;
    }

    const currentFileName = DemoDecorationProvider.resolveCurrentFileName(context);
    const needsText = this.workerDocumentFileName !== currentFileName || context.textChanges.length > 0;
    const text = needsText ? editorDocument.getText() : null;
    const workerInstance = this.ensureWorker();
    if (workerInstance === null) {
      receiver.accept(this.buildEmptyResult());
      return;
    }

    const requestId = ++this.nextRequestId;
    const message: DecorationWorkerAnalyzeMessage = {
      type: 'analyze',
      requestId,
      fileName: currentFileName,
      totalLineCount: context.totalLineCount,
      visibleStartLine: context.visibleLineRange.start,
      visibleEndLine: context.visibleLineRange.end,
      text,
      textChanges: context.textChanges
    };

    this.pendingRequests.set(requestId, { receiver, startedAt: Date.now() });
    try {
      workerInstance.postMessage(message);
      if (needsText) {
        this.workerDocumentFileName = currentFileName;
      }
    } catch (error) {
      this.pendingRequests.delete(requestId);
      hilog.error(HILOG_DOMAIN, TAG, 'post worker request failed: %{public}s', `${error}`);
      receiver.accept(this.buildEmptyResult());
    }
  }

  dispose(): void {
    this.pendingRequests.clear();
    this.diagnosticTimerIds.forEach((timerId) => clearTimeout(timerId));
    this.diagnosticTimerIds.clear();
    if (this.workerInstance !== null) {
      try {
        this.workerInstance.terminate();
      } catch (_error) {
      }
      this.workerInstance = null;
    }
    this.workerDocumentFileName = null;
  }

  private ensureWorker(): worker.ThreadWorker | null {
    if (this.workerInstance !== null) {
      return this.workerInstance;
    }
    try {
      const instance = new worker.ThreadWorker(WORKER_SCRIPT_URL, { name: 'SweetEditorDecorationWorker' });
      instance.onmessage = (event: MessageEvents): void => this.handleWorkerMessage(event);
      instance.onerror = (event: ErrorEvent): void => this.handleWorkerError(event);
      instance.onmessageerror = (event: MessageEvents): void => {
        this.handleWorkerFailure(`message error: ${event.type}`);
      };
      if (!this.sendWorkerInit(instance)) {
        instance.terminate();
        return null;
      }
      this.workerInstance = instance;
      return instance;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'create worker failed: %{public}s', `${error}`);
      this.workerInstance = null;
      this.workerDocumentFileName = null;
      return null;
    }
  }

  private sendWorkerInit(instance: worker.ThreadWorker): boolean {
    try {
      instance.postMessage({
        type: 'init',
        syntaxJsons: [...DemoDecorationProvider.syntaxJsons]
      });
      return true;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'init worker failed: %{public}s', `${error}`);
      return false;
    }
  }

  private handleWorkerMessage(event: MessageEvents): void {
    const message = event.data as DecorationWorkerResultMessage;
    if (!message || message.type !== 'result') {
      return;
    }
    const pending = this.pendingRequests.get(message.requestId);
    if (!pending) {
      return;
    }
    this.pendingRequests.delete(message.requestId);
    if (pending.receiver.isCancelled()) {
      return;
    }

    if (message.error !== null) {
      hilog.warn(HILOG_DOMAIN, TAG, 'worker result error: %{public}s', message.error);
    }
    if (message.analysisMs >= WORKER_ANALYSIS_WARN_MS) {
      hilog.info(
        HILOG_DOMAIN,
        TAG,
        'worker analysis=%{public}dms total=%{public}dms',
        message.analysisMs,
        Date.now() - pending.startedAt
      );
    }

    pending.receiver.accept(new DecorationResultBuilder()
      .syntaxSpans(DemoDecorationProvider.mapFromLineItems(message.syntaxSpans), ApplyMode.REPLACE_RANGE)
      .inlayHints(DemoDecorationProvider.mapFromLineItems(message.inlayHints), ApplyMode.REPLACE_RANGE)
      .indentGuides(message.indentGuides, ApplyMode.REPLACE_ALL)
      .foldRegions(message.foldRegions, ApplyMode.REPLACE_ALL)
      .separatorGuides(message.separatorGuides, ApplyMode.REPLACE_ALL)
      .gutterIcons(DemoDecorationProvider.mapFromLineItems(message.gutterIcons), ApplyMode.REPLACE_ALL)
      .codeLensItems(DemoDecorationProvider.mapFromLineItems(message.codeLensItems), ApplyMode.REPLACE_ALL)
      .build());

    const diagnostics = DemoDecorationProvider.mapFromLineItems(message.diagnostics);
    const timerId = setTimeout(() => {
      this.diagnosticTimerIds.delete(message.requestId);
      if (pending.receiver.isCancelled()) {
        return;
      }
      pending.receiver.accept(new DecorationResultBuilder()
        .diagnostics(diagnostics, ApplyMode.REPLACE_ALL)
        .build());
    }, DIAGNOSTIC_DELAY_MS);
    this.diagnosticTimerIds.set(message.requestId, timerId);
  }

  private handleWorkerError(event: ErrorEvent): void {
    this.handleWorkerFailure(`${event.message} (${event.filename}:${event.lineno}:${event.colno})`);
  }

  private handleWorkerFailure(reason: string): void {
    hilog.error(HILOG_DOMAIN, TAG, 'worker failed: %{public}s', reason);
    const pending = Array.from(this.pendingRequests.values());
    this.pendingRequests.clear();
    for (const request of pending) {
      if (!request.receiver.isCancelled()) {
        request.receiver.accept(this.buildEmptyResult());
      }
    }
    if (this.workerInstance !== null) {
      try {
        this.workerInstance.terminate();
      } catch (_error) {
      }
    }
    this.workerInstance = null;
    this.workerDocumentFileName = null;
  }

  private buildEmptyResult(): DecorationResult {
    return new DecorationResultBuilder()
      .syntaxSpans(new Map<number, StyleSpan[]>(), ApplyMode.REPLACE_RANGE)
      .inlayHints(new Map<number, InlayHint[]>(), ApplyMode.REPLACE_RANGE)
      .indentGuides([], ApplyMode.REPLACE_ALL)
      .foldRegions([], ApplyMode.REPLACE_ALL)
      .separatorGuides([], ApplyMode.REPLACE_ALL)
      .gutterIcons(new Map<number, GutterIcon[]>(), ApplyMode.REPLACE_ALL)
      .codeLensItems(new Map<number, CodeLensItem[]>(), ApplyMode.REPLACE_ALL)
      .build();
  }

  private static mapFromLineItems<T>(items: LineDecorationItems<T>[]): Map<number, T[]> {
    const out = new Map<number, T[]>();
    for (let index = 0; index < items.length; index++) {
      const entry = items[index];
      out.set(entry.line, entry.items ? entry.items : []);
    }
    return out;
  }

  private static resolveCurrentFileName(context: DecorationContext): string {
    if (context.editorMetadata instanceof DemoFileMetadata && context.editorMetadata.fileName.length > 0) {
      return context.editorMetadata.fileName;
    }
    return DEFAULT_ANALYSIS_FILE_NAME;
  }

  private static async loadSyntaxJsons(manager: resourceManager.ResourceManager): Promise<boolean> {
    let syntaxFiles: string[] = [];
    try {
      syntaxFiles = await manager.getRawFileList(DEMO_RAWFILE_SYNTAX_ROOT);
    } catch (error) {
      throw new Error(`Failed to list syntax rawfiles under ${DEMO_RAWFILE_SYNTAX_ROOT}: ${String(error)}`);
    }
    const sortedSyntaxFiles = [...syntaxFiles].sort((left: string, right: string) => left.localeCompare(right));
    if (sortedSyntaxFiles.length === 0) {
      throw new Error(`No syntax files found under rawfile/${DEMO_RAWFILE_SYNTAX_ROOT}`);
    }

    const syntaxJsons: string[] = [];
    for (let index = 0; index < sortedSyntaxFiles.length; index++) {
      const assetName = sortedSyntaxFiles[index];
      let syntaxContent: Uint8Array;
      try {
        syntaxContent = await manager.getRawFileContent(`${DEMO_RAWFILE_SYNTAX_ROOT}/${assetName}`);
      } catch (error) {
        throw new Error(`Failed to load syntax rawfile ${assetName}: ${String(error)}`);
      }
      syntaxJsons.push(DemoDecorationProvider.textDecoder.decodeToString(syntaxContent));
    }
    DemoDecorationProvider.syntaxJsons = syntaxJsons;
    return true;
  }
}
