import { EditorMetadata } from '@qiplat/sweeteditor';

export class DemoFileMetadata implements EditorMetadata {
  readonly fileName: string;
  readonly languageId: string;

  constructor(fileName: string, languageId: string) {
    this.fileName = fileName;
    this.languageId = languageId;
  }
}
