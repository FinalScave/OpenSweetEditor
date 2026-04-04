export interface TabStopRange {
  startLine: number;
  startColumn: number;
  endLine: number;
  endColumn: number;
}

export interface TabStopGroup {
  index: number;
  defaultText: string | null;
  ranges: TabStopRange[];
}

export interface LinkedEditingModel {
  groups: TabStopGroup[];
}

