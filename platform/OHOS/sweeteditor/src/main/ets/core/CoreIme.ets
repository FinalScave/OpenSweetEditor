import { TextPosition, TextRange } from './CoreFoundation';

export enum ImeCommandKind {
  SET_SELECTION = 0,
  SET_PREEDIT_TEXT = 1,
  COMMIT_TEXT = 2,
  FINISH_PREEDIT = 3,
  CANCEL_PREEDIT = 4,
  SET_MARKED_RANGE = 5,
  CLEAR_MARKED_RANGE = 6,
  REPLACE_TEXT = 7,
  DELETE_SURROUNDING_TEXT = 8,
  SET_KEYBOARD_SCRIPT = 9,
}

export function imeCommandKindFromValue(value: number): ImeCommandKind {
  switch (value) {
    case 0: return ImeCommandKind.SET_SELECTION;
    case 1: return ImeCommandKind.SET_PREEDIT_TEXT;
    case 2: return ImeCommandKind.COMMIT_TEXT;
    case 3: return ImeCommandKind.FINISH_PREEDIT;
    case 4: return ImeCommandKind.CANCEL_PREEDIT;
    case 5: return ImeCommandKind.SET_MARKED_RANGE;
    case 6: return ImeCommandKind.CLEAR_MARKED_RANGE;
    case 7: return ImeCommandKind.REPLACE_TEXT;
    case 8: return ImeCommandKind.DELETE_SURROUNDING_TEXT;
    case 9: return ImeCommandKind.SET_KEYBOARD_SCRIPT;
    default: return ImeCommandKind.SET_SELECTION;
  }
}

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

export enum ImeMarkedRangeRole {
  NONE = 0,
  PREEDIT = 1,
  SYSTEM_MARK = 2,
}

export function imeMarkedRangeRoleFromValue(value: number): ImeMarkedRangeRole {
  switch (value) {
    case 0: return ImeMarkedRangeRole.NONE;
    case 1: return ImeMarkedRangeRole.PREEDIT;
    case 2: return ImeMarkedRangeRole.SYSTEM_MARK;
    default: return ImeMarkedRangeRole.NONE;
  }
}

export enum ImePreeditStorage {
  NONE = 0,
  VISIBLE_DOCUMENT_PREEDIT = 1,
  SHADOW_ONLY = 2,
}

export function imePreeditStorageFromValue(value: number): ImePreeditStorage {
  switch (value) {
    case 0: return ImePreeditStorage.NONE;
    case 1: return ImePreeditStorage.VISIBLE_DOCUMENT_PREEDIT;
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

export enum ImeTextUpdateKind {
  SNAPSHOT = 0,
  PATCH = 1,
}

export function imeTextUpdateKindFromValue(value: number): ImeTextUpdateKind {
  switch (value) {
    case 0: return ImeTextUpdateKind.SNAPSHOT;
    case 1: return ImeTextUpdateKind.PATCH;
    default: return ImeTextUpdateKind.SNAPSHOT;
  }
}

export enum ImeTextUpdateScope {
  DOCUMENT_WINDOW = 0,
  TRANSIENT_INPUT = 1,
}

export function imeTextUpdateScopeFromValue(value: number): ImeTextUpdateScope {
  switch (value) {
    case 0: return ImeTextUpdateScope.DOCUMENT_WINDOW;
    case 1: return ImeTextUpdateScope.TRANSIENT_INPUT;
    default: return ImeTextUpdateScope.DOCUMENT_WINDOW;
  }
}

export class ImeCommandMessage {
  kind: ImeCommandKind = ImeCommandKind.SET_SELECTION;
  contextId: number = 0;
  contextRevision: number = 0;
  documentStartOffset: number = 0;
  range: ImeOffsetRange = { start: -1, end: -1 };
  selection: ImeOffsetRange = { start: -1, end: -1 };
  text: string = '';
  cursorOffset: number = 1;
  deleteBefore: number = 0;
  deleteAfter: number = 0;
  textUnit: ImeTextUnit = ImeTextUnit.GRAPHEME;
  markedRole: ImeMarkedRangeRole = ImeMarkedRangeRole.NONE;
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}

export interface ImeInputContext {
  id: number;
  revision: number;
  documentStartOffset: number;
  text: string;
  selection: ImeOffsetRange;
  hasComposition: boolean;
  composition: ImeOffsetRange;
  hasSystemMarkRange: boolean;
  systemMarkRange: ImeOffsetRange;
  kind: ImeInputContextKind;
}

export interface ImeMarkedRange {
  role: ImeMarkedRangeRole;
  range: ImeOffsetRange;
}

export interface ImeOffsetRange {
  start: number;
  end: number;
}

export interface ImeSyncSnapshot {
  cursor: TextPosition;
  selection: TextRange;
  hasSelection: boolean;
  hasComposingSession: boolean;
  hasVisibleCompositionRange: boolean;
  visibleCompositionRange: TextRange;
  hasSystemMarkRange: boolean;
  systemMarkRange: TextRange;
  preeditStorage: ImePreeditStorage;
  contextPolicy: ImeContextPolicy;
  clearSystemMark: boolean;
}

export interface ImeTextPatch {
  range: ImeOffsetRange;
  text: string;
}

export class ImeTextUpdateMessage {
  kind: ImeTextUpdateKind = ImeTextUpdateKind.SNAPSHOT;
  scope: ImeTextUpdateScope = ImeTextUpdateScope.DOCUMENT_WINDOW;
  contextId: number = 0;
  contextRevision: number = 0;
  documentStartOffset: number = 0;
  text: string = '';
  patch: ImeTextPatch = { range: { start: -1, end: -1 }, text: '' };
  selection: ImeOffsetRange = { start: -1, end: -1 };
  markedRange: ImeMarkedRange = { role: ImeMarkedRangeRole.NONE, range: { start: -1, end: -1 } };
  scriptClass: ImeScriptClass = ImeScriptClass.UNKNOWN;
}
