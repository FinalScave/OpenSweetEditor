#ifndef SWEETEDITOR_JNIUTIL_H
#define SWEETEDITOR_JNIUTIL_H

#include <jni.h>
#include <memory>
#include "internal/c_wrapper.hpp"

class JniEnvScope {
public:
  explicit JniEnvScope(JavaVM* java_vm): m_java_vm_(java_vm), m_env_(nullptr), m_attached_(false) {
    if (m_java_vm_ == nullptr) {
      return;
    }
    jint result = m_java_vm_->GetEnv(reinterpret_cast<void**>(&m_env_), JNI_VERSION_1_6);
    if (result == JNI_EDETACHED) {
      if (m_java_vm_->AttachCurrentThread(&m_env_, nullptr) == JNI_OK) {
        m_attached_ = true;
      }
    }
  }

  ~JniEnvScope() {
    if (m_attached_ && m_java_vm_ != nullptr) {
      m_java_vm_->DetachCurrentThread();
    }
  }

  JNIEnv* env() const {
    return m_env_;
  }

private:
  JavaVM* m_java_vm_;
  JNIEnv* m_env_;
  bool m_attached_;
};

class JObjectInvoker {
public:
  JObjectInvoker(JNIEnv* env, jobject java_obj): m_java_vm_(nullptr), m_java_obj_(env->NewGlobalRef(java_obj)) {
    env->GetJavaVM(&m_java_vm_);
  }

  virtual ~JObjectInvoker() {
    JniEnvScope env_scope(m_java_vm_);
    JNIEnv* env = env_scope.env();
    if (env != nullptr && m_java_obj_ != nullptr) {
      env->DeleteGlobalRef(m_java_obj_);
    }
  }

protected:
  JniEnvScope makeEnvScope() const {
    return JniEnvScope(m_java_vm_);
  }

  JavaVM* m_java_vm_;
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
