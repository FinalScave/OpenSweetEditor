#include <jni.h>
#include "jeditor.hpp"

jint JNI_OnLoad(JavaVM *javaVm, void *) {
  JNIEnv *env = nullptr;
  jint result = javaVm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6);
  if (result != JNI_OK) {
    return -1;
  }
  DocumentJni::RegisterMethods(env);
  EditorCoreJni::RegisterMethods(env);
  return JNI_VERSION_1_6;
}