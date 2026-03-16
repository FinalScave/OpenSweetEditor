// SweetEditor Demo - Cross-platform Code Editor
// Try editing this text, scrolling, and selecting!

#include <iostream>
#include <vector>
#include <string>
#include <algorithm>

namespace sweeteditor {

/// A simple 2D point structure
struct Point {
    float x = 0;
    float y = 0;

    float distance(const Point& other) const {
        float dx = x - other.x;
        float dy = y - other.y;
        return std::sqrt(dx * dx + dy * dy);
    }

    Point operator+(const Point& other) const {
        return {x + other.x, y + other.y};
    }

    Point operator*(float scalar) const {
        return {x * scalar, y * scalar};
    }
};

/// Rectangle defined by origin and size
struct Rect {
    Point origin;
    float width = 0;
    float height = 0;

    bool contains(const Point& p) const {
        return p.x >= origin.x && p.x <= origin.x + width
            && p.y >= origin.y && p.y <= origin.y + height;
    }

    float area() const { return width * height; }
};

/// Simple text buffer implementation
class TextBuffer {
public:
    TextBuffer() = default;

    explicit TextBuffer(const std::string& content) {
        std::string line;
        for (char ch : content) {
            if (ch == '\n') {
                lines_.push_back(line);
                line.clear();
            } else {
                line += ch;
            }
        }
        if (!line.empty()) {
            lines_.push_back(line);
        }
    }

    size_t lineCount() const { return lines_.size(); }

    const std::string& getLine(size_t index) const {
        static const std::string empty;
        if (index >= lines_.size()) return empty;
        return lines_[index];
    }

    void insertText(size_t line, size_t column, const std::string& text) {
        if (line >= lines_.size()) return;
        auto& target = lines_[line];
        if (column > target.size()) column = target.size();
        target.insert(column, text);
    }

    void deleteLine(size_t line) {
        if (line < lines_.size()) {
            lines_.erase(lines_.begin() + line);
        }
    }

private:
    std::vector<std::string> lines_;
};

} // namespace sweeteditor

int main() {
    using namespace sweeteditor;

    TextBuffer buffer("Hello, World!\nThis is a test.\nLine three here.");

    std::cout << "Line count: " << buffer.lineCount() << std::endl;
    for (size_t i = 0; i < buffer.lineCount(); ++i) {
        std::cout << "[" << i << "] " << buffer.getLine(i) << std::endl;
    }

    Point a{3.0f, 4.0f};
    Point b{6.0f, 8.0f};
    std::cout << "Distance: " << a.distance(b) << std::endl;

    Rect rect{{0, 0}, 10, 10};
    std::cout << "Contains (5,5): " << rect.contains({5, 5}) << std::endl;
    std::cout << "Area: " << rect.area() << std::endl;

    return 0;
}
