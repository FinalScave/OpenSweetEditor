#ifndef SWEETEDITOR_NAPI_HELPER_H
#define SWEETEDITOR_NAPI_HELPER_H

#include "napi/native_api.h"
#include <cstdint>
#include <cstring>
#include <string>
#include <sweeteditor/c_api.h>
#include <sweeteditor/macro.h>

using namespace NS_SWEETEDITOR;

template<typename T>
class CPtrHolder {
public:
  explicit CPtrHolder(const SharedPtr<T>& ptr): m_ptr_(ptr) {}

  SharedPtr<T>& get() { return m_ptr_; }

private:
  SharedPtr<T> m_ptr_;
};

template<typename T, typename... Args>
intptr_t makeCPtrHolderToIntPtr(Args&&... args) {
  SharedPtr<T> ptr = makeShared<T>(std::forward<Args>(args)...);
  auto* holder = new CPtrHolder<T>(ptr);
  return reinterpret_cast<intptr_t>(holder);
}

template<typename T>
intptr_t toIntPtr(const SharedPtr<T>& ptr) {
  if (ptr == nullptr) return 0;
  auto* holder = new CPtrHolder<T>(ptr);
  return reinterpret_cast<intptr_t>(holder);
}

template<typename T>
SharedPtr<T> getCPtrHolderValue(intptr_t handle) {
  if (handle == 0) return nullptr;
  auto* holder = reinterpret_cast<CPtrHolder<T>*>(handle);
  return holder->get();
}

template<typename T>
void deleteCPtrHolder(intptr_t handle) {
  if (handle == 0) return;
  auto* holder = reinterpret_cast<CPtrHolder<T>*>(handle);
  delete holder;
}

static void release_payload(napi_env env, void* data, void* hint) {
  delete[] static_cast<uint8_t*>(data);
}

static napi_value wrap_binary_payload(napi_env env, const uint8_t* payload, size_t size) {
  if (payload == nullptr || size == 0) {
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }
  napi_value arraybuffer;
  napi_create_external_arraybuffer(env,
    const_cast<uint8_t*>(payload), size,
    release_payload, nullptr, &arraybuffer);
  return arraybuffer;
}

static int64_t napi_get_handle(napi_env env, napi_value value) {
  int64_t result = 0;
  napi_get_value_int64(env, value, &result);
  return result;
}

static int32_t napi_get_int32(napi_env env, napi_value value) {
  int32_t result = 0;
  napi_get_value_int32(env, value, &result);
  return result;
}

static double napi_get_double(napi_env env, napi_value value) {
  double result = 0;
  napi_get_value_double(env, value, &result);
  return result;
}

static float napi_get_float(napi_env env, napi_value value) {
  return static_cast<float>(napi_get_double(env, value));
}

static bool napi_get_bool(napi_env env, napi_value value) {
  bool result = false;
  napi_get_value_bool(env, value, &result);
  return result;
}

static std::string napi_get_utf8_string(napi_env env, napi_value value) {
  size_t len = 0;
  napi_get_value_string_utf8(env, value, nullptr, 0, &len);
  std::string result(len, '\0');
  napi_get_value_string_utf8(env, value, &result[0], len + 1, &len);
  return result;
}

static bool napi_is_null_or_undefined(napi_env env, napi_value value) {
  napi_valuetype type;
  napi_typeof(env, value, &type);
  return type == napi_undefined || type == napi_null;
}

static napi_value napi_create_int64_value(napi_env env, int64_t value) {
  napi_value result;
  napi_create_int64(env, value, &result);
  return result;
}

static napi_value napi_create_int32_value(napi_env env, int32_t value) {
  napi_value result;
  napi_create_int32(env, value, &result);
  return result;
}

static napi_value napi_create_double_value(napi_env env, double value) {
  napi_value result;
  napi_create_double(env, value, &result);
  return result;
}

static napi_value napi_create_bool_value(napi_env env, bool value) {
  napi_value result;
  napi_get_boolean(env, value, &result);
  return result;
}

static napi_value napi_create_string_value(napi_env env, const char* str) {
  napi_value result;
  napi_create_string_utf8(env, str ? str : "", NAPI_AUTO_LENGTH, &result);
  return result;
}

#endif // SWEETEDITOR_NAPI_HELPER_H
