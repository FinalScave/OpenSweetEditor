import { TextPosition, TextRange } from './CoreFoundation';

export enum ImeContextPolicy {
  NONE = 0,
  LIMITED_FOR_CANDIDATES = 1,
}

export function imeContextPolicyFromValue(value: number): ImeContextPolicy {
  switch (value) {
    case 0: return ImeContextPolicy.NONE;
    case 1: return ImeContextPolicy.LIMITED_FOR_CANDIDATES;
    default: return ImeContextPolicy.NONE;
  }
}

export enum ImeInputContextKind {
  NONE = 0,
  SELECTION_ONLY = 1,
  DOCUMENT_WINDOW = 2,
  TRANSIENT_INPUT = 3,
}

export function imeInputContextKindFromValue(value: number): ImeInputContextKind {
  switch (value) {
    case 0: return ImeInputContextKind.NONE;
    case 1: return ImeInputContextKind.SELECTION_ONLY;
    case 2: return ImeInputContextKind.DOCUMENT_WINDOW;
    case 3: return ImeInputContextKind.TRANSIENT_INPUT;
    default: return ImeInputContextKind.NONE;
  }
}

export enum ImePreeditStorage {
  NONE = 0,
  VISIBLE_DOCUMENT_COMPOSITION = 1,
  SHADOW_ONLY = 2,
}

export function imePreeditStorageFromValue(value: number): ImePreeditStorage {
  switch (value) {
    case 0: return ImePreeditStorage.NONE;
    case 1: return ImePreeditStorage.VISIBLE_DOCUMENT_COMPOSITION;
    case 2: return ImePreeditStorage.SHADOW_ONLY;
    default: return ImePreeditStorage.NONE;
  }
}

export enum ImeScriptClass {
  UNKNOWN = 0,
  LATIN = 1,
  CJK = 2,
  KANA = 3,
  HANGUL = 4,
}

export function imeScriptClassFromValue(value: number): ImeScriptClass {
  switch (value) {
    case 0: return ImeScriptClass.UNKNOWN;
    case 1: return ImeScriptClass.LATIN;
    case 2: return ImeScriptClass.CJK;
    case 3: return ImeScriptClass.KANA;
    case 4: return ImeScriptClass.HANGUL;
    default: return ImeScriptClass.UNKNOWN;
  }
}

export enum ImeTextModelMode {
  DOCUMENT_WINDOW = 0,
  TRANSIENT_INPUT = 1,
}

export function imeTextModelModeFromValue(value: number): ImeTextModelMode {
  switch (value) {
    case 0: return ImeTextModelMode.DOCUMENT_WINDOW;
    case 1: return ImeTextModelMode.TRANSIENT_INPUT;
    default: return ImeTextModelMode.DOCUMENT_WINDOW;
  }
}

export enum ImeTextUnit {
  GRAPHEME = 0,
  CODE_POINT = 1,
}

export function imeTextUnitFromValue(value: number): ImeTextUnit {
  switch (value) {
    case 0: return ImeTextUnit.GRAPHEME;
    case 1: return ImeTextUnit.CODE_POINT;
    default: return ImeTextUnit.GRAPHEME;
  }
}

export class ImeDocumentTextReplacement {
  startOffset: number = 0;
  endOffset: number = 0;
  text: string = '';
  cursorOffset: number = 1;
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}

export interface ImeInputContext {
  id: number;
  revision: number;
  documentStartOffset: number;
  text: string;
  selection: ImeTextRange;
  hasComposition: boolean;
  composition: ImeTextRange;
  kind: ImeInputContextKind;
}

export class ImeInputContextTextReplacement {
  startOffset: number = 0;
  endOffset: number = 0;
  text: string = '';
  cursorOffset: number = 1;
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}

export class ImeInputStateTextReplacement {
  contextId: number = 0;
  documentStartOffset: number = 0;
  startOffset: number = 0;
  endOffset: number = 0;
  text: string = '';
  cursorOffset: number = 1;
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}

export interface ImeSyncSnapshot {
  cursor: TextPosition;
  selection: TextRange;
  hasSelection: boolean;
  hasComposingSession: boolean;
  hasVisibleCompositionRange: boolean;
  visibleCompositionRange: TextRange;
  hasPlatformMarkedRange: boolean;
  platformMarkedRange: TextRange;
  preeditStorage: ImePreeditStorage;
  contextPolicy: ImeContextPolicy;
  clearPlatformPreedit: boolean;
}

export class ImeTextModelDelta {
  mode: ImeTextModelMode = ImeTextModelMode.DOCUMENT_WINDOW;
  contextId: number = 0;
  documentStartOffset: number = 0;
  oldText: string = '';
  delta: ImeTextRange = { start: -1, end: -1 };
  deltaText: string = '';
  selection: ImeTextRange = { start: 0, end: 0 };
  composition: ImeTextRange = { start: -1, end: -1 };
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}

export class ImeTextModelState {
  mode: ImeTextModelMode = ImeTextModelMode.DOCUMENT_WINDOW;
  contextId: number = 0;
  documentStartOffset: number = 0;
  text: string = '';
  selection: ImeTextRange = { start: 0, end: 0 };
  composition: ImeTextRange = { start: -1, end: -1 };
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}

export interface ImeTextRange {
  start: number;
  end: number;
}

export class ImeTextReplacement {
  range: TextRange = { start: { line: 0, column: 0 }, end: { line: 0, column: 0 } };
  text: string = '';
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}
