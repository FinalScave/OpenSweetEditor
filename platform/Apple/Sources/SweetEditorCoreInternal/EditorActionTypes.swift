import Foundation

enum HitTargetType: String, Codable {
    case NONE
    case INLAY_HINT_TEXT
    case INLAY_HINT_ICON
    case GUTTER_ICON
    case FOLD_PLACEHOLDER
    case FOLD_GUTTER
    case INLAY_HINT_COLOR
    case CODELENS
    case LINK
}

struct HitTargetData: Codable {
    let type: HitTargetType
    let line: Int
    let column: Int
    let icon_id: Int32
    let color_value: Int32

    init(type: HitTargetType, line: Int, column: Int, icon_id: Int32, color_value: Int32) {
        self.type = type
        self.line = line
        self.column = column
        self.icon_id = icon_id
        self.color_value = color_value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(HitTargetType.self, forKey: .type)
        line = try container.decode(Int.self, forKey: .line)
        column = try container.decode(Int.self, forKey: .column)
        icon_id = try container.decode(Int32.self, forKey: .icon_id)
        color_value = try container.decodeIfPresent(Int32.self, forKey: .color_value) ?? 0
    }
}

struct TextRangeData: Codable {
    let start: TextPositionData
    let end: TextPositionData
}

enum GestureType: String, Codable {
    case UNDEFINED
    case TAP
    case DOUBLE_TAP
    case LONG_PRESS
    case SCALE
    case SCROLL
    case FAST_SCROLL
    case DRAG_SELECT
    case CONTEXT_MENU
}
