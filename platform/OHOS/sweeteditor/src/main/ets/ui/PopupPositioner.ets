export enum PopupSide {
  ABOVE,
  BELOW,
  LEFT,
  RIGHT
}

export enum PopupAlign {
  START,
  CENTER,
  END
}

export interface PopupPlacement {
  side: PopupSide;
  align: PopupAlign;
}

export interface PopupRect {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface PopupPositionRequest {
  availableFrame: PopupRect;
  anchorRect: PopupRect;
  popupWidth: number;
  popupHeight: number;
  gap: number;
  clearance: number;
  preferredPlacements: PopupPlacement[];
  isRtl?: boolean;
}

export interface PopupPositionResult {
  x: number;
  y: number;
  placement: PopupPlacement;
  availableFrame: PopupRect;
}

interface PopupCandidate {
  x: number;
  y: number;
  placement: PopupPlacement;
  overflow: number;
}

const DEFAULT_PLACEMENT: PopupPlacement = { side: PopupSide.BELOW, align: PopupAlign.CENTER };

export function popupPlacement(side: PopupSide, align: PopupAlign): PopupPlacement {
  return { side: side, align: align };
}

export function popupRect(left: number, top: number, right: number, bottom: number): PopupRect {
  return { left: left, top: top, right: right, bottom: bottom };
}

export function insetPopupRect(rect: PopupRect, horizontal: number, vertical: number): PopupRect {
  const left = rect.left + horizontal;
  const top = rect.top + vertical;
  const right = rect.right - horizontal;
  const bottom = rect.bottom - vertical;
  const centerX = rectCenterX(rect);
  const centerY = rectCenterY(rect);
  return {
    left: left <= right ? left : centerX,
    top: top <= bottom ? top : centerY,
    right: left <= right ? right : centerX,
    bottom: top <= bottom ? bottom : centerY
  };
}

export function computePopupPosition(request: PopupPositionRequest): PopupPositionResult {
  const popupWidth = Math.max(1, request.popupWidth);
  const popupHeight = Math.max(1, request.popupHeight);
  const placements = request.preferredPlacements.length > 0
    ? request.preferredPlacements
    : [DEFAULT_PLACEMENT];
  let best: PopupCandidate | null = null;

  for (const placement of placements) {
    const candidate = buildCandidate(
      request.anchorRect,
      request.availableFrame,
      popupWidth,
      popupHeight,
      Math.max(0, request.gap),
      Math.max(0, request.clearance),
      placement,
      request.isRtl === true
    );
    if (candidate.overflow === 0) {
      return buildResult(candidate, request.availableFrame, popupWidth, popupHeight);
    }
    if (best === null || candidate.overflow < best.overflow) {
      best = candidate;
    }
  }

  if (best === null) {
    best = buildCandidate(
      request.anchorRect,
      request.availableFrame,
      popupWidth,
      popupHeight,
      Math.max(0, request.gap),
      Math.max(0, request.clearance),
      DEFAULT_PLACEMENT,
      request.isRtl === true
    );
  }
  return buildResult(best, request.availableFrame, popupWidth, popupHeight);
}

function buildResult(candidate: PopupCandidate, availableFrame: PopupRect,
  popupWidth: number, popupHeight: number): PopupPositionResult {
  const minX = availableFrame.left;
  const maxX = availableFrame.left + Math.max(0, rectWidth(availableFrame) - popupWidth);
  const minY = availableFrame.top;
  const maxY = availableFrame.top + Math.max(0, rectHeight(availableFrame) - popupHeight);
  return {
    x: clamp(candidate.x, minX, maxX),
    y: clamp(candidate.y, minY, maxY),
    placement: candidate.placement,
    availableFrame: popupRect(availableFrame.left, availableFrame.top, availableFrame.right, availableFrame.bottom)
  };
}

function buildCandidate(anchorRect: PopupRect, availableFrame: PopupRect, popupWidth: number, popupHeight: number,
  gap: number, clearance: number, placement: PopupPlacement, isRtl: boolean): PopupCandidate {
  let x: number;
  let y: number;
  switch (placement.side) {
    case PopupSide.ABOVE:
      x = resolveHorizontalAlignedX(anchorRect, popupWidth, placement.align, isRtl);
      y = anchorRect.top - popupHeight - gap;
      break;
    case PopupSide.BELOW:
      x = resolveHorizontalAlignedX(anchorRect, popupWidth, placement.align, isRtl);
      y = anchorRect.bottom + gap + clearance;
      break;
    case PopupSide.LEFT:
      x = anchorRect.left - popupWidth - gap;
      y = resolveVerticalAlignedY(anchorRect, popupHeight, placement.align);
      break;
    case PopupSide.RIGHT:
    default:
      x = anchorRect.right + gap + clearance;
      y = resolveVerticalAlignedY(anchorRect, popupHeight, placement.align);
      break;
  }

  const screenX = Math.round(x);
  const screenY = Math.round(y);
  const overflowLeft = Math.max(0, availableFrame.left - screenX);
  const overflowTop = Math.max(0, availableFrame.top - screenY);
  const overflowRight = Math.max(0, screenX + popupWidth - availableFrame.right);
  const overflowBottom = Math.max(0, screenY + popupHeight - availableFrame.bottom);
  return {
    x: screenX,
    y: screenY,
    placement: placement,
    overflow: overflowLeft + overflowTop + overflowRight + overflowBottom
  };
}

function resolveHorizontalAlignedX(anchorRect: PopupRect, popupWidth: number,
  align: PopupAlign, isRtl: boolean): number {
  switch (align) {
    case PopupAlign.START:
      return isRtl ? anchorRect.right - popupWidth : anchorRect.left;
    case PopupAlign.END:
      return isRtl ? anchorRect.left : anchorRect.right - popupWidth;
    case PopupAlign.CENTER:
    default:
      return rectCenterX(anchorRect) - popupWidth * 0.5;
  }
}

function resolveVerticalAlignedY(anchorRect: PopupRect, popupHeight: number, align: PopupAlign): number {
  switch (align) {
    case PopupAlign.START:
      return anchorRect.top;
    case PopupAlign.END:
      return anchorRect.bottom - popupHeight;
    case PopupAlign.CENTER:
    default:
      return rectCenterY(anchorRect) - popupHeight * 0.5;
  }
}

function rectWidth(rect: PopupRect): number {
  return Math.max(0, rect.right - rect.left);
}

function rectHeight(rect: PopupRect): number {
  return Math.max(0, rect.bottom - rect.top);
}

function rectCenterX(rect: PopupRect): number {
  return (rect.left + rect.right) * 0.5;
}

function rectCenterY(rect: PopupRect): number {
  return (rect.top + rect.bottom) * 0.5;
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) {
    return min;
  }
  return Math.min(Math.max(value, min), max);
}
