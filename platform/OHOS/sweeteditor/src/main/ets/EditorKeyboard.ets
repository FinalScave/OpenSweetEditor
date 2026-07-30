import { KeyCode, KeyModifier } from './core/CoreKeymap';
import { KeyCode as OhosKeyCode } from '@ohos.multimodalInput.keyCode';

const OHOS_META_KEY_PRESSED = 1;
const SINGLE_PRINTABLE_KEY_TEXT_LENGTH = 1;

export enum OverlayKeyAction {
  NONE,
  TAB,
  ENTER,
  ESCAPE,
  UP,
  DOWN
}

export function resolveNativeKeyCode(event: KeyEvent, modifiers: number): number {
  const nativeKeyCode = mapOhosKeyCodeToNative(event.keyCode);
  if (nativeKeyCode !== KeyCode.NONE) {
    return nativeKeyCode;
  }

  if ((modifiers & (KeyModifier.CTRL | KeyModifier.META | KeyModifier.ALT)) === KeyModifier.NONE) {
    return KeyCode.NONE;
  }

  const text = extractPrintableKeyText(event);
  if (!text) {
    return KeyCode.NONE;
  }

  const mappedKeyCode = mapPrintableKeyCode(text);
  if (mappedKeyCode === KeyCode.NONE) {
    return KeyCode.NONE;
  }
  return mappedKeyCode as number;
}

export function resolveOverlayKeyAction(event: KeyEvent): OverlayKeyAction {
  return mapOhosKeyCodeToOverlayAction(event.keyCode);
}

function mapOhosKeyCodeToOverlayAction(ohosKeyCode: number): OverlayKeyAction {
  switch (ohosKeyCode) {
    case OhosKeyCode.KEYCODE_TAB:
      return OverlayKeyAction.TAB;
    case OhosKeyCode.KEYCODE_ENTER:
      return OverlayKeyAction.ENTER;
    case OhosKeyCode.KEYCODE_ESCAPE:
      return OverlayKeyAction.ESCAPE;
    case OhosKeyCode.KEYCODE_DPAD_UP:
      return OverlayKeyAction.UP;
    case OhosKeyCode.KEYCODE_DPAD_DOWN:
      return OverlayKeyAction.DOWN;
    default:
      return OverlayKeyAction.NONE;
  }
}

export function getNativeModifiers(event: KeyEvent): number {
  let modifiers = getEventModifiers(event);
  if (event.metaKey === OHOS_META_KEY_PRESSED) {
    modifiers |= KeyModifier.META;
  }
  return modifiers;
}

export function getPointerModifiers(event: BaseEvent): number {
  return getEventModifiers(event);
}

export function extractPrintableKeyText(event: KeyEvent): string | null {
  const keyText = event.keyText;
  if (!keyText || Array.from(keyText).length !== SINGLE_PRINTABLE_KEY_TEXT_LENGTH) {
    return null;
  }

  return isPrintableText(keyText) ? keyText : null;
}

function mapPrintableKeyCode(text: string): KeyCode {
  const normalized = text.toUpperCase();
  switch (normalized) {
    case 'A':
      return KeyCode.A;
    case 'C':
      return KeyCode.C;
    case 'D':
      return KeyCode.D;
    case 'K':
      return KeyCode.K;
    case 'V':
      return KeyCode.V;
    case 'X':
      return KeyCode.X;
    case 'Y':
      return KeyCode.Y;
    case 'Z':
      return KeyCode.Z;
    case ' ':
      return KeyCode.SPACE;
    default:
      return KeyCode.NONE;
  }
}

function mapOhosKeyCodeToNative(ohosKeyCode: number): number {
  switch (ohosKeyCode) {
    case OhosKeyCode.KEYCODE_DEL:
      return KeyCode.BACKSPACE;
    case OhosKeyCode.KEYCODE_TAB:
      return KeyCode.TAB;
    case OhosKeyCode.KEYCODE_ENTER:
      return KeyCode.ENTER;
    case OhosKeyCode.KEYCODE_ESCAPE:
      return KeyCode.ESCAPE;
    case OhosKeyCode.KEYCODE_FORWARD_DEL:
      return KeyCode.DELETE_KEY;
    case OhosKeyCode.KEYCODE_DPAD_LEFT:
      return KeyCode.LEFT;
    case OhosKeyCode.KEYCODE_DPAD_UP:
      return KeyCode.UP;
    case OhosKeyCode.KEYCODE_DPAD_RIGHT:
      return KeyCode.RIGHT;
    case OhosKeyCode.KEYCODE_DPAD_DOWN:
      return KeyCode.DOWN;
    case OhosKeyCode.KEYCODE_MOVE_HOME:
      return KeyCode.HOME;
    case OhosKeyCode.KEYCODE_MOVE_END:
      return KeyCode.END;
    case OhosKeyCode.KEYCODE_PAGE_UP:
      return KeyCode.PAGE_UP;
    case OhosKeyCode.KEYCODE_PAGE_DOWN:
      return KeyCode.PAGE_DOWN;
    default:
      return KeyCode.NONE;
  }
}

function getEventModifiers(event: KeyEvent | BaseEvent): number {
  let modifiers = KeyModifier.NONE;
  if (isModifierPressed(event, 'Shift')) {
    modifiers |= KeyModifier.SHIFT;
  }
  if (isModifierPressed(event, 'Ctrl')) {
    modifiers |= KeyModifier.CTRL;
  }
  if (isModifierPressed(event, 'Alt')) {
    modifiers |= KeyModifier.ALT;
  }
  return modifiers;
}

function isModifierPressed(event: KeyEvent | BaseEvent, key: string): boolean {
  if (!event.getModifierKeyState) {
    return false;
  }
  return event.getModifierKeyState([key]);
}

function isPrintableText(text: string): boolean {
  return text.length > 0 && !/[\u0000-\u001f\u007f]/.test(text);
}
