#ifdef _WIN32
#include <windows.h>
#endif

#include <catch2/catch_amalgamated.hpp>

int main(int argc, char* argv[]) {
#ifdef _WIN32
  SetConsoleOutputCP(CP_UTF8);
  SetConsoleCP(CP_UTF8);
#endif
  Catch::Session session;
  int code = session.applyCommandLine(argc, argv);
  if (code != 0) {
    return code;
  }
  return session.run();
}