export function argbToCssColor(argb: number): string {
  const a = ((argb >>> 24) & 0xFF) / 255;
  const r = (argb >>> 16) & 0xFF;
  const g = (argb >>> 8) & 0xFF;
  const b = argb & 0xFF;
  if (a >= 1.0) {
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }
  return `rgba(${r}, ${g}, ${b}, ${a.toFixed(3)})`;
}

export function multiplyArgbAlpha(argb: number, alphaMultiplier: number): number {
  const m = Math.max(0, Math.min(1, alphaMultiplier));
  const baseAlpha = (argb >>> 24) & 0xFF;
  const outAlpha = Math.round(baseAlpha * m);
  return (outAlpha << 24) | (argb & 0x00FFFFFF);
}
