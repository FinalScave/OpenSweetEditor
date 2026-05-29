import { TextRange } from './CoreFoundation';

export class LinkedEditingModel {
  groups: TabStopGroup[];
}

export class TabStopGroup {
  index: number = 0;
  ranges: TextRange[];
  defaultText: string;
}
