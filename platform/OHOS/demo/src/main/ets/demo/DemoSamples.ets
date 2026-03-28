import { EditorTheme, LanguageConfiguration } from '@qiplat/sweeteditor';
import { DemoFileMetadata } from './DemoTypes';

export const DEMO_STYLE_COLOR: number = EditorTheme.STYLE_USER_BASE + 1;
export const DEMO_RAWFILE_ROOT: string = 'demo_shared/files';
export const FALLBACK_FILE_NAME: string = 'example.java';
export const FALLBACK_TEXT: string =
  'public class DemoFallback {\n' +
  '    public static void main(String[] args) {\n' +
  '        // TODO sync platform/_res into rawfile\n' +
  '        String color = "#4A8F7A";\n' +
  '        System.out.println(color);\n' +
  '    }\n' +
  '}\n';

export function createDemoTheme(isDarkTheme: boolean): EditorTheme {
  const theme = isDarkTheme ? EditorTheme.dark() : EditorTheme.light();
  const color = isDarkTheme ? 0xFFB5CEA8 : 0xFF098658;
  theme.defineTextStyle(DEMO_STYLE_COLOR, {
    color,
    backgroundColor: 0,
    fontStyle: 0
  });
  return theme;
}

export function createDemoFileMetadata(fileName: string): DemoFileMetadata {
  return new DemoFileMetadata(fileName, resolveLanguageId(fileName));
}

export function createLanguageConfiguration(fileName: string): LanguageConfiguration {
  const builder = LanguageConfiguration.builder(resolveLanguageId(fileName))
    .addBracket('(', ')')
    .addBracket('[', ']')
    .addBracket('{', '}')
    .addAutoClosingPair('(', ')')
    .addAutoClosingPair('[', ']')
    .addAutoClosingPair('{', '}')
    .addAutoClosingPair('"', '"')
    .addAutoClosingPair('\'', '\'')
    .setTabSize(isLuaFile(fileName) ? 2 : 4)
    .setInsertSpaces(true);
  return builder.build();
}

function isLuaFile(fileName: string): boolean {
  return fileName.toLowerCase().endsWith('.lua');
}

function resolveLanguageId(fileName: string): string {
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.java')) {
    return 'java';
  }
  if (lower.endsWith('.kt') || lower.endsWith('.kts')) {
    return 'kotlin';
  }
  if (lower.endsWith('.lua')) {
    return 'lua';
  }
  if (lower.endsWith('.hpp') || lower.endsWith('.h') || lower.endsWith('.cpp') || lower.endsWith('.cc')) {
    return 'cpp';
  }
  return 'text';
}
