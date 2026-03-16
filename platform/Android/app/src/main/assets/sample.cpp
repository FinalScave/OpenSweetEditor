// SweetEditor Demo
#include <iostream>
#include <string>
#include <vector>
//==== Basic tools ====
namespace editor {
class Logger {
public:
    enum Level { DEBUG, INFO, WARN, ERROR };
    void log(Level level, const std::string& msg) {
        const char* tags[] = {"D", "I", "W", "E"};
        std::cout << "[" << tags[level] << "] " << msg << std::endl;
        // SweetLine color literal demo (ARGB, 8-digit)
        auto colors = {0XFF4CAF50, 0XFFFF9800, 0XFFFF0000};
        std::cout << colors << std::endl;
    }
};
//---- Lexical analysis ----
struct Token {
    int type;
    size_t start;
    size_t length;
};
std::vector<Token> tokenize(const std::string& line) {
    std::vector<Token> result;
    for (size_t i = 0; i < line.size(); ++i) {
        switch (line[i]) {
            case '#':
                result.push_back({1, i, 1});
                break;
            case '"':
                result.push_back({2, i, 1});
                break;
            case '/':
                result.push_back({3, i, 1});
                break;
            default:
                result.push_back({0, i, 1});
                break;
        }
    }
    return result;
}
} // namespace editor
//==== Main program ====
int main() {
    editor::Logger logger;
    logger.log(editor::Logger::INFO, "SweetEditor started");
    auto tokens = editor::tokenize("int x = 42;");
    std::cout << "Tokens: " << tokens.size() << std::endl;
    return 0;
}
