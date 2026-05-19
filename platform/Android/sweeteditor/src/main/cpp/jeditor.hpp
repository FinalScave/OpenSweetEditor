#ifndef SWEETEDITOR_JEDITOR_HPP
#define SWEETEDITOR_JEDITOR_HPP

#include <jni.h>
#include <vector>
#include <cstring>
#include <editor_core.h>
#include <document.h>
#include "jni_helper.h"

using namespace NS_SWEETEDITOR;

// ====================================== DocumentJni ===========================================
class DocumentJni {
public:
  static jlong makeStringDocument(JNIEnv* env, jclass clazz, jstring text) {
    const char* content_str = env->GetStringUTFChars(text, nullptr);
    SharedPtr<Document> document = makeShared<LineArrayDocument>(content_str);
    env->ReleaseStringUTFChars(text, content_str);
    return toIntPtr(document);
  }

  static jlong makeFileDocument(JNIEnv* env, jclass clazz, jstring path) {
    const char* path_str = env->GetStringUTFChars(path, nullptr);
    UniquePtr<Buffer> buffer = makeUnique<MappedFileBuffer>(path_str);
    env->ReleaseStringUTFChars(path, path_str);
    SharedPtr<Document> document = makeShared<LineArrayDocument>(std::move(buffer));
    return toIntPtr(document);
  }

  static void finalizeDocument(jlong handle) {
    deleteCPtrHolder<Document>(handle);
  }

  static jstring getText(JNIEnv* env, jclass clazz, jlong handle) {
    SharedPtr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return env->NewStringUTF("");
    }
    return env->NewStringUTF(document->getU8Text().c_str());
  }

  static jint getLineCount(jlong handle) {
    SharedPtr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return 0;
    }
    return static_cast<jint>(document->getLineCount());
  }

  static jstring getLineText(JNIEnv* env, jclass clazz, jlong handle, jint line) {
    SharedPtr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return env->NewStringUTF("");
    }
    U16String u16_text = document->getLineU16Text(line);
    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(u16_text, u8_text);
    return env->NewStringUTF(u8_text.c_str());
  }

  static jlong getPositionFromCharIndex(jlong handle, jint index) {
    SharedPtr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return 0;
    }
    TextPosition position = document->getPositionFromCharIndex(index);
    jlong line = (jlong)position.line;
    jlong column = (jlong)position.column;
    return (line << 32) | (column & 0XFFFFFFFFLL);
  }

  static jint getCharIndexFromPosition(jlong handle, jlong position) {
    SharedPtr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return 0;
    }
    size_t line = (size_t)(jint)(position >> 32);
    size_t column = (size_t)(jint)(position & 0XFFFFFFFF);
    return (jint)document->getCharIndexFromPosition({line, column});
  }

  constexpr static const char *kJClassName = "com/qiplat/sweeteditor/core/Document";
  constexpr static const JNINativeMethod kJMethods[] = {
      {"nativeMakeStringDocument", "(Ljava/lang/String;)J", (void*) makeStringDocument},
      {"nativeMakeFileDocument", "(Ljava/lang/String;)J", (void*) makeFileDocument},
      {"nativeFinalizeDocument", "(J)V", (void*) finalizeDocument},
      {"nativeGetText", "(J)Ljava/lang/String;", (void*) getText},
      {"nativeGetLineCount", "(J)I", (void*) getLineCount},
      {"nativeGetLineText", "(JI)Ljava/lang/String;", (void*) getLineText},
      {"nativeCharIndexOfPosition", "(JJ)I", (void*) getCharIndexFromPosition},
      {"nativePositionOfCharIndex", "(JI)J", (void*) getPositionFromCharIndex},
  };

  static void RegisterMethods(JNIEnv *env) {
    jclass java_class = env->FindClass(kJClassName);
    env->RegisterNatives(java_class, kJMethods,
                         sizeof(kJMethods) / sizeof(JNINativeMethod));
  }
};

// ====================================== AndroidTextMeasurer ===========================================
class AndroidTextMeasurer : public TextMeasurer, public JObjectInvoker {
public:
  AndroidTextMeasurer(JNIEnv* env, jobject measurer): JObjectInvoker(env, measurer) {
    if (m_jclass_TextMeasurer_ == nullptr) {
      m_jclass_TextMeasurer_ = (jclass)env->NewGlobalRef(env->FindClass("com/qiplat/sweeteditor/core/TextMeasurer"));
    }
    if (m_jmethod_measureWidth_ == nullptr) {
      m_jmethod_measureWidth_ = env->GetMethodID(m_jclass_TextMeasurer_,
                                                "measureWidth","(Ljava/lang/String;I)F");
    }
    if (m_jmethod_measureInlayHintWidth_ == nullptr) {
      m_jmethod_measureInlayHintWidth_ = env->GetMethodID(m_jclass_TextMeasurer_,
                                                "measureInlayHintWidth","(Ljava/lang/String;)F");
    }
    if (m_jmethod_measureIconWidth_ == nullptr) {
      m_jmethod_measureIconWidth_ = env->GetMethodID(m_jclass_TextMeasurer_,
                                                "measureIconWidth","(I)F");
    }
    if (m_jmethod_getFontHeight_ == nullptr) {
      m_jmethod_getFontHeight_ = env->GetMethodID(m_jclass_TextMeasurer_,
                                                 "getFontHeight", "()F");
    }
    if (m_jmethod_getFontAscent_ == nullptr) {
      m_jmethod_getFontAscent_ = env->GetMethodID(m_jclass_TextMeasurer_,
                                                 "getFontAscent", "()F");
    }
    if (m_jmethod_getFontDescent_ == nullptr) {
      m_jmethod_getFontDescent_ = env->GetMethodID(m_jclass_TextMeasurer_,
                                                  "getFontDescent", "()F");
    }
  }

  float measureWidth(const U16String &text, int32_t font_style) override {
    JniEnvScope env_scope = makeEnvScope();
    JNIEnv* env = env_scope.env();
    if (env == nullptr) {
      return 0.0f;
    }
    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(text, u8_text);
    jstring java_text = env->NewStringUTF(u8_text.c_str());
    float result = env->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,
                                                  m_jmethod_measureWidth_, java_text, (jint)font_style);
    env->DeleteLocalRef(java_text);
    return result;
  }

  float measureInlayHintWidth(const U16String &text) override {
    JniEnvScope env_scope = makeEnvScope();
    JNIEnv* env = env_scope.env();
    if (env == nullptr) {
      return 0.0f;
    }
    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(text, u8_text);
    jstring java_text = env->NewStringUTF(u8_text.c_str());
    float result = env->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,
                                                  m_jmethod_measureInlayHintWidth_, java_text);
    env->DeleteLocalRef(java_text);
    return result;
  }

  float measureIconWidth(int32_t icon_id) override {
    JniEnvScope env_scope = makeEnvScope();
    JNIEnv* env = env_scope.env();
    if (env == nullptr) {
      return 0.0f;
    }
    return env->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,
                                          m_jmethod_measureIconWidth_, (jint)icon_id);
  }

  FontMetrics getFontMetrics() override {
    JniEnvScope env_scope = makeEnvScope();
    JNIEnv* env = env_scope.env();
    if (env == nullptr) {
      return {0.0f, 0.0f};
    }
    float ascent = env->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,m_jmethod_getFontAscent_);
    float descent = env->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,m_jmethod_getFontDescent_);
    return {ascent, descent};
  }

private:
  static jclass m_jclass_TextMeasurer_;
  static jmethodID m_jmethod_measureWidth_;
  static jmethodID m_jmethod_measureInlayHintWidth_;
  static jmethodID m_jmethod_measureIconWidth_;
  static jmethodID m_jmethod_getFontHeight_;
  static jmethodID m_jmethod_getFontAscent_;
  static jmethodID m_jmethod_getFontDescent_;
};
jclass AndroidTextMeasurer::m_jclass_TextMeasurer_ = nullptr;
jmethodID AndroidTextMeasurer::m_jmethod_measureWidth_ = nullptr;
jmethodID AndroidTextMeasurer::m_jmethod_measureInlayHintWidth_ = nullptr;
jmethodID AndroidTextMeasurer::m_jmethod_measureIconWidth_ = nullptr;
jmethodID AndroidTextMeasurer::m_jmethod_getFontHeight_ = nullptr;
jmethodID AndroidTextMeasurer::m_jmethod_getFontAscent_ = nullptr;
jmethodID AndroidTextMeasurer::m_jmethod_getFontDescent_ = nullptr;

