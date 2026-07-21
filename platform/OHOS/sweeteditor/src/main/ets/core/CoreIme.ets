import { CaretAffinity } from './CoreFoundation';

export enum ImeCommandKind {
  SET_SELECTION = 0,
  BEGIN_COMPOSITION = 1,
  UPDATE_COMPOSITION = 2,
  COMMIT_TEXT = 3,
  FINISH_COMPOSITION = 4,
  CANCEL_COMPOSITION = 5,
  DELETE_SURROUNDING = 6,
}

export function imeCommandKindFromValue(value: number): ImeCommandKind {
  switch (value) {
    case 0: return ImeCommandKind.SET_SELECTION;
    case 1: return ImeCommandKind.BEGIN_COMPOSITION;
    case 2: return ImeCommandKind.UPDATE_COMPOSITION;
    case 3: return ImeCommandKind.COMMIT_TEXT;
    case 4: return ImeCommandKind.FINISH_COMPOSITION;
    case 5: return ImeCommandKind.CANCEL_COMPOSITION;
    case 6: return ImeCommandKind.DELETE_SURROUNDING;
    default: throw new Error('Unknown ImeCommandKind value: ' + value);
  }
}

export enum ImeCoordinateSpace {
  DOCUMENT = 0,
  EDITING_BUFFER = 1,
  CONTEXT_SLICE = 2,
  COMPOSITION = 3,
}

export function imeCoordinateSpaceFromValue(value: number): ImeCoordinateSpace {
  switch (value) {
    case 0: return ImeCoordinateSpace.DOCUMENT;
    case 1: return ImeCoordinateSpace.EDITING_BUFFER;
    case 2: return ImeCoordinateSpace.CONTEXT_SLICE;
    case 3: return ImeCoordinateSpace.COMPOSITION;
    default: throw new Error('Unknown ImeCoordinateSpace value: ' + value);
  }
}

export enum ImeHostAction {
  NONE = 0,
  CLOSE_SESSION = 1,
  RESTART_SESSION = 2,
}

export function imeHostActionFromValue(value: number): ImeHostAction {
  switch (value) {
    case 0: return ImeHostAction.NONE;
    case 1: return ImeHostAction.CLOSE_SESSION;
    case 2: return ImeHostAction.RESTART_SESSION;
    default: throw new Error('Unknown ImeHostAction value: ' + value);
  }
}

export enum ImeMutationModel {
  COMMAND = 0,
  TEXT_UPDATE = 1,
}

export function imeMutationModelFromValue(value: number): ImeMutationModel {
  switch (value) {
    case 0: return ImeMutationModel.COMMAND;
    case 1: return ImeMutationModel.TEXT_UPDATE;
    default: throw new Error('Unknown ImeMutationModel value: ' + value);
  }
}

export enum ImeResultCode {
  OK = 0,
  SESSION_MISMATCH = 1,
  REJECTED = 2,
  READ_ONLY = 3,
}

export function imeResultCodeFromValue(value: number): ImeResultCode {
  switch (value) {
    case 0: return ImeResultCode.OK;
    case 1: return ImeResultCode.SESSION_MISMATCH;
    case 2: return ImeResultCode.REJECTED;
    case 3: return ImeResultCode.READ_ONLY;
    default: throw new Error('Unknown ImeResultCode value: ' + value);
  }
}

export enum ImeTextSource {
  EDITING = 0,
  COMMITTED = 1,
  EDITING_BUFFER = 2,
}

export function imeTextSourceFromValue(value: number): ImeTextSource {
  switch (value) {
    case 0: return ImeTextSource.EDITING;
    case 1: return ImeTextSource.COMMITTED;
    case 2: return ImeTextSource.EDITING_BUFFER;
    default: throw new Error('Unknown ImeTextSource value: ' + value);
  }
}

export enum ImeTextUnit {
  UTF16_CODE_UNIT = 0,
  UNICODE_CODE_POINT = 1,
}

export function imeTextUnitFromValue(value: number): ImeTextUnit {
  switch (value) {
    case 0: return ImeTextUnit.UTF16_CODE_UNIT;
    case 1: return ImeTextUnit.UNICODE_CODE_POINT;
    default: throw new Error('Unknown ImeTextUnit value: ' + value);
  }
}

export class ImeCommand {
  kind: ImeCommandKind = ImeCommandKind.SET_SELECTION;
  targetRange: ImeOffsetRange = { coordinateSpace: ImeCoordinateSpace.DOCUMENT, startUtf16: -1, endUtf16: -1 };
  selectionAfter: ImeSelection = { coordinateSpace: ImeCoordinateSpace.DOCUMENT, anchorUtf16: -1, activeUtf16: -1, affinity: CaretAffinity.DOWNSTREAM };
  text: string = '';
  deleteBefore: number = 0;
  deleteAfter: number = 0;
  textUnit: ImeTextUnit = ImeTextUnit.UTF16_CODE_UNIT;
}

export class ImeCommandBatch {
  sessionId: number = 0;
  commands: ImeCommand[] = [];
}

export interface ImeOffsetRange {
  coordinateSpace: ImeCoordinateSpace;
  startUtf16: number;
  endUtf16: number;
}

export interface ImeSelection {
  coordinateSpace: ImeCoordinateSpace;
  anchorUtf16: number;
  activeUtf16: number;
  affinity: CaretAffinity;
}

export interface ImeState {
  resultCode: ImeResultCode;
  sessionId: number;
  stateRevision: number;
  selection: ImeSelection;
  compositionRange: ImeOffsetRange;
}

export interface ImeTextContext {
  resultCode: ImeResultCode;
  sliceStartUtf16: number;
  totalLengthUtf16: number;
  text: string;
  selection: ImeSelection;
  compositionRange: ImeOffsetRange;
}

export class ImeTextUpdateBatch {
  sessionId: number = 0;
  expectedStateRevision: number = 0;
  steps: ImeTextUpdateStep[] = [];
}

export class ImeTextUpdateStep {
  oldText: string = '';
  patchRange: ImeOffsetRange = { coordinateSpace: ImeCoordinateSpace.DOCUMENT, startUtf16: -1, endUtf16: -1 };
  replacementText: string = '';
  selectionAfter: ImeSelection = { coordinateSpace: ImeCoordinateSpace.DOCUMENT, anchorUtf16: -1, activeUtf16: -1, affinity: CaretAffinity.DOWNSTREAM };
  compositionAfter: ImeOffsetRange = { coordinateSpace: ImeCoordinateSpace.DOCUMENT, startUtf16: -1, endUtf16: -1 };
}
