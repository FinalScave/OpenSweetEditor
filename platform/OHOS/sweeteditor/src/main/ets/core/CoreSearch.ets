import { TextRange } from './CoreFoundation';

export enum SearchStatus {
  INACTIVE = 0,
  SEARCHING = 1,
  READY = 2,
  STALE = 3,
  FAILED = 4,
}

export function searchStatusFromValue(value: number): SearchStatus {
  switch (value) {
    case 0: return SearchStatus.INACTIVE;
    case 1: return SearchStatus.SEARCHING;
    case 2: return SearchStatus.READY;
    case 3: return SearchStatus.STALE;
    case 4: return SearchStatus.FAILED;
    default: return SearchStatus.INACTIVE;
  }
}

export interface SearchOptions {
  caseSensitive: boolean;
  wholeWord: boolean;
  useRegex: boolean;
  wrapAround: boolean;
  maxMatches: number;
}

export class SearchReplaceRequest {
  replacement: string = '';
}

export class SearchRequest {
  pattern: string = '';
  options: SearchOptions = { caseSensitive: false, wholeWord: false, useRegex: false, wrapAround: true, maxMatches: 10000 };
}

export interface SearchState {
  status: SearchStatus;
  pattern: string;
  options: SearchOptions;
  generation: number;
  documentRevision: number;
  matchCount: number;
  currentIndex: number;
  hasCurrentMatch: boolean;
  currentRange: TextRange;
  errorMessage: string;
}
