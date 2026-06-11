//
// Created by Scave on 2025/12/1.
//
#ifndef SWEETEDITOR_MACRO_H
#define SWEETEDITOR_MACRO_H

#include <list>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#define NS_SWEETEDITOR sweeteditor

#if defined(__clang__)
#define SE_PROTOCOL_ANNOTATE(value) [[clang::annotate(value)]]
#else
#define SE_PROTOCOL_ANNOTATE(value)
#endif

#define SE_PROTOCOL_VALUE(domain) SE_PROTOCOL_ANNOTATE("se.protocol.value:" #domain)
#define SE_PROTOCOL_OUT(domain) SE_PROTOCOL_ANNOTATE("se.protocol.out:" #domain)
#define SE_PROTOCOL_IN(domain) SE_PROTOCOL_ANNOTATE("se.protocol.in:" #domain)
#define SE_PROTOCOL_BOTH(domain) SE_PROTOCOL_ANNOTATE("se.protocol.both:" #domain)
#define SE_PROTOCOL_ENUM(domain, fallback) SE_PROTOCOL_ANNOTATE("se.protocol.enum:" #domain ":" #fallback)
#define SE_PROTOCOL_FLAGS(domain) SE_PROTOCOL_ANNOTATE("se.protocol.flags:" #domain)
#define SE_PROTOCOL_CONSTS(domain) SE_PROTOCOL_ANNOTATE("se.protocol.consts:" #domain)
#define SE_PROTOCOL_SKIP SE_PROTOCOL_ANNOTATE("se.protocol.skip")
#define SE_PROTOCOL_WIRE(kind) SE_PROTOCOL_ANNOTATE("se.protocol.wire:" #kind)
#define SE_PROTOCOL_KEY_WIRE(kind) SE_PROTOCOL_ANNOTATE("se.protocol.key_wire:" #kind)
#define SE_PROTOCOL_VALUE_WIRE(kind) SE_PROTOCOL_ANNOTATE("se.protocol.value_wire:" #kind)
#define SE_PROTOCOL_MAP_ENTRY(key, value) SE_PROTOCOL_ANNOTATE("se.protocol.map_entry:" #key ":" #value)

namespace NS_SWEETEDITOR {
  template<typename T>
  using SharedPtr = std::shared_ptr<T>;
  template<typename T, typename... Args>
  constexpr SharedPtr<T> makeShared(Args&&... args) {
    return std::make_shared<T>(std::forward<Args>(args)...);
  }

  template<typename T>
  using UniquePtr = std::unique_ptr<T>;
  template<typename T, typename... Args>
  constexpr UniquePtr<T> makeUnique(Args&&... args) {
    return std::make_unique<T>(std::forward<Args>(args)...);
  }

  template<typename T>
  using WeakPtr = std::weak_ptr<T>;

  template<typename T>
  using Vector = std::vector<T>;
  template<typename T>
  using List = std::list<T>;
  template<typename K, typename V, typename KeyHash = std::hash<K>, typename KeyEqualTo = std::equal_to<K>>
  using HashMap = std::unordered_map<K, V, KeyHash, KeyEqualTo>;
  template<typename T, typename Hash = std::hash<T>, typename EqualTo = std::equal_to<T>>
  using HashSet = std::unordered_set<T, Hash, EqualTo>;

  using U8String = std::string;
#ifdef _WIN32
  using U16Char = wchar_t;
#define CHAR16_NONE L""
#define CHAR16(ch) L##ch
#define CHAR16_PTR(ptr) (char16_t*) ptr
#else
  using U16Char = char16_t;
#define CHAR16_NONE u""
#define CHAR16(ch) u##ch
#define CHAR16_PTR(ptr) ptr
#endif
  using U16String = std::basic_string<U16Char>;

  /// Lambda/function signature check (return type conversion allowed)
  template <typename T, typename Ret, typename... Args>
  constexpr bool kIsLambdaOrFunc = std::is_invocable_r_v<Ret, T, Args...>;

  /// Lambda signature check (return type conversion allowed)
  template <typename T, typename Ret, typename... Args>
  constexpr bool kIsLambdaWithSignature =
    std::is_class_v<T> && !std::is_function_v<T> && std::is_invocable_r_v<Ret, T, Args...>;

  /// Lambda signature check (exact return type match)
  template <typename T, typename Ret, typename... Args>
  constexpr bool kIsLambdaWithExactSignature =
    std::is_class_v<T> && !std::is_function_v<T> && std::is_invocable_v<T, Args...>
    && std::is_same_v<std::invoke_result_t<T, Args...>, Ret>;

  /// Lambda signature check (argument types only, ignore return type)
  template <typename T, typename... Args>
  constexpr bool kIsLambdaWithArgs =
    std::is_class_v<T> && !std::is_function_v<T> && std::is_invocable_v<T, Args...>;
}
#endif //SWEETEDITOR_MACRO_H