// ====================================== EditorCoreJni ===========================================
class EditorCoreJni {
public:
  static jlong makeEditorCore(JNIEnv* env, jclass clazz, jobject measurer, jobject options_buffer, jint options_size) {
    // Zero-copy decode: get direct ByteBuffer address
    EditorOptions editor_options;
    if (options_buffer != nullptr && options_size >= 40) {
      auto* data_ptr = reinterpret_cast<const uint8_t*>(env->GetDirectBufferAddress(options_buffer));
      if (data_ptr != nullptr) {
        size_t offset = 0;
        std::memcpy(&editor_options.touch_slop, data_ptr + offset, sizeof(float)); offset += sizeof(float);
        std::memcpy(&editor_options.double_tap_timeout, data_ptr + offset, sizeof(int64_t)); offset += sizeof(int64_t);
        std::memcpy(&editor_options.long_press_ms, data_ptr + offset, sizeof(int64_t)); offset += sizeof(int64_t);
        std::memcpy(&editor_options.fling_friction, data_ptr + offset, sizeof(float)); offset += sizeof(float);
        std::memcpy(&editor_options.fling_min_velocity, data_ptr + offset, sizeof(float)); offset += sizeof(float);
        std::memcpy(&editor_options.fling_max_velocity, data_ptr + offset, sizeof(float)); offset += sizeof(float);
        uint64_t max_undo = 0;
        std::memcpy(&max_undo, data_ptr + offset, sizeof(uint64_t)); offset += sizeof(uint64_t);
        editor_options.max_undo_stack_size = static_cast<size_t>(max_undo);
        if (offset + sizeof(int64_t) <= static_cast<size_t>(options_size)) {
          std::memcpy(&editor_options.key_chord_timeout_ms, data_ptr + offset, sizeof(int64_t));
          offset += sizeof(int64_t);
        }
        if (offset + sizeof(uint8_t) <= static_cast<size_t>(options_size)) {
          editor_options.reveal_selection_end_on_select_all = data_ptr[offset] != 0;
        }
      }
    }
    SharedPtr<TextMeasurer> native_measurer = makeShared<AndroidTextMeasurer>(env, measurer);
    auto handle = makeCPtrHolderToIntPtr<EditorCore>(native_measurer, editor_options);
    return handle;
  }

  static void finalizeEditorCore(jlong handle) {
    deleteCPtrHolder<EditorCore>(handle);
  }

  using HandleAction = const uint8_t* (*)(intptr_t, size_t*);
  using BufferAction = const uint8_t* (*)(intptr_t, const uint8_t*, size_t, size_t*);
  using LineAction = const uint8_t* (*)(intptr_t, size_t, size_t*);

