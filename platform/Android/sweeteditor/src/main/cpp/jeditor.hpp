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
    Ptr<Document> document = makePtr<LineArrayDocument>(content_str);
    env->ReleaseStringUTFChars(text, content_str);
    return toIntPtr(document);
  }

  static jlong makeFileDocument(JNIEnv* env, jclass clazz, jstring path) {
    const char* path_str = env->GetStringUTFChars(path, nullptr);
    UPtr<Buffer> buffer = makeUPtr<MappedFileBuffer>(path_str);
    env->ReleaseStringUTFChars(path, path_str);
    Ptr<Document> document = makePtr<LineArrayDocument>(std::move(buffer));
    return toIntPtr(document);
  }

  static void finalizeDocument(jlong handle) {
    deleteCPtrHolder<Document>(handle);
  }

  static jstring getText(JNIEnv* env, jclass clazz, jlong handle) {
    Ptr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return env->NewStringUTF("");
    }
    return env->NewStringUTF(document->getU8Text().c_str());
  }

  static jint getLineCount(jlong handle) {
    Ptr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return 0;
    }
    return static_cast<jint>(document->getLineCount());
  }

  static jstring getLineText(JNIEnv* env, jclass clazz, jlong handle, jint line) {
    Ptr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return env->NewStringUTF("");
    }
    U16String u16_text = document->getLineU16Text(line);
    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(u16_text, u8_text);
    return env->NewStringUTF(u8_text.c_str());
  }

  static jlong getPositionFromCharIndex(jlong handle, jint index) {
    Ptr<Document> document = getCPtrHolderValue<Document>(handle);
    if (document == nullptr) {
      return 0;
    }
    TextPosition position = document->getPositionFromCharIndex(index);
    jlong line = (jlong)position.line;
    jlong column = (jlong)position.column;
    return (line << 32) | (column & 0XFFFFFFFFLL);
  }

  static jint getCharIndexFromPosition(jlong handle, jlong position) {
    Ptr<Document> document = getCPtrHolderValue<Document>(handle);
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
    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(text, u8_text);
    jstring java_text = m_env_->NewStringUTF(u8_text.c_str());
    return m_env_->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,
                                             m_jmethod_measureWidth_, java_text, (jint)font_style);
  }

  float measureInlayHintWidth(const U16String &text) override {
    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(text, u8_text);
    jstring java_text = m_env_->NewStringUTF(u8_text.c_str());
    return m_env_->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,
                                             m_jmethod_measureInlayHintWidth_, java_text);
  }

  float measureIconWidth(int32_t icon_id) override {
    return m_env_->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,
                                             m_jmethod_measureIconWidth_, (jint)icon_id);
  }

  FontMetrics getFontMetrics() override {
    float ascent = m_env_->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,m_jmethod_getFontAscent_);
    float descent = m_env_->CallNonvirtualFloatMethod(m_java_obj_,m_jclass_TextMeasurer_,m_jmethod_getFontDescent_);
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
    if (options_buffer != nullptr && options_size >= 28) {
      auto* data_ptr = reinterpret_cast<const uint8_t*>(env->GetDirectBufferAddress(options_buffer));
      if (data_ptr != nullptr) {
        size_t offset = 0;
        std::memcpy(&editor_options.touch_slop, data_ptr + offset, sizeof(float)); offset += sizeof(float);
        std::memcpy(&editor_options.double_tap_timeout, data_ptr + offset, sizeof(int64_t)); offset += sizeof(int64_t);
        std::memcpy(&editor_options.long_press_ms, data_ptr + offset, sizeof(int64_t)); offset += sizeof(int64_t);
        uint64_t max_undo = 0;
        std::memcpy(&max_undo, data_ptr + offset, sizeof(uint64_t));
        editor_options.max_undo_stack_size = static_cast<size_t>(max_undo);
      }
    }
    Ptr<TextMeasurer> native_measurer = makePtr<AndroidTextMeasurer>(env, measurer);
    auto handle = makeCPtrHolderToIntPtr<EditorCore>(native_measurer, editor_options);
    return handle;
  }

  static void finalizeEditorCore(jlong handle) {
    deleteCPtrHolder<EditorCore>(handle);
  }

  static void setViewport(jlong handle, jint width, jint height) {
    set_editor_viewport(static_cast<intptr_t>(handle), static_cast<int16_t>(width), static_cast<int16_t>(height));
  }

  static void loadDocument(jlong handle, jlong doc_handle) {
    set_editor_document(static_cast<intptr_t>(handle), static_cast<intptr_t>(doc_handle));
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

  static void resetMeasurer(jlong handle) {
    reset_editor_text_measurer(static_cast<intptr_t>(handle));
  }

  static jobject tickEdgeScroll(JNIEnv* env, jclass clazz, jlong handle) {
    if (handle == 0) return nullptr;
    size_t out_size = 0;
    const uint8_t* payload = editor_tick_edge_scroll(static_cast<intptr_t>(handle), &out_size);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static jobject buildRenderModel(JNIEnv* env, jclass clazz, jlong handle) {
    size_t out_size = 0;
    return wrapBinaryPayload(env, build_editor_render_model(static_cast<intptr_t>(handle), &out_size), out_size);
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
    Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(handle);
    if (editor_core == nullptr) {
      return env->NewStringUTF("");
    }
    U8String selected = editor_core->getSelectedText();
    return env->NewStringUTF(selected.c_str());
  }

  static void compositionStart(jlong handle) {
    editor_composition_start(static_cast<intptr_t>(handle));
  }

  static void compositionUpdate(JNIEnv* env, jclass clazz, jlong handle, jstring text) {
    const char* text_str = text != nullptr ? env->GetStringUTFChars(text, JNI_FALSE) : nullptr;
    editor_composition_update(static_cast<intptr_t>(handle), text_str);
    if (text != nullptr) {
      env->ReleaseStringUTFChars(text, text_str);
    }
  }

  static jobject compositionEnd(JNIEnv* env, jclass clazz, jlong handle, jstring committed_text) {
    if (handle == 0) return nullptr;
    const char* text_str = committed_text != nullptr ? env->GetStringUTFChars(committed_text, JNI_FALSE) : "";
    size_t out_size = 0;
    const uint8_t* payload = editor_composition_end(static_cast<intptr_t>(handle), text_str, &out_size);
    if (committed_text != nullptr) env->ReleaseStringUTFChars(committed_text, text_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static void compositionCancel(jlong handle) {
    editor_composition_cancel(static_cast<intptr_t>(handle));
  }

  static jboolean isComposing(jlong handle) {
    return toJBoolean(editor_is_composing(static_cast<intptr_t>(handle)));
  }

  static void setCompositionEnabled(jlong handle, jboolean enabled) {
    editor_set_composition_enabled(static_cast<intptr_t>(handle), enabled == JNI_TRUE ? 1 : 0);
  }

  static jboolean isCompositionEnabled(jlong handle) {
    return toJBoolean(editor_is_composition_enabled(static_cast<intptr_t>(handle)));
  }

  static void setReadOnly(jlong handle, jboolean readOnly) {
    editor_set_read_only(static_cast<intptr_t>(handle), readOnly == JNI_TRUE ? 1 : 0);
  }

  static jboolean isReadOnly(jlong handle) {
    return toJBoolean(editor_is_read_only(static_cast<intptr_t>(handle)));
  }

  static void setAutoIndentMode(jlong handle, jint mode) {
    editor_set_auto_indent_mode(static_cast<intptr_t>(handle), static_cast<int>(mode));
  }

  static jint getAutoIndentMode(jlong handle) {
    return static_cast<jint>(editor_get_auto_indent_mode(static_cast<intptr_t>(handle)));
  }

  static void setHandleConfig(jlong handle, jfloat radius, jfloat centerDist, jfloat lineWidth, jfloat touchPadding, jfloat dragYOffset) {
    editor_set_handle_config(static_cast<intptr_t>(handle), radius, centerDist, lineWidth, touchPadding, dragYOffset);
  }

  static void setScrollbarConfig(jlong handle, jfloat thickness, jfloat minThumb, jfloat thumbHitPadding,
                                 jint mode, jboolean thumbDraggable, jint trackTapMode,
                                 jint fadeDelayMs, jint fadeDurationMs) {
    editor_set_scrollbar_config(static_cast<intptr_t>(handle),
                                thickness, minThumb, thumbHitPadding,
                                static_cast<int>(mode),
                                thumbDraggable == JNI_TRUE ? 1 : 0,
                                static_cast<int>(trackTapMode),
                                static_cast<int>(fadeDelayMs),
                                static_cast<int>(fadeDurationMs));
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

  static void registerTextStyle(jlong handle, jint styleId, jint color, jint backgroundColor, jint fontStyle) {
    editor_register_text_style(static_cast<intptr_t>(handle),
                               static_cast<uint32_t>(styleId),
                               static_cast<int32_t>(color),
                               static_cast<int32_t>(backgroundColor),
                               static_cast<int32_t>(fontStyle));
  }

  static void setLineSpans(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_line_spans(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setLineInlayHints(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_line_inlay_hints(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setLinePhantomTexts(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    auto* ptr = env->GetDirectBufferAddress(buffer);
    editor_set_line_phantom_texts(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void clearHighlights(jlong handle) {
    editor_clear_highlights(static_cast<intptr_t>(handle));
  }

  static void clearHighlightsLayer(jlong handle, jint layer) {
    editor_clear_highlights_layer(static_cast<intptr_t>(handle), static_cast<uint8_t>(layer));
  }

  static void clearInlayHints(jlong handle) {
    editor_clear_inlay_hints(static_cast<intptr_t>(handle));
  }

  static void clearPhantomTexts(jlong handle) {
    editor_clear_phantom_texts(static_cast<intptr_t>(handle));
  }

  static void clearGutterIcons(jlong handle) {
    editor_clear_gutter_icons(static_cast<intptr_t>(handle));
  }

  static void clearGuides(jlong handle) {
    editor_clear_guides(static_cast<intptr_t>(handle));
  }

  static void clearAllDecorations(jlong handle) {
    editor_clear_all_decorations(static_cast<intptr_t>(handle));
  }

  static void setIndentGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    auto* ptr = env->GetDirectBufferAddress(buffer);
    editor_set_indent_guides(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setBracketGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    auto* ptr = env->GetDirectBufferAddress(buffer);
    editor_set_bracket_guides(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setFlowGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    auto* ptr = env->GetDirectBufferAddress(buffer);
    editor_set_flow_guides(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setSeparatorGuides(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    auto* ptr = env->GetDirectBufferAddress(buffer);
    editor_set_separator_guides(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setBracketPairs(JNIEnv* env, jclass clazz, jlong handle, jintArray openChars, jintArray closeChars) {
    if (openChars == nullptr || closeChars == nullptr) return;
    jsize count = env->GetArrayLength(openChars);
    jint* opens = env->GetIntArrayElements(openChars, nullptr);
    jint* closes = env->GetIntArrayElements(closeChars, nullptr);
    editor_set_bracket_pairs(static_cast<intptr_t>(handle),
                             reinterpret_cast<const uint32_t*>(opens),
                             reinterpret_cast<const uint32_t*>(closes),
                             static_cast<size_t>(count));
    env->ReleaseIntArrayElements(openChars, opens, JNI_ABORT);
    env->ReleaseIntArrayElements(closeChars, closes, JNI_ABORT);
  }

  static void setMatchedBrackets(jlong handle, jint openLine, jint openCol, jint closeLine, jint closeCol) {
    editor_set_matched_brackets(static_cast<intptr_t>(handle),
                                static_cast<size_t>(openLine),
                                static_cast<size_t>(openCol),
                                static_cast<size_t>(closeLine),
                                static_cast<size_t>(closeCol));
  }

  static void clearMatchedBrackets(jlong handle) {
    editor_clear_matched_brackets(static_cast<intptr_t>(handle));
  }

  static void setLineDiagnostics(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_line_diagnostics(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void clearDiagnostics(jlong handle) {
    editor_clear_diagnostics(static_cast<intptr_t>(handle));
  }

  // ==================== Set line decorations in batch ====================

  static void setBatchLineSpans(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_batch_line_spans(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setBatchLineInlayHints(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_batch_line_inlay_hints(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setBatchLinePhantomTexts(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_batch_line_phantom_texts(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setBatchLineGutterIcons(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_batch_line_gutter_icons(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setBatchLineDiagnostics(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_batch_line_diagnostics(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setFoldRegions(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_set_fold_regions(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static jboolean toggleFoldAt(jlong handle, jint line) {
    return toJBoolean(editor_toggle_fold(static_cast<intptr_t>(handle), static_cast<size_t>(line)));
  }

  static jboolean foldAt(jlong handle, jint line) {
    return toJBoolean(editor_fold_at(static_cast<intptr_t>(handle), static_cast<size_t>(line)));
  }

  static jboolean unfoldAt(jlong handle, jint line) {
    return toJBoolean(editor_unfold_at(static_cast<intptr_t>(handle), static_cast<size_t>(line)));
  }

  static void foldAll(jlong handle) {
    editor_fold_all(static_cast<intptr_t>(handle));
  }

  static void unfoldAll(jlong handle) {
    editor_unfold_all(static_cast<intptr_t>(handle));
  }

  static jboolean isLineVisible(jlong handle, jint line) {
    return toJBoolean(editor_is_line_visible(static_cast<intptr_t>(handle), static_cast<size_t>(line)));
  }

  static void setLineGutterIcons(JNIEnv* env, jclass clazz, jlong handle, jobject buffer, jint size) {
    auto* ptr = env->GetDirectBufferAddress(buffer);
    editor_set_line_gutter_icons(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static void setMaxGutterIcons(jlong handle, jint count) {
    editor_set_max_gutter_icons(static_cast<intptr_t>(handle), static_cast<uint32_t>(count));
  }

  static void setFoldArrowMode(jlong handle, jint mode) {
    editor_set_fold_arrow_mode(static_cast<intptr_t>(handle), static_cast<int>(mode));
  }

  static void setWrapMode(jlong handle, jint mode) {
    editor_set_wrap_mode(static_cast<intptr_t>(handle), static_cast<int>(mode));
  }

  static void setScale(jlong handle, jfloat scale) {
    Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(handle);
    if (editor_core == nullptr) return;
    editor_core->setScale(scale);
  }

  static void setLineSpacing(jlong handle, jfloat add, jfloat mult) {
    editor_set_line_spacing(static_cast<intptr_t>(handle), add, mult);
  }

  static void setContentStartPadding(jlong handle, jfloat padding) {
    editor_set_content_start_padding(static_cast<intptr_t>(handle), padding);
  }

  static void setShowSplitLine(jlong handle, jboolean show) {
    editor_set_show_split_line(static_cast<intptr_t>(handle), show == JNI_TRUE ? 1 : 0);
  }

  static void setCurrentLineRenderMode(jlong handle, jint mode) {
    editor_set_current_line_render_mode(static_cast<intptr_t>(handle), static_cast<int>(mode));
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

  static void scrollToLine(jlong handle, jint line, jint behavior) {
    editor_scroll_to_line(static_cast<intptr_t>(handle), static_cast<size_t>(line), static_cast<uint8_t>(behavior));
  }

  static void gotoPosition(jlong handle, jint line, jint column) {
    editor_goto_position(static_cast<intptr_t>(handle), static_cast<size_t>(line), static_cast<size_t>(column));
  }

  static void setScroll(jlong handle, jfloat scrollX, jfloat scrollY) {
    editor_set_scroll(static_cast<intptr_t>(handle), scrollX, scrollY);
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
    Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(handle);
    if (editor_core == nullptr) return env->NewStringUTF("");
    U8String word = editor_core->getWordAtCursor();
    return env->NewStringUTF(word.c_str());
  }

  static jobject editorInsertSnippet(JNIEnv* env, jclass clazz, jlong handle, jstring snippetTemplate) {
    if (handle == 0 || snippetTemplate == nullptr) return nullptr;
    const char* tpl_str = env->GetStringUTFChars(snippetTemplate, JNI_FALSE);
    size_t out_size = 0;
    const uint8_t* payload = editor_insert_snippet(static_cast<intptr_t>(handle), tpl_str, &out_size);
    env->ReleaseStringUTFChars(snippetTemplate, tpl_str);
    return wrapBinaryPayload(env, payload, out_size);
  }

  static void editorStartLinkedEditing(JNIEnv* env, jclass clazz, jlong handle, jobject data, jint size) {
    if (handle == 0 || data == nullptr || size <= 0) return;
    void* ptr = env->GetDirectBufferAddress(data);
    jlong capacity = env->GetDirectBufferCapacity(data);
    if (ptr == nullptr || capacity < 0 || static_cast<jlong>(size) > capacity) return;
    editor_start_linked_editing(static_cast<intptr_t>(handle), reinterpret_cast<const uint8_t*>(ptr), static_cast<size_t>(size));
  }

  static jboolean editorIsInLinkedEditing(jlong handle) {
    return toJBoolean(editor_is_in_linked_editing(static_cast<intptr_t>(handle)));
  }

  static jboolean editorLinkedEditingNext(jlong handle) {
    return toJBoolean(editor_linked_editing_next(static_cast<intptr_t>(handle)));
  }

  static jboolean editorLinkedEditingPrev(jlong handle) {
    return toJBoolean(editor_linked_editing_prev(static_cast<intptr_t>(handle)));
  }

  static void editorCancelLinkedEditing(jlong handle) {
    editor_cancel_linked_editing(static_cast<intptr_t>(handle));
  }

  static void selectAll(jlong handle) {
    editor_select_all(static_cast<intptr_t>(handle));
  }

  static void setSelection(jlong handle, jint startLine, jint startColumn, jint endLine, jint endColumn) {
    editor_set_selection(static_cast<intptr_t>(handle),
                         static_cast<size_t>(startLine),
                         static_cast<size_t>(startColumn),
                         static_cast<size_t>(endLine),
                         static_cast<size_t>(endColumn));
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
      {"nativeSetViewport", "(JII)V", (void*) setViewport},
      {"nativeLoadDocument", "(JJ)V", (void*) loadDocument},
      {"nativeHandleGestureEvent", "(JII[F)Ljava/nio/ByteBuffer;", (void*) handleGestureEvent},
      {"nativeTickEdgeScroll", "(J)Ljava/nio/ByteBuffer;", (void*) tickEdgeScroll},
      {"nativeResetMeasurer", "(J)V", (void*) resetMeasurer},
      {"nativeBuildRenderModel", "(J)Ljava/nio/ByteBuffer;", (void*) buildRenderModel},
      {"nativeHandleKeyEvent", "(JILjava/lang/String;I)Ljava/nio/ByteBuffer;", (void*) handleKeyEvent},
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
      {"nativeCompositionStart", "(J)V", (void*) compositionStart},
      {"nativeCompositionUpdate", "(JLjava/lang/String;)V", (void*) compositionUpdate},
      {"nativeCompositionEnd", "(JLjava/lang/String;)Ljava/nio/ByteBuffer;", (void*) compositionEnd},
      {"nativeCompositionCancel", "(J)V", (void*) compositionCancel},
      {"nativeIsComposing", "(J)Z", (void*) isComposing},
      {"nativeSetCompositionEnabled", "(JZ)V", (void*) setCompositionEnabled},
      {"nativeIsCompositionEnabled", "(J)Z", (void*) isCompositionEnabled},
      {"nativeSetReadOnly", "(JZ)V", (void*) setReadOnly},
      {"nativeIsReadOnly", "(J)Z", (void*) isReadOnly},
      {"nativeSetAutoIndentMode", "(JI)V", (void*) setAutoIndentMode},
      {"nativeGetAutoIndentMode", "(J)I", (void*) getAutoIndentMode},
      {"nativeSetHandleConfig", "(JFFFFF)V", (void*) setHandleConfig},
      {"nativeSetScrollbarConfig", "(JFFFIZIII)V", (void*) setScrollbarConfig},
      {"nativeGetPositionRect", "(JII)[F", (void*) getPositionRect},
      {"nativeGetCursorRect", "(J)[F", (void*) getCursorRect},
      {"nativeRegisterTextStyle", "(JIIII)V", (void*) registerTextStyle},
      {"nativeSetLineSpans", "(JLjava/nio/ByteBuffer;I)V", (void*) setLineSpans},
      {"nativeSetLineInlayHints", "(JLjava/nio/ByteBuffer;I)V", (void*) setLineInlayHints},
      {"nativeSetLinePhantomTexts", "(JLjava/nio/ByteBuffer;I)V", (void*) setLinePhantomTexts},
      {"nativeClearHighlights", "(J)V", (void*) clearHighlights},
      {"nativeClearHighlightsLayer", "(JI)V", (void*) clearHighlightsLayer},
      {"nativeClearInlayHints", "(J)V", (void*) clearInlayHints},
      {"nativeClearPhantomTexts", "(J)V", (void*) clearPhantomTexts},
      {"nativeClearGutterIcons", "(J)V", (void*) clearGutterIcons},
      {"nativeClearGuides", "(J)V", (void*) clearGuides},
      {"nativeClearAllDecorations", "(J)V", (void*) clearAllDecorations},
      {"nativeSetIndentGuides", "(JLjava/nio/ByteBuffer;I)V", (void*) setIndentGuides},
      {"nativeSetBracketGuides", "(JLjava/nio/ByteBuffer;I)V", (void*) setBracketGuides},
      {"nativeSetFlowGuides", "(JLjava/nio/ByteBuffer;I)V", (void*) setFlowGuides},
      {"nativeSetSeparatorGuides", "(JLjava/nio/ByteBuffer;I)V", (void*) setSeparatorGuides},
      {"nativeSetBracketPairs", "(J[I[I)V", (void*) setBracketPairs},
      {"nativeSetMatchedBrackets", "(JIIII)V", (void*) setMatchedBrackets},
      {"nativeClearMatchedBrackets", "(J)V", (void*) clearMatchedBrackets},
      {"nativeSetLineDiagnostics", "(JLjava/nio/ByteBuffer;I)V", (void*) setLineDiagnostics},
      {"nativeClearDiagnostics", "(J)V", (void*) clearDiagnostics},
      {"nativeSetBatchLineSpans", "(JLjava/nio/ByteBuffer;I)V", (void*) setBatchLineSpans},
      {"nativeSetBatchLineInlayHints", "(JLjava/nio/ByteBuffer;I)V", (void*) setBatchLineInlayHints},
      {"nativeSetBatchLinePhantomTexts", "(JLjava/nio/ByteBuffer;I)V", (void*) setBatchLinePhantomTexts},
      {"nativeSetBatchLineGutterIcons", "(JLjava/nio/ByteBuffer;I)V", (void*) setBatchLineGutterIcons},
      {"nativeSetBatchLineDiagnostics", "(JLjava/nio/ByteBuffer;I)V", (void*) setBatchLineDiagnostics},
      {"nativeSetFoldRegions", "(JLjava/nio/ByteBuffer;I)V", (void*) setFoldRegions},
      {"nativeToggleFoldAt", "(JI)Z", (void*) toggleFoldAt},
      {"nativeFoldAt", "(JI)Z", (void*) foldAt},
      {"nativeUnfoldAt", "(JI)Z", (void*) unfoldAt},
      {"nativeFoldAll", "(J)V", (void*) foldAll},
      {"nativeUnfoldAll", "(J)V", (void*) unfoldAll},
      {"nativeIsLineVisible", "(JI)Z", (void*) isLineVisible},
      {"nativeSetLineGutterIcons", "(JLjava/nio/ByteBuffer;I)V", (void*) setLineGutterIcons},
      {"nativeSetMaxGutterIcons", "(JI)V", (void*) setMaxGutterIcons},
      {"nativeSetFoldArrowMode", "(JI)V", (void*) setFoldArrowMode},
      {"nativeSetWrapMode", "(JI)V", (void*) setWrapMode},
      {"nativeSetScale", "(JF)V", (void*) setScale},
      {"nativeSetLineSpacing", "(JFF)V", (void*) setLineSpacing},
      {"nativeSetContentStartPadding", "(JF)V", (void*) setContentStartPadding},
      {"nativeSetShowSplitLine", "(JZ)V", (void*) setShowSplitLine},
      {"nativeSetCurrentLineRenderMode", "(JI)V", (void*) setCurrentLineRenderMode},
      {"nativeUndo", "(J)Ljava/nio/ByteBuffer;", (void*) editorUndo},
      {"nativeRedo", "(J)Ljava/nio/ByteBuffer;", (void*) editorRedo},
      {"nativeCanUndo", "(J)Z", (void*) editorCanUndo},
      {"nativeCanRedo", "(J)Z", (void*) editorCanRedo},
      {"nativeScrollToLine", "(JII)V", (void*) scrollToLine},
      {"nativeGotoPosition", "(JII)V", (void*) gotoPosition},
      {"nativeSetScroll", "(JFF)V", (void*) setScroll},
      {"nativeGetScrollMetrics", "(J)Ljava/nio/ByteBuffer;", (void*) getScrollMetrics},
      {"nativeGetCursorPosition", "(J)J", (void*) getCursorPosition},
      {"nativeGetWordRangeAtCursor", "(J)[J", (void*) getWordRangeAtCursor},
      {"nativeGetWordAtCursor", "(J)Ljava/lang/String;", (void*) getWordAtCursor},
      {"nativeSelectAll", "(J)V", (void*) selectAll},
      {"nativeSetSelection", "(JIIII)V", (void*) setSelection},
      {"nativeGetSelection", "(J)[J", (void*) getSelection},
      {"nativeInsertSnippet", "(JLjava/lang/String;)Ljava/nio/ByteBuffer;", (void*) editorInsertSnippet},
      {"nativeStartLinkedEditing", "(JLjava/nio/ByteBuffer;I)V", (void*) editorStartLinkedEditing},
      {"nativeIsInLinkedEditing", "(J)Z", (void*) editorIsInLinkedEditing},
      {"nativeLinkedEditingNext", "(J)Z", (void*) editorLinkedEditingNext},
      {"nativeLinkedEditingPrev", "(J)Z", (void*) editorLinkedEditingPrev},
      {"nativeCancelLinkedEditing", "(J)V", (void*) editorCancelLinkedEditing},
      {"nativeFreeBinaryData", "(Ljava/nio/ByteBuffer;)V", (void*) freeBinaryData},
  };

  static void RegisterMethods(JNIEnv *env) {
    jclass java_class = env->FindClass(kJClassName);
    env->RegisterNatives(java_class, kJMethods,
                         sizeof(kJMethods) / sizeof(JNINativeMethod));
  }
};

#endif //SWEETEDITOR_JEDITOR_HPP

