#ifndef SWEETEDITOR_JNIUTIL_H
#define SWEETEDITOR_JNIUTIL_H

#include <jni.h>
#include <memory>
#include "../core/c_wrapper.hpp"

class JObjectInvoker {
public:
  JObjectInvoker(JNIEnv* env, jobject java_obj): m_env_(env), m_java_obj_(env->NewGlobalRef(java_obj)) {
  }

  virtual ~JObjectInvoker() {
    if (m_env_ != nullptr) {
      m_env_->DeleteGlobalRef(m_java_obj_);
    }
  }

protected:
  JNIEnv* m_env_;
  jobject m_java_obj_;
};

static jboolean toJBoolean(int value) {
  return value != 0 ? JNI_TRUE : JNI_FALSE;
}

static jlong packTextPosition(size_t line, size_t column) {
  return (static_cast<jlong>(line) << 32) | (static_cast<jlong>(column) & 0xFFFFFFFFLL);
}

static jobject wrapBinaryPayload(JNIEnv* env, const uint8_t* payload, size_t size) {
  if (payload == nullptr || size == 0) {
    return nullptr;
  }
  return env->NewDirectByteBuffer(const_cast<uint8_t*>(payload), static_cast<jlong>(size));
}
#endif //SWEETEDITOR_JNIUTIL_H