  static jobject wrapHandleAction(JNIEnv* env, jlong handle, HandleAction action) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = action(static_cast<intptr_t>(handle), &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject wrapBufferAction(JNIEnv* env, jlong handle, jobject buffer, jint size, BufferAction action) {
    if (handle == 0 || buffer == nullptr || size <= 0) return nullptr;
    void* ptr = env->GetDirectBufferAddress(buffer);
    jlong capacity = env->GetDirectBufferCapacity(buffer);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = action(static_cast<intptr_t>(handle),
                                    reinterpret_cast<const uint8_t*>(ptr),
                                    static_cast<size_t>(size),
                                    &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject wrapLineAction(JNIEnv* env, jlong handle, jint line, LineAction action) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = action(static_cast<intptr_t>(handle),
                                    static_cast<size_t>(line),
                                    &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setViewport(JNIEnv* env, jclass clazz, jlong handle, jint width, jint height) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = set_editor_viewport(static_cast<intptr_t>(handle),
                                                 static_cast<int16_t>(width),
                                                 static_cast<int16_t>(height),
                                                 &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject loadDocument(JNIEnv* env, jclass clazz, jlong handle, jlong doc_handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = set_editor_document(static_cast<intptr_t>(handle),
                                                 static_cast<intptr_t>(doc_handle),
                                                 &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject handleGestureEvent(JNIEnv* env, jclass clazz, jlong handle, jint type, jint pointer_count, jfloatArray points) {
    if (handle == 0 || (pointer_count > 0 && points == nullptr)) {
      return nullptr;
    }
    size_t out_size = 0;
    jfloat* points_arr = points != nullptr ? env->GetFloatArrayElements(points, nullptr) : nullptr;
    const uint8_t* payload = handle_editor_gesture_event(static_cast<intptr_t>(handle),
                                                         static_cast<uint8_t>(type),
                                                         static_cast<uint8_t>(pointer_count),
                                                         points_arr,
                                                         &out_size);
    if (points != nullptr && points_arr != nullptr) {
      env->ReleaseFloatArrayElements(points, points_arr, JNI_ABORT);
    }
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject handleGestureEventEx(JNIEnv* env, jclass clazz, jlong handle, jint type, jint pointer_count,
                                      jfloatArray points, jint modifiers, jfloat wheel_delta_x,
                                      jfloat wheel_delta_y, jfloat direct_scale) {
    if (handle == 0 || (pointer_count > 0 && points == nullptr)) {
      return nullptr;
    }
    size_t out_size = 0;
    jfloat* points_arr = points != nullptr ? env->GetFloatArrayElements(points, nullptr) : nullptr;
    const uint8_t* payload = handle_editor_gesture_event_ex(
        static_cast<intptr_t>(handle),
        static_cast<uint8_t>(type),
        static_cast<uint8_t>(pointer_count),
        points_arr,
        static_cast<uint8_t>(modifiers),
        static_cast<float>(wheel_delta_x),
        static_cast<float>(wheel_delta_y),
        static_cast<float>(direct_scale),
        &out_size);
    if (points != nullptr && points_arr != nullptr) {
      env->ReleaseFloatArrayElements(points, points_arr, JNI_ABORT);
    }
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject onFontMetricsChanged(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_on_font_metrics_changed(static_cast<intptr_t>(handle), &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject tickEdgeScroll(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_tick_edge_scroll(static_cast<intptr_t>(handle), &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject tickFling(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_tick_fling(static_cast<intptr_t>(handle), &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject tickAnimations(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_tick_animations(static_cast<intptr_t>(handle), &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject buildRenderModel(JNIEnv* env, jclass clazz, jlong handle) {
    size_t out_size = 0;
    return wrapBinaryPayload(env, build_editor_render_model(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject getLayoutMetrics(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, get_layout_metrics(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject handleKeyEvent(JNIEnv* env, jclass clazz, jlong handle, jint key_code, jstring text, jint modifiers) {
    if (handle == 0) {
      return nullptr;
    }
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : nullptr;
    size_t out_size = 0;
    const uint8_t* payload = handle_editor_key_event(static_cast<intptr_t>(handle),
                                                     static_cast<uint16_t>(key_code),
                                                     text_str,
                                                     static_cast<uint8_t>(modifiers),
                                                     &out_size);
    if (text != nullptr) {
      env->ReleaseStringUTFChars(text, text_str);
    }
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setKeyMap(JNIEnv* env, jclass clazz, jlong handle, jobject buffer) {
    if (handle == 0 || buffer == nullptr) return nullptr;
    auto* data = static_cast<const uint8_t*>(env->GetDirectBufferAddress(buffer));
    jlong capacity = env->GetDirectBufferCapacity(buffer);
    if (data == nullptr || capacity <= 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_keymap(static_cast<intptr_t>(handle),
                                               data,
                                               static_cast<size_t>(capacity),
                                               &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject insertText(JNIEnv* env, jclass clazz, jlong handle, jstring text) {
    if (handle == 0 || text == nullptr) return nullptr;
    const char* text_str = env->GetStringUTFChars(text, JNI_FALSE);
    size_t out_size = 0;
    const uint8_t* payload = editor_insert_text(static_cast<intptr_t>(handle), text_str, &out_size);
    env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject replaceText(JNIEnv* env, jclass clazz, jlong handle,
      jint startLine, jint startColumn, jint endLine, jint endColumn, jstring text) {
    if (handle == 0 || text == nullptr) return nullptr;
    const char* text_str = env->GetStringUTFChars(text, JNI_FALSE);
    size_t out_size = 0;
    const uint8_t* payload = editor_replace_text(static_cast<intptr_t>(handle),
                                                 static_cast<size_t>(startLine),
                                                 static_cast<size_t>(startColumn),
                                                 static_cast<size_t>(endLine),
                                                 static_cast<size_t>(endColumn),
                                                 text_str,
                                                 &out_size);
    env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject deleteText(JNIEnv* env, jclass clazz, jlong handle,
      jint startLine, jint startColumn, jint endLine, jint endColumn) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_delete_text(static_cast<intptr_t>(handle),
                                                static_cast<size_t>(startLine),
                                                static_cast<size_t>(startColumn),
                                                static_cast<size_t>(endLine),
                                                static_cast<size_t>(endColumn),
                                                &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject moveLineUp(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_move_line_up(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject moveLineDown(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_move_line_down(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject copyLineUp(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_copy_line_up(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject copyLineDown(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_copy_line_down(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject deleteLine(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_delete_line(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject insertLineAbove(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_insert_line_above(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject insertLineBelow(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_insert_line_below(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jstring getSelectedText(JNIEnv* env, jclass clazz, jlong handle) {
    SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(handle);
    if (editor_core == nullptr) {
      return env->NewStringUTF("");
    }
    U8String selected = editor_core->getSelectedText();
    return env->NewStringUTF(selected.c_str());
  }

  static jboolean isComposing(jlong handle) {
    return toJBoolean(editor_is_composing(static_cast<intptr_t>(handle)));
  }

  static jlongArray getComposingRange(JNIEnv* env, jclass clazz, jlong handle) {
    int32_t start_line = -1;
    int32_t start_column = -1;
    int32_t end_line = -1;
    int32_t end_column = -1;
    editor_get_composing_range(static_cast<intptr_t>(handle),
                               &start_line,
                               &start_column,
                               &end_line,
                               &end_column);
    jlong values[4] = {start_line, start_column, end_line, end_column};
    jlongArray result = env->NewLongArray(4);
    env->SetLongArrayRegion(result, 0, 4, values);
    return result;
  }

  static jlongArray getComposingSessionRange(JNIEnv* env, jclass clazz, jlong handle) {
    int32_t start_line = -1;
    int32_t start_column = -1;
    int32_t end_line = -1;
    int32_t end_column = -1;
    editor_get_composing_session_range(static_cast<intptr_t>(handle),
                                       &start_line,
                                       &start_column,
                                       &end_line,
                                       &end_column);
    jlong values[4] = {start_line, start_column, end_line, end_column};
    jlongArray result = env->NewLongArray(4);
    env->SetLongArrayRegion(result, 0, 4, values);
    return result;
  }

  static jobject imeUpdatePreedit(JNIEnv* env, jclass clazz, jlong handle, jstring text, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_update_preedit(static_cast<intptr_t>(handle),
                                                       text_str,
                                                       static_cast<int>(scriptHint),
                                                       &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeSetComposingText(JNIEnv* env, jclass clazz, jlong handle, jstring text,
                                     jint cursorOffset, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_set_composing_text(static_cast<intptr_t>(handle),
                                                           text_str,
                                                           static_cast<int>(cursorOffset),
                                                           static_cast<int>(scriptHint),
                                                           &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeCommitText(JNIEnv* env, jclass clazz, jlong handle, jstring text, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_commit_text(static_cast<intptr_t>(handle),
                                                    text_str,
                                                    static_cast<int>(scriptHint),
                                                    &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeCommitTextWithCursor(JNIEnv* env, jclass clazz, jlong handle, jstring text,
                                         jint cursorOffset, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_commit_text_with_cursor(static_cast<intptr_t>(handle),
                                                                text_str,
                                                                static_cast<int>(cursorOffset),
                                                                static_cast<int>(scriptHint),
                                                                &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeFinishPreedit(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_ime_finish_preedit(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject imeCancelPreedit(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_ime_cancel_preedit(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject imeMarkDocumentRange(JNIEnv* env, jclass clazz, jlong handle,
                                      jlong startLine, jlong startColumn, jlong endLine, jlong endColumn,
                                      jint scriptHint) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_mark_document_range(static_cast<intptr_t>(handle),
                                                            static_cast<size_t>(startLine),
                                                            static_cast<size_t>(startColumn),
                                                            static_cast<size_t>(endLine),
                                                            static_cast<size_t>(endColumn),
                                                            static_cast<int>(scriptHint),
                                                            &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeMarkDocumentRangeByOffset(JNIEnv* env, jclass clazz, jlong handle,
                                              jlong startOffset, jlong endOffset, jint scriptHint) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_mark_document_range_by_offset(static_cast<intptr_t>(handle),
                                                                      static_cast<size_t>(startOffset),
                                                                      static_cast<size_t>(endOffset),
                                                                      static_cast<int>(scriptHint),
                                                                      &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeReplaceText(JNIEnv* env, jclass clazz, jlong handle,
                                jlong startLine, jlong startColumn, jlong endLine, jlong endColumn,
                                jstring text, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_replace_text(static_cast<intptr_t>(handle),
                                                     static_cast<size_t>(startLine),
                                                     static_cast<size_t>(startColumn),
                                                     static_cast<size_t>(endLine),
                                                     static_cast<size_t>(endColumn),
                                                     text_str,
                                                     static_cast<int>(scriptHint),
                                                     &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeReplaceDocumentText(JNIEnv* env, jclass clazz, jlong handle,
                                        jlong startOffset, jlong endOffset, jstring text,
                                        jint cursorOffset, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_replace_document_text(static_cast<intptr_t>(handle),
                                                             static_cast<size_t>(startOffset),
                                                             static_cast<size_t>(endOffset),
                                                             text_str,
                                                             static_cast<int>(cursorOffset),
                                                             static_cast<int>(scriptHint),
                                                             &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeReplaceInputContextText(JNIEnv* env, jclass clazz, jlong handle,
                                            jlong startOffset, jlong endOffset, jstring text,
                                            jint cursorOffset, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_replace_input_context_text(static_cast<intptr_t>(handle),
                                                                   static_cast<size_t>(startOffset),
                                                                   static_cast<size_t>(endOffset),
                                                                   text_str,
                                                                   static_cast<int>(cursorOffset),
                                                                   static_cast<int>(scriptHint),
                                                                   &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeMarkInputContextRange(JNIEnv* env, jclass clazz, jlong handle,
                                          jlong startOffset, jlong endOffset, jint scriptHint) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_mark_input_context_range(static_cast<intptr_t>(handle),
                                                                 static_cast<size_t>(startOffset),
                                                                 static_cast<size_t>(endOffset),
                                                                 static_cast<int>(scriptHint),
                                                                 &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeNotifyDocumentSelectionChanged(JNIEnv* env, jclass clazz, jlong handle,
                                                   jlong startOffset, jlong endOffset) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_notify_document_selection_changed(
        static_cast<intptr_t>(handle),
        static_cast<size_t>(startOffset),
        static_cast<size_t>(endOffset),
        &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeNotifyInputContextSelectionChanged(JNIEnv* env, jclass clazz, jlong handle,
                                                       jlong startOffset, jlong endOffset) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_notify_input_context_selection_changed(
        static_cast<intptr_t>(handle),
        static_cast<size_t>(startOffset),
        static_cast<size_t>(endOffset),
        &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeUpdateInputStateText(JNIEnv* env, jclass clazz, jlong handle,
                                         jlong contextId, jint documentStartOffset, jstring text,
                                         jint selectionStartOffset, jint selectionEndOffset,
                                         jint composingStartOffset, jint composingEndOffset,
                                         jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_update_input_state_text(
        static_cast<intptr_t>(handle),
        static_cast<uint64_t>(contextId),
        static_cast<int32_t>(documentStartOffset),
        text_str,
        static_cast<int32_t>(selectionStartOffset),
        static_cast<int32_t>(selectionEndOffset),
        static_cast<int32_t>(composingStartOffset),
        static_cast<int32_t>(composingEndOffset),
        static_cast<int>(scriptHint),
        &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeUpdateInputStateSelection(JNIEnv* env, jclass clazz, jlong handle,
                                              jlong contextId, jint documentStartOffset,
                                              jint selectionStartOffset, jint selectionEndOffset) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_update_input_state_selection(
        static_cast<intptr_t>(handle),
        static_cast<uint64_t>(contextId),
        static_cast<int32_t>(documentStartOffset),
        static_cast<int32_t>(selectionStartOffset),
        static_cast<int32_t>(selectionEndOffset),
        &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeReplaceInputStateText(JNIEnv* env, jclass clazz, jlong handle,
                                          jlong contextId, jint documentStartOffset,
                                          jlong startOffset, jlong endOffset, jstring text,
                                          jint cursorOffset, jint scriptHint) {
    if (handle == 0) return nullptr;
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_replace_input_state_text(
        static_cast<intptr_t>(handle),
        static_cast<uint64_t>(contextId),
        static_cast<int32_t>(documentStartOffset),
        static_cast<size_t>(startOffset),
        static_cast<size_t>(endOffset),
        text_str,
        static_cast<int>(cursorOffset),
        static_cast<int>(scriptHint),
        &out_size);
    if (text != nullptr) env->ReleaseStringUTFChars(text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeDeleteBackward(JNIEnv* env, jclass clazz, jlong handle, jlong beforeLength, jint textUnit) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_delete_backward(static_cast<intptr_t>(handle),
                                                        static_cast<size_t>(beforeLength),
                                                        static_cast<int>(textUnit),
                                                        &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeDeleteForward(JNIEnv* env, jclass clazz, jlong handle, jlong afterLength, jint textUnit) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_delete_forward(static_cast<intptr_t>(handle),
                                                       static_cast<size_t>(afterLength),
                                                       static_cast<int>(textUnit),
                                                       &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeDeleteSurrounding(JNIEnv* env, jclass clazz, jlong handle,
                                      jlong beforeLength, jlong afterLength, jint textUnit) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_delete_surrounding(static_cast<intptr_t>(handle),
                                                           static_cast<size_t>(beforeLength),
                                                           static_cast<size_t>(afterLength),
                                                           static_cast<int>(textUnit),
                                                            &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeNotifySelectionChanged(JNIEnv* env, jclass clazz, jlong handle,
                                           jlong startLine, jlong startColumn,
                                           jlong endLine, jlong endColumn) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_notify_selection_changed(static_cast<intptr_t>(handle),
                                                                 static_cast<size_t>(startLine),
                                                                 static_cast<size_t>(startColumn),
                                                                 static_cast<size_t>(endLine),
                                                                 static_cast<size_t>(endColumn),
                                                                 &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeNotifyCursorChanged(JNIEnv* env, jclass clazz, jlong handle,
                                        jlong cursorLine, jlong cursorColumn) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_notify_cursor_changed(static_cast<intptr_t>(handle),
                                                              static_cast<size_t>(cursorLine),
                                                              static_cast<size_t>(cursorColumn),
                                                              &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject imeSetKeyboardScriptClass(JNIEnv* env, jclass clazz, jlong handle, jint scriptClass) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_ime_set_keyboard_script_class(static_cast<intptr_t>(handle),
                                                                  static_cast<int>(scriptClass),
                                                                  &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jint imeGetKeyboardScriptClass(jlong handle) {
    return static_cast<jint>(editor_ime_get_keyboard_script_class(static_cast<intptr_t>(handle)));
  }

  static jobject getImeSyncSnapshot(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_get_ime_sync_snapshot(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject getImeInputContext(JNIEnv* env, jclass clazz, jlong handle,
                                    jlong beforeLength, jlong afterLength) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_get_ime_input_context(static_cast<intptr_t>(handle),
                                                         static_cast<size_t>(beforeLength),
                                                         static_cast<size_t>(afterLength),
                                                         &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setReadOnly(JNIEnv* env, jclass clazz, jlong handle, jboolean readOnly) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_read_only(static_cast<intptr_t>(handle),
                                                  readOnly == JNI_TRUE ? 1 : 0,
                                                  &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jboolean isReadOnly(jlong handle) {
    return toJBoolean(editor_is_read_only(static_cast<intptr_t>(handle)));
  }

  static jobject setAutoIndentMode(JNIEnv* env, jclass clazz, jlong handle, jint mode) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_auto_indent_mode(static_cast<intptr_t>(handle),
                                                         static_cast<int>(mode),
                                                         &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jint getAutoIndentMode(jlong handle) {
    return static_cast<jint>(editor_get_auto_indent_mode(static_cast<intptr_t>(handle)));
  }

  static jobject setBackspaceUnindent(JNIEnv* env, jclass clazz, jlong handle, jboolean enabled) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_backspace_unindent(static_cast<intptr_t>(handle),
                                                           enabled ? 1 : 0,
                                                           &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setInsertSpaces(JNIEnv* env, jclass clazz, jlong handle, jboolean enabled) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_insert_spaces(static_cast<intptr_t>(handle),
                                                      enabled ? 1 : 0,
                                                      &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setHandleConfig(JNIEnv* env, jclass clazz, jlong handle,
      jfloat startLeft, jfloat startTop, jfloat startRight, jfloat startBottom,
      jfloat endLeft, jfloat endTop, jfloat endRight, jfloat endBottom) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_handle_config(static_cast<intptr_t>(handle),
        startLeft, startTop, startRight, startBottom,
        endLeft, endTop, endRight, endBottom, &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setScrollbarConfig(JNIEnv* env, jclass clazz, jlong handle, jfloat thickness, jfloat minThumb, jfloat thumbHitPadding,
                                 jint mode, jboolean thumbDraggable, jint trackTapMode,
                                 jint fadeDelayMs, jint fadeDurationMs) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_scrollbar_config(static_cast<intptr_t>(handle),
                                thickness, minThumb, thumbHitPadding,
                                static_cast<int>(mode),
                                thumbDraggable == JNI_TRUE ? 1 : 0,
                                static_cast<int>(trackTapMode),
                                static_cast<int>(fadeDelayMs),
                                static_cast<int>(fadeDurationMs),
                                &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jfloatArray getPositionRect(JNIEnv* env, jclass clazz, jlong handle, jint line, jint column) {
    jfloatArray result = env->NewFloatArray(3);
    float x = 0;
    float y = 0;
    float height = 0;
    editor_get_position_rect(static_cast<intptr_t>(handle), static_cast<size_t>(line), static_cast<size_t>(column), &x, &y, &height);
    jfloat data[3] = {x, y, height};
    env->SetFloatArrayRegion(result, 0, 3, data);
    return result;
  }

  static jfloatArray getCursorRect(JNIEnv* env, jclass clazz, jlong handle) {
    jfloatArray result = env->NewFloatArray(3);
    float x = 0;
    float y = 0;
    float height = 0;
    editor_get_cursor_rect(static_cast<intptr_t>(handle), &x, &y, &height);
    jfloat data[3] = {x, y, height};
    env->SetFloatArrayRegion(result, 0, 3, data);
    return result;
  }

  static jobject registerTextStyle(JNIEnv* env, jclass clazz, jlong handle, jint styleId, jint color, jint backgroundColor, jint fontStyle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_register_text_style(static_cast<intptr_t>(handle),
                               static_cast<uint32_t>(styleId),
                               static_cast<int32_t>(color),
                               static_cast<int32_t>(backgroundColor),
                               static_cast<int32_t>(fontStyle),
                               &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject registerBatchTextStyles(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_register_batch_text_styles);
  }

  static jobject setLineSpans(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_line_spans);
  }

  static jobject setLineInlayHints(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_line_inlay_hints);
  }

  static jobject setLinePhantomTexts(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    return wrapBufferAction(env, handle, buffer, size, editor_set_line_phantom_texts);
  }

  static jobject clearHighlights(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_highlights);
  }

  static jobject clearHighlightsLayer(JNIEnv* env, jclass clazz, jlong handle, jint layer) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_clear_highlights_layer(static_cast<intptr_t>(handle),
                                                           static_cast<uint8_t>(layer),
                                                           &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject clearLineSpans(JNIEnv* env, jclass clazz, jlong handle, jint line, jint layer) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_clear_line_spans(static_cast<intptr_t>(handle),
                                                     static_cast<size_t>(line),
                                                     static_cast<uint8_t>(layer),
                                                     &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject clearInlayHints(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_inlay_hints);
  }

  static jobject clearPhantomTexts(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_phantom_texts);
  }

  static jobject clearGutterIcons(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_gutter_icons);
  }

  static jobject clearCodeLens(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_codelens);
  }

  static jobject clearLinks(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_links);
  }

  static jobject clearGuides(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_guides);
  }

  static jobject clearAllDecorations(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_all_decorations);
  }

  static jobject setIndentGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    return wrapBufferAction(env, handle, buffer, size, editor_set_indent_guides);
  }

  static jobject setBracketGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    return wrapBufferAction(env, handle, buffer, size, editor_set_bracket_guides);
  }

  static jobject setFlowGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    return wrapBufferAction(env, handle, buffer, size, editor_set_flow_guides);
  }

  static jobject setSeparatorGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    return wrapBufferAction(env, handle, buffer, size, editor_set_separator_guides);
  }

  static jobject setBracketPairs(JNIEnv* env, jclass clazz, jlong handle, jintArray openChars, jintArray closeChars) {
    if (handle == 0 || openChars == nullptr || closeChars == nullptr) return nullptr;
    jsize count = env->GetArrayLength(openChars);
    jint* opens = env->GetIntArrayElements(openChars, nullptr);
    jint* closes = env->GetIntArrayElements(closeChars, nullptr);
    size_t out_size = 0;
    const uint8_t* payload = editor_set_bracket_pairs(static_cast<intptr_t>(handle),
                                                      reinterpret_cast<const uint32_t*>(opens),
                                                      reinterpret_cast<const uint32_t*>(closes),
                                                      static_cast<size_t>(count),
                                                      &out_size);
    env->ReleaseIntArrayElements(openChars, opens, JNI_ABORT);
    env->ReleaseIntArrayElements(closeChars, closes, JNI_ABORT);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setAutoClosingPairs(JNIEnv* env, jclass clazz, jlong handle, jintArray openChars, jintArray closeChars) {
    if (handle == 0 || openChars == nullptr || closeChars == nullptr) return nullptr;
    jsize count = env->GetArrayLength(openChars);
    jint* opens = env->GetIntArrayElements(openChars, nullptr);
    jint* closes = env->GetIntArrayElements(closeChars, nullptr);
    size_t out_size = 0;
    const uint8_t* payload = editor_set_auto_closing_pairs(static_cast<intptr_t>(handle),
                                                           reinterpret_cast<const uint32_t*>(opens),
                                                           reinterpret_cast<const uint32_t*>(closes),
                                                           static_cast<size_t>(count),
                                                           &out_size);
    env->ReleaseIntArrayElements(openChars, opens, JNI_ABORT);
    env->ReleaseIntArrayElements(closeChars, closes, JNI_ABORT);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setMatchedBrackets(JNIEnv* env, jclass clazz, jlong handle, jint openLine, jint openCol, jint closeLine, jint closeCol) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_matched_brackets(static_cast<intptr_t>(handle),
                                                         static_cast<size_t>(openLine),
                                                         static_cast<size_t>(openCol),
                                                         static_cast<size_t>(closeLine),
                                                         static_cast<size_t>(closeCol),
                                                         &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject clearMatchedBrackets(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_matched_brackets);
  }

  static jobject setLineDiagnostics(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_line_diagnostics);
  }

  static jobject clearDiagnostics(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_clear_diagnostics);
  }

  // ==================== Set line decorations in batch ====================

  static jobject setBatchLineSpans(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_batch_line_spans);
  }

  static jobject setBatchLineInlayHints(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_batch_line_inlay_hints);
  }

  static jobject setBatchLinePhantomTexts(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_batch_line_phantom_texts);
  }

  static jobject setBatchLineGutterIcons(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_batch_line_gutter_icons);
  }

  static jobject setLineCodeLens(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    return wrapBufferAction(env, handle, buffer, size, editor_set_line_codelens);
  }

  static jobject setBatchLineCodeLens(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_batch_line_codelens);
  }

  static jobject setLineLinks(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_line_links);
  }

  static jobject setBatchLineLinks(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_batch_line_links);
  }

  static jobject setBatchLineDiagnostics(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_batch_line_diagnostics);
  }

  static jobject setFoldRegions(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_set_fold_regions);
  }

  static jobject toggleFoldAt(JNIEnv* env, jclass clazz, jlong handle, jint line) {
    return wrapLineAction(env, handle, line, editor_toggle_fold);
  }

  static jobject foldAt(JNIEnv* env, jclass clazz, jlong handle, jint line) {
    return wrapLineAction(env, handle, line, editor_fold_at);
  }

  static jobject unfoldAt(JNIEnv* env, jclass clazz, jlong handle, jint line) {
    return wrapLineAction(env, handle, line, editor_unfold_at);
  }

  static jobject foldAll(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_fold_all);
  }

  static jobject unfoldAll(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_unfold_all);
  }

  static jboolean isLineVisible(jlong handle, jint line) {
    return toJBoolean(editor_is_line_visible(static_cast<intptr_t>(handle), static_cast<size_t>(line)));
  }

  static jintArray getVisibleLineRange(JNIEnv* env, jclass clazz, jlong handle) {
    int32_t start_line = 0;
    int32_t end_line = -1;
    editor_get_visible_line_range(static_cast<intptr_t>(handle), &start_line, &end_line);
    const jint values[2] = {static_cast<jint>(start_line), static_cast<jint>(end_line)};
    jintArray result = env->NewIntArray(2);
    if (result == nullptr) return nullptr;
    env->SetIntArrayRegion(result, 0, 2, values);
    return result;
  }

  static jobject setLineGutterIcons(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    return wrapBufferAction(env, handle, buffer, size, editor_set_line_gutter_icons);
  }

  static jobject setMaxGutterIcons(JNIEnv* env, jclass clazz, jlong handle, jint count) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_max_gutter_icons(static_cast<intptr_t>(handle),
                                                         static_cast<uint32_t>(count),
                                                         &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setFoldArrowMode(JNIEnv* env, jclass clazz, jlong handle, jint mode) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_fold_arrow_mode(static_cast<intptr_t>(handle),
                                                        static_cast<int>(mode),
                                                        &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setWrapMode(JNIEnv* env, jclass clazz, jlong handle, jint mode) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_wrap_mode(static_cast<intptr_t>(handle),
                                                  static_cast<int>(mode),
                                                  &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setTabSize(JNIEnv* env, jclass clazz, jlong handle, jint tab_size) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_tab_size(static_cast<intptr_t>(handle),
                                                 static_cast<int>(tab_size),
                                                 &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setScale(JNIEnv* env, jclass clazz, jlong handle, jfloat scale) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_scale(static_cast<intptr_t>(handle), scale, &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setLineSpacing(JNIEnv* env, jclass clazz, jlong handle, jfloat add, jfloat mult) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_line_spacing(static_cast<intptr_t>(handle),
                                                     add,
                                                     mult,
                                                     &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setContentStartPadding(JNIEnv* env, jclass clazz, jlong handle, jfloat padding) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_content_start_padding(static_cast<intptr_t>(handle),
                                                              padding,
                                                              &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setShowSplitLine(JNIEnv* env, jclass clazz, jlong handle, jboolean show) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_show_split_line(static_cast<intptr_t>(handle),
                                                        show == JNI_TRUE ? 1 : 0,
                                                        &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setGutterSticky(JNIEnv* env, jclass clazz, jlong handle, jboolean sticky) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_gutter_sticky(static_cast<intptr_t>(handle),
                                                      sticky == JNI_TRUE ? 1 : 0,
                                                      &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setGutterVisible(JNIEnv* env, jclass clazz, jlong handle, jboolean visible) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_gutter_visible(static_cast<intptr_t>(handle),
                                                       visible == JNI_TRUE ? 1 : 0,
                                                       &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject setCurrentLineRenderMode(JNIEnv* env, jclass clazz, jlong handle, jint mode) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_current_line_render_mode(static_cast<intptr_t>(handle),
                                                                 static_cast<int>(mode),
                                                                 &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject editorUndo(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_undo(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jobject editorRedo(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_redo(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jboolean editorCanUndo(jlong handle) {
    return toJBoolean(editor_can_undo(static_cast<intptr_t>(handle)));
  }

  static jboolean editorCanRedo(jlong handle) {
    return toJBoolean(editor_can_redo(static_cast<intptr_t>(handle)));
  }

  static jobject scrollToLine(JNIEnv* env, jclass clazz, jlong handle, jint line, jint behavior) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_scroll_to_line(static_cast<intptr_t>(handle),
                                                   static_cast<size_t>(line),
                                                   static_cast<uint8_t>(behavior),
                                                   &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject gotoPosition(JNIEnv* env, jclass clazz, jlong handle, jint line, jint column) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_goto_position(static_cast<intptr_t>(handle),
                                                  static_cast<size_t>(line),
                                                  static_cast<size_t>(column),
                                                  &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject ensureCursorVisible(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_ensure_cursor_visible);
  }

  static jobject setScroll(JNIEnv* env, jclass clazz, jlong handle, jfloat scrollX, jfloat scrollY) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_scroll(static_cast<intptr_t>(handle),
                                               scrollX,
                                               scrollY,
                                               &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject getScrollMetrics(JNIEnv* env, jclass clazz, jlong handle) {
    size_t out_size = 0;
    return wrapBinaryPayload(env, editor_get_scroll_metrics(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static jlong getCursorPosition(jlong handle) {
    size_t line = 0;
    size_t column = 0;
    editor_get_cursor_position(static_cast<intptr_t>(handle), &line, &column);
    return packTextPosition(line, column);
  }

  static jlongArray getWordRangeAtCursor(JNIEnv* env, jclass clazz, jlong handle) {
    jlongArray result = env->NewLongArray(4);
    size_t start_line = 0;
    size_t start_column = 0;
    size_t end_line = 0;
    size_t end_column = 0;
    editor_get_word_range_at_cursor(static_cast<intptr_t>(handle), &start_line, &start_column, &end_line, &end_column);
    jlong vals[4] = {
        static_cast<jlong>(start_line),
        static_cast<jlong>(start_column),
        static_cast<jlong>(end_line),
        static_cast<jlong>(end_column)
    };
    env->SetLongArrayRegion(result, 0, 4, vals);
    return result;
  }

  static jstring getWordAtCursor(JNIEnv* env, jclass clazz, jlong handle) {
    SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(handle);
    if (editor_core == nullptr) return env->NewStringUTF("");
    U8String word = editor_core->getWordAtCursor();
    return env->NewStringUTF(word.c_str());
  }

  static jstring getLinkTargetAt(JNIEnv* env, jclass clazz, jlong handle, jint line, jint column) {
    SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(handle);
    if (editor_core == nullptr) return env->NewStringUTF("");
    U8String target = editor_core->getLinkTargetAt(static_cast<size_t>(line), static_cast<size_t>(column));
    return env->NewStringUTF(target.c_str());
  }

  static jobject setCursorPosition(JNIEnv* env, jclass clazz, jlong handle, jint line, jint column) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_cursor_position(static_cast<intptr_t>(handle),
                                                        static_cast<size_t>(line),
                                                        static_cast<size_t>(column),
                                                        &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject moveCursorLeft(JNIEnv* env, jclass clazz, jlong handle, jboolean extendSelection) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_move_cursor_left(static_cast<intptr_t>(handle),
                                                     extendSelection == JNI_TRUE ? 1 : 0,
                                                     &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject moveCursorRight(JNIEnv* env, jclass clazz, jlong handle, jboolean extendSelection) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_move_cursor_right(static_cast<intptr_t>(handle),
                                                      extendSelection == JNI_TRUE ? 1 : 0,
                                                      &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject moveCursorUp(JNIEnv* env, jclass clazz, jlong handle, jboolean extendSelection) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_move_cursor_up(static_cast<intptr_t>(handle),
                                                   extendSelection == JNI_TRUE ? 1 : 0,
                                                   &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject moveCursorDown(JNIEnv* env, jclass clazz, jlong handle, jboolean extendSelection) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_move_cursor_down(static_cast<intptr_t>(handle),
                                                     extendSelection == JNI_TRUE ? 1 : 0,
                                                     &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject moveCursorToLineStart(JNIEnv* env, jclass clazz, jlong handle, jboolean extendSelection) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_move_cursor_to_line_start(static_cast<intptr_t>(handle),
                                                              extendSelection == JNI_TRUE ? 1 : 0,
                                                              &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject moveCursorToLineEnd(JNIEnv* env, jclass clazz, jlong handle, jboolean extendSelection) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_move_cursor_to_line_end(static_cast<intptr_t>(handle),
                                                            extendSelection == JNI_TRUE ? 1 : 0,
                                                            &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject editorInsertSnippet(JNIEnv* env, jclass clazz, jlong handle, jstring snippetTemplate) {
    if (handle == 0 || snippetTemplate == nullptr) return nullptr;
    const char* tpl_str = env->GetStringUTFChars(snippetTemplate, JNI_FALSE);
    size_t out_size = 0;
    const uint8_t* payload = editor_insert_snippet(static_cast<intptr_t>(handle), tpl_str, &out_size);
    env->ReleaseStringUTFChars(snippetTemplate, tpl_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject editorStartLinkedEditing(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    return wrapBufferAction(env, handle, data, size, editor_start_linked_editing);
  }

  static jboolean editorIsInLinkedEditing(jlong handle) {
    return toJBoolean(editor_is_in_linked_editing(static_cast<intptr_t>(handle)));
  }

  static jobject editorLinkedEditingNext(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_linked_editing_next);
  }

  static jobject editorLinkedEditingPrev(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_linked_editing_prev);
  }

  static jobject editorCancelLinkedEditing(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_cancel_linked_editing);
  }

  static jobject selectAll(JNIEnv* env, jclass clazz, jlong handle) {
    return wrapHandleAction(env, handle, editor_select_all);
  }

  static jobject setSelection(JNIEnv* env, jclass clazz, jlong handle, jint startLine, jint startColumn, jint endLine, jint endColumn) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_set_selection(static_cast<intptr_t>(handle),
                                                  static_cast<size_t>(startLine),
                                                  static_cast<size_t>(startColumn),
                                                  static_cast<size_t>(endLine),
                                                  static_cast<size_t>(endColumn),
                                                  &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jlongArray getSelection(JNIEnv* env, jclass clazz, jlong handle) {
    jlongArray result = env->NewLongArray(4);
    size_t start_line = 0;
    size_t start_column = 0;
    size_t end_line = 0;
    size_t end_column = 0;
    jlong vals[4] = {-1, -1, -1, -1};
    if (editor_get_selection(static_cast<intptr_t>(handle), &start_line, &start_column, &end_line, &end_column) != 0) {
      vals[0] = static_cast<jlong>(start_line);
      vals[1] = static_cast<jlong>(start_column);
      vals[2] = static_cast<jlong>(end_line);
      vals[3] = static_cast<jlong>(end_column);
    }
    env->SetLongArrayRegion(result, 0, 4, vals);
    return result;
  }

  static void freeBinaryData(JNIEnv* env, jclass clazz, jobject buffer) {
    if (buffer == nullptr) {
      return;
    }
    void* ptr = env->GetDirectBufferAddress(buffer);
    if (ptr == nullptr) {
      return;
    }
    free_binary_data(reinterpret_cast<intptr_t>(ptr));
  }

  constexpr static const char *kJClassName = "com/qiplat/sweeteditor/core/EditorCore";
  constexpr static const JNINativeMethod kJMethods[] = {
    {"nativeMakeEditorCore", "(Lcom/qiplat/sweeteditor/core/TextMeasurer;Ljava/nio/ByteBuffer;I)J", (void*) makeEditorCore},
      {"nativeFinalizeEditorCore", "(J)V", (void*) finalizeEditorCore},
      {"nativeSetViewport", "(JII)Ljava/nio/ByteBuffer;", (void*) setViewport},
      {"nativeLoadDocument", "(JJ)Ljava/nio/ByteBuffer;", (void*) loadDocument},
      {"nativeHandleGestureEvent", "(JII[F)Ljava/nio/ByteBuffer;", (void*) handleGestureEvent},
      {"nativeHandleGestureEventEx", "(JII[FIFFF)Ljava/nio/ByteBuffer;", (void*) handleGestureEventEx},
      {"nativeTickEdgeScroll", "(J)Ljava/nio/ByteBuffer;", (void*) tickEdgeScroll},
      {"nativeTickFling", "(J)Ljava/nio/ByteBuffer;", (void*) tickFling},
      {"nativeTickAnimations", "(J)Ljava/nio/ByteBuffer;", (void*) tickAnimations},
      {"nativeOnFontMetricsChanged", "(J)Ljava/nio/ByteBuffer;", (void*) onFontMetricsChanged},
      {"nativeBuildRenderModel", "(J)Ljava/nio/ByteBuffer;", (void*) buildRenderModel},
      {"nativeGetLayoutMetrics", "(J)Ljava/nio/ByteBuffer;", (void*) getLayoutMetrics},
      {"nativeHandleKeyEvent", "(JILjava/lang/String;I)Ljava/nio/ByteBuffer;", (void*) handleKeyEvent},
      {"nativeSetKeyMap", "(JLjava/nio/ByteBuffer;)Ljava/nio/ByteBuffer;", (void*) setKeyMap},
      {"nativeInsertText", "(JLjava/lang/String;)Ljava/nio/ByteBuffer;", (void*) insertText},
      {"nativeReplaceText", "(JIIIILjava/lang/String;)Ljava/nio/ByteBuffer;", (void*) replaceText},
      {"nativeDeleteText", "(JIIII)Ljava/nio/ByteBuffer;", (void*) deleteText},
      {"nativeMoveLineUp", "(J)Ljava/nio/ByteBuffer;", (void*) moveLineUp},
      {"nativeMoveLineDown", "(J)Ljava/nio/ByteBuffer;", (void*) moveLineDown},
      {"nativeCopyLineUp", "(J)Ljava/nio/ByteBuffer;", (void*) copyLineUp},
      {"nativeCopyLineDown", "(J)Ljava/nio/ByteBuffer;", (void*) copyLineDown},
      {"nativeDeleteLine", "(J)Ljava/nio/ByteBuffer;", (void*) deleteLine},
      {"nativeInsertLineAbove", "(J)Ljava/nio/ByteBuffer;", (void*) insertLineAbove},
      {"nativeInsertLineBelow", "(J)Ljava/nio/ByteBuffer;", (void*) insertLineBelow},
      {"nativeGetSelectedText", "(J)Ljava/lang/String;", (void*) getSelectedText},
      {"nativeIsComposing", "(J)Z", (void*) isComposing},
      {"nativeGetComposingRange", "(J)[J", (void*) getComposingRange},
      {"nativeGetComposingSessionRange", "(J)[J", (void*) getComposingSessionRange},
      {"nativeImeUpdatePreedit", "(JLjava/lang/String;I)Ljava/nio/ByteBuffer;", (void*) imeUpdatePreedit},
      {"nativeImeSetComposingText", "(JLjava/lang/String;II)Ljava/nio/ByteBuffer;", (void*) imeSetComposingText},
      {"nativeImeCommitText", "(JLjava/lang/String;I)Ljava/nio/ByteBuffer;", (void*) imeCommitText},
      {"nativeImeCommitTextWithCursor", "(JLjava/lang/String;II)Ljava/nio/ByteBuffer;", (void*) imeCommitTextWithCursor},
      {"nativeImeFinishPreedit", "(J)Ljava/nio/ByteBuffer;", (void*) imeFinishPreedit},
      {"nativeImeCancelPreedit", "(J)Ljava/nio/ByteBuffer;", (void*) imeCancelPreedit},
      {"nativeImeMarkDocumentRange", "(JJJJJI)Ljava/nio/ByteBuffer;", (void*) imeMarkDocumentRange},
      {"nativeImeMarkDocumentRangeByOffset", "(JJJI)Ljava/nio/ByteBuffer;", (void*) imeMarkDocumentRangeByOffset},
      {"nativeImeReplaceText", "(JJJJJLjava/lang/String;I)Ljava/nio/ByteBuffer;", (void*) imeReplaceText},
      {"nativeImeReplaceDocumentText", "(JJJLjava/lang/String;II)Ljava/nio/ByteBuffer;", (void*) imeReplaceDocumentText},
      {"nativeImeReplaceInputContextText", "(JJJLjava/lang/String;II)Ljava/nio/ByteBuffer;", (void*) imeReplaceInputContextText},
      {"nativeImeMarkInputContextRange", "(JJJI)Ljava/nio/ByteBuffer;", (void*) imeMarkInputContextRange},
      {"nativeImeNotifyDocumentSelectionChanged", "(JJJ)Ljava/nio/ByteBuffer;", (void*) imeNotifyDocumentSelectionChanged},
      {"nativeImeNotifyInputContextSelectionChanged", "(JJJ)Ljava/nio/ByteBuffer;", (void*) imeNotifyInputContextSelectionChanged},
      {"nativeImeUpdateInputStateText", "(JJILjava/lang/String;IIIII)Ljava/nio/ByteBuffer;", (void*) imeUpdateInputStateText},
      {"nativeImeUpdateInputStateSelection", "(JJIII)Ljava/nio/ByteBuffer;", (void*) imeUpdateInputStateSelection},
      {"nativeImeReplaceInputStateText", "(JJIJJLjava/lang/String;II)Ljava/nio/ByteBuffer;", (void*) imeReplaceInputStateText},
      {"nativeImeDeleteBackward", "(JJI)Ljava/nio/ByteBuffer;", (void*) imeDeleteBackward},
      {"nativeImeDeleteForward", "(JJI)Ljava/nio/ByteBuffer;", (void*) imeDeleteForward},
      {"nativeImeDeleteSurrounding", "(JJJI)Ljava/nio/ByteBuffer;", (void*) imeDeleteSurrounding},
      {"nativeImeNotifySelectionChanged", "(JJJJJ)Ljava/nio/ByteBuffer;", (void*) imeNotifySelectionChanged},
      {"nativeImeNotifyCursorChanged", "(JJJ)Ljava/nio/ByteBuffer;", (void*) imeNotifyCursorChanged},
      {"nativeImeSetKeyboardScriptClass", "(JI)Ljava/nio/ByteBuffer;", (void*) imeSetKeyboardScriptClass},
      {"nativeImeGetKeyboardScriptClass", "(J)I", (void*) imeGetKeyboardScriptClass},
      {"nativeGetImeSyncSnapshot", "(J)Ljava/nio/ByteBuffer;", (void*) getImeSyncSnapshot},
      {"nativeGetImeInputContext", "(JJJ)Ljava/nio/ByteBuffer;", (void*) getImeInputContext},
      {"nativeSetReadOnly", "(JZ)Ljava/nio/ByteBuffer;", (void*) setReadOnly},
      {"nativeIsReadOnly", "(J)Z", (void*) isReadOnly},
      {"nativeSetAutoIndentMode", "(JI)Ljava/nio/ByteBuffer;", (void*) setAutoIndentMode},
      {"nativeGetAutoIndentMode", "(J)I", (void*) getAutoIndentMode},
      {"nativeSetBackspaceUnindent", "(JZ)Ljava/nio/ByteBuffer;", (void*) setBackspaceUnindent},
      {"nativeSetInsertSpaces", "(JZ)Ljava/nio/ByteBuffer;", (void*) setInsertSpaces},
      {"nativeSetHandleConfig", "(JFFFFFFFF)Ljava/nio/ByteBuffer;", (void*) setHandleConfig},
      {"nativeSetScrollbarConfig", "(JFFFIZIII)Ljava/nio/ByteBuffer;", (void*) setScrollbarConfig},
      {"nativeGetPositionRect", "(JII)[F", (void*) getPositionRect},
      {"nativeGetCursorRect", "(J)[F", (void*) getCursorRect},
      {"nativeRegisterTextStyle", "(JIIII)Ljava/nio/ByteBuffer;", (void*) registerTextStyle},
      {"nativeRegisterBatchTextStyles", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) registerBatchTextStyles},
      {"nativeSetLineSpans", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setLineSpans},
      {"nativeSetLineInlayHints", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setLineInlayHints},
      {"nativeSetLinePhantomTexts", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setLinePhantomTexts},
      {"nativeClearHighlights", "(J)Ljava/nio/ByteBuffer;", (void*) clearHighlights},
      {"nativeClearHighlightsLayer", "(JI)Ljava/nio/ByteBuffer;", (void*) clearHighlightsLayer},
      {"nativeClearLineSpans", "(JII)Ljava/nio/ByteBuffer;", (void*) clearLineSpans},
      {"nativeClearInlayHints", "(J)Ljava/nio/ByteBuffer;", (void*) clearInlayHints},
      {"nativeClearPhantomTexts", "(J)Ljava/nio/ByteBuffer;", (void*) clearPhantomTexts},
      {"nativeClearGutterIcons", "(J)Ljava/nio/ByteBuffer;", (void*) clearGutterIcons},
      {"nativeClearCodeLens", "(J)Ljava/nio/ByteBuffer;", (void*) clearCodeLens},
      {"nativeClearLinks", "(J)Ljava/nio/ByteBuffer;", (void*) clearLinks},
      {"nativeClearGuides", "(J)Ljava/nio/ByteBuffer;", (void*) clearGuides},
      {"nativeClearAllDecorations", "(J)Ljava/nio/ByteBuffer;", (void*) clearAllDecorations},
      {"nativeSetIndentGuides", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setIndentGuides},
      {"nativeSetBracketGuides", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBracketGuides},
      {"nativeSetFlowGuides", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setFlowGuides},
      {"nativeSetSeparatorGuides", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setSeparatorGuides},
      {"nativeSetBracketPairs", "(J[I[I)Ljava/nio/ByteBuffer;", (void*) setBracketPairs},
      {"nativeSetAutoClosingPairs", "(J[I[I)Ljava/nio/ByteBuffer;", (void*) setAutoClosingPairs},
      {"nativeSetMatchedBrackets", "(JIIII)Ljava/nio/ByteBuffer;", (void*) setMatchedBrackets},
      {"nativeClearMatchedBrackets", "(J)Ljava/nio/ByteBuffer;", (void*) clearMatchedBrackets},
      {"nativeSetLineDiagnostics", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setLineDiagnostics},
      {"nativeClearDiagnostics", "(J)Ljava/nio/ByteBuffer;", (void*) clearDiagnostics},
      {"nativeSetBatchLineSpans", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBatchLineSpans},
      {"nativeSetBatchLineInlayHints", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBatchLineInlayHints},
      {"nativeSetBatchLinePhantomTexts", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBatchLinePhantomTexts},
      {"nativeSetBatchLineGutterIcons", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBatchLineGutterIcons},
      {"nativeSetLineCodeLens", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setLineCodeLens},
      {"nativeSetBatchLineCodeLens", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBatchLineCodeLens},
      {"nativeSetLineLinks", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setLineLinks},
      {"nativeSetBatchLineLinks", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBatchLineLinks},
      {"nativeSetBatchLineDiagnostics", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setBatchLineDiagnostics},
      {"nativeSetFoldRegions", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setFoldRegions},
      {"nativeToggleFoldAt", "(JI)Ljava/nio/ByteBuffer;", (void*) toggleFoldAt},
      {"nativeFoldAt", "(JI)Ljava/nio/ByteBuffer;", (void*) foldAt},
      {"nativeUnfoldAt", "(JI)Ljava/nio/ByteBuffer;", (void*) unfoldAt},
      {"nativeFoldAll", "(J)Ljava/nio/ByteBuffer;", (void*) foldAll},
      {"nativeUnfoldAll", "(J)Ljava/nio/ByteBuffer;", (void*) unfoldAll},
      {"nativeIsLineVisible", "(JI)Z", (void*) isLineVisible},
      {"nativeGetVisibleLineRange", "(J)[I", (void*) getVisibleLineRange},
      {"nativeSetLineGutterIcons", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) setLineGutterIcons},
      {"nativeSetMaxGutterIcons", "(JI)Ljava/nio/ByteBuffer;", (void*) setMaxGutterIcons},
      {"nativeSetFoldArrowMode", "(JI)Ljava/nio/ByteBuffer;", (void*) setFoldArrowMode},
      {"nativeSetWrapMode", "(JI)Ljava/nio/ByteBuffer;", (void*) setWrapMode},
      {"nativeSetTabSize", "(JI)Ljava/nio/ByteBuffer;", (void*) setTabSize},
      {"nativeSetScale", "(JF)Ljava/nio/ByteBuffer;", (void*) setScale},
      {"nativeSetLineSpacing", "(JFF)Ljava/nio/ByteBuffer;", (void*) setLineSpacing},
      {"nativeSetContentStartPadding", "(JF)Ljava/nio/ByteBuffer;", (void*) setContentStartPadding},
      {"nativeSetShowSplitLine", "(JZ)Ljava/nio/ByteBuffer;", (void*) setShowSplitLine},
      {"nativeSetGutterSticky", "(JZ)Ljava/nio/ByteBuffer;", (void*) setGutterSticky},
      {"nativeSetGutterVisible", "(JZ)Ljava/nio/ByteBuffer;", (void*) setGutterVisible},
      {"nativeSetCurrentLineRenderMode", "(JI)Ljava/nio/ByteBuffer;", (void*) setCurrentLineRenderMode},
      {"nativeUndo", "(J)Ljava/nio/ByteBuffer;", (void*) editorUndo},
      {"nativeRedo", "(J)Ljava/nio/ByteBuffer;", (void*) editorRedo},
      {"nativeCanUndo", "(J)Z", (void*) editorCanUndo},
      {"nativeCanRedo", "(J)Z", (void*) editorCanRedo},
      {"nativeScrollToLine", "(JII)Ljava/nio/ByteBuffer;", (void*) scrollToLine},
      {"nativeGotoPosition", "(JII)Ljava/nio/ByteBuffer;", (void*) gotoPosition},
      {"nativeEnsureCursorVisible", "(J)Ljava/nio/ByteBuffer;", (void*) ensureCursorVisible},
      {"nativeSetScroll", "(JFF)Ljava/nio/ByteBuffer;", (void*) setScroll},
      {"nativeGetScrollMetrics", "(J)Ljava/nio/ByteBuffer;", (void*) getScrollMetrics},
      {"nativeGetCursorPosition", "(J)J", (void*) getCursorPosition},
      {"nativeGetWordRangeAtCursor", "(J)[J", (void*) getWordRangeAtCursor},
      {"nativeGetWordAtCursor", "(J)Ljava/lang/String;", (void*) getWordAtCursor},
      {"nativeGetLinkTargetAt", "(JII)Ljava/lang/String;", (void*) getLinkTargetAt},
      {"nativeMoveCursorLeft", "(JZ)Ljava/nio/ByteBuffer;", (void*) moveCursorLeft},
      {"nativeMoveCursorRight", "(JZ)Ljava/nio/ByteBuffer;", (void*) moveCursorRight},
      {"nativeMoveCursorUp", "(JZ)Ljava/nio/ByteBuffer;", (void*) moveCursorUp},
      {"nativeMoveCursorDown", "(JZ)Ljava/nio/ByteBuffer;", (void*) moveCursorDown},
      {"nativeMoveCursorToLineStart", "(JZ)Ljava/nio/ByteBuffer;", (void*) moveCursorToLineStart},
      {"nativeMoveCursorToLineEnd", "(JZ)Ljava/nio/ByteBuffer;", (void*) moveCursorToLineEnd},
      {"nativeSetCursorPosition", "(JII)Ljava/nio/ByteBuffer;", (void*) setCursorPosition},
      {"nativeSelectAll", "(J)Ljava/nio/ByteBuffer;", (void*) selectAll},
      {"nativeSetSelection", "(JIIII)Ljava/nio/ByteBuffer;", (void*) setSelection},
      {"nativeGetSelection", "(J)[J", (void*) getSelection},
      {"nativeInsertSnippet", "(JLjava/lang/String;)Ljava/nio/ByteBuffer;", (void*) editorInsertSnippet},
      {"nativeStartLinkedEditing", "(JLjava/nio/ByteBuffer;I)Ljava/nio/ByteBuffer;", (void*) editorStartLinkedEditing},
      {"nativeIsInLinkedEditing", "(J)Z", (void*) editorIsInLinkedEditing},
      {"nativeLinkedEditingNext", "(J)Ljava/nio/ByteBuffer;", (void*) editorLinkedEditingNext},
      {"nativeLinkedEditingPrev", "(J)Ljava/nio/ByteBuffer;", (void*) editorLinkedEditingPrev},
      {"nativeCancelLinkedEditing", "(J)Ljava/nio/ByteBuffer;", (void*) editorCancelLinkedEditing},
      {"nativeFreeBinaryData", "(Ljava/nio/ByteBuffer;)V", (void*) freeBinaryData},
  };

  static void RegisterMethods(JNIEnv *env) {
    jclass java_class = env->FindClass(kJClassName);
    env->RegisterNatives(java_class, kJMethods,
                         sizeof(kJMethods) / sizeof(JNINativeMethod));
  }
};

#endif //SWEETEDITOR_JEDITOR_HPP
