package com.qiplat.sweeteditor.demo;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.Settings;
import android.text.Editable;
import android.text.InputType;
import android.text.Selection;
import android.text.Spanned;
import android.util.AttributeSet;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.CompletionInfo;
import android.view.inputmethod.CorrectionInfo;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.ExtractedTextRequest;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputConnectionWrapper;
import android.view.inputmethod.InputMethodInfo;
import android.view.inputmethod.InputMethodManager;
import android.view.inputmethod.InputMethodSubtype;
import android.view.inputmethod.SurroundingText;
import android.view.inputmethod.TextAttribute;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.qiplat.sweeteditor.EditorSettings;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.ime.ImeSyncSnapshot;
import com.qiplat.sweeteditor.event.CursorChangedEvent;
import com.qiplat.sweeteditor.event.SelectionChangedEvent;
import com.qiplat.sweeteditor.event.TextChangedEvent;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class ImeTraceActivity extends AppCompatActivity {
    private static final String SAMPLE_TEXT =
            "class ImeTraceSample {\n" +
                    "\n" +
                    "    String value() {\n" +
                    "        return \"default\";\n" +
                    "    }\n" +
                    "\n" +
                    "    int count() {\n" +
                    "        return 0;\n" +
                    "    }\n" +
                    "\n" +
                    "    boolean enabled() {\n" +
                    "        return true;\n" +
                    "    }\n" +
                    "\n" +
                    "    void palette() {\n" +
                    "        int[] colors = {0xff0000, 0x00ff00};\n" +
                    "    }\n" +
                    "\n" +
                    "    String sweetEditorUrl = \"https://sweeteditor.dev\";\n" +
                    "    String sweetLineUrl = \"https://sweetline.dev\";\n" +
                    "}";
    private static final int VALUE_LINE = 2;
    private static final int VALUE_START_COLUMN = 11;
    private static final int VALUE_MID_COLUMN = 13;
    private static final int VALUE_END_COLUMN = 16;
    private static final String TARGET_SWEETEDITOR = "sweeteditor";
    private static final String TARGET_EDITTEXT = "edittext";
    private static final String UNKNOWN_IME_PACKAGE = "unknown_ime";
    private static final TraceCase[] TRACE_CASES = new TraceCase[]{
            new TraceCase("EN_HELLO_CANDIDATE_DELETE_TO_EMPTY", "en", 0,
                    "Before Start, switch the IME to English mode with suggestions enabled.",
                    "Tap the empty target and type exactly hello on the soft keyboard.",
                    "Tap the visible hello candidate or confirmation in the IME UI.",
                    "Press the soft keyboard delete key repeatedly until the editor should be empty.",
                    "Tap Delete marker before each delete if possible; tap Next after the final state is stable."),
            new TraceCase("CN_WORD_MID_USER_TAP", "cn", VALUE_MID_COLUMN,
                    "Before Start, switch the IME to Chinese mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after a, so the text position is va|lue.",
                    "Do not type, delete, or tap candidates.",
                    "Wait about one second, then tap Next."),
            new TraceCase("CN_WORD_MID_PINYIN_PREEDIT", "cn", VALUE_MID_COLUMN,
                    "Before Start, switch the IME to Chinese mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after a, so the text position is va|lue.",
                    "Type exactly nihao on the soft keyboard.",
                    "Do not tap any candidate and do not press Enter.",
                    "Tap Next while nihao/candidates are still visible in the IME UI."),
            new TraceCase("CN_WORD_MID_CANDIDATE", "cn", VALUE_MID_COLUMN,
                    "Before Start, switch the IME to Chinese mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after a, so the text position is va|lue.",
                    "Type exactly nihao on the soft keyboard.",
                    "Tap the first Chinese candidate, usually 你好.",
                    "After the candidate appears in the editor, tap Next."),
            new TraceCase("CN_WORD_TAIL_USER_TAP", "cn", VALUE_END_COLUMN,
                    "Before Start, switch the IME to Chinese mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after e, so the text position is value|.",
                    "Do not type, delete, or tap candidates.",
                    "Wait about one second, then tap Next."),
            new TraceCase("CN_WORD_TAIL_CANDIDATE", "cn", VALUE_END_COLUMN,
                    "Before Start, switch the IME to Chinese mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after e, so the text position is value|.",
                    "Type exactly nihao on the soft keyboard.",
                    "Tap the first Chinese candidate, usually 你好.",
                    "After the candidate appears in the editor, tap Next."),
            new TraceCase("EN_WORD_MID_USER_TAP", "en", VALUE_MID_COLUMN,
                    "Before Start, switch the IME to English mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after a, so the text position is va|lue.",
                    "Do not type, delete, or tap candidates.",
                    "Wait about one second, then tap Next."),
            new TraceCase("EN_WORD_MID_TYPE", "en", VALUE_MID_COLUMN,
                    "Before Start, switch the IME to English mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after a, so the text position is va|lue.",
                    "Type exactly x on the soft keyboard.",
                    "After the editor shows vax|lue or equivalent cursor state, tap Next."),
            new TraceCase("EN_WORD_MID_DELETE", "en", VALUE_MID_COLUMN,
                    "Before Start, switch the IME to English mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after a, so the text position is va|lue.",
                    "Press the soft keyboard delete key once.",
                    "After deletion is reflected in the editor or IME UI, tap Next."),
            new TraceCase("EN_WORD_TAIL_TYPE", "en", VALUE_END_COLUMN,
                    "Before Start, switch the IME to English mode.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after e, so the text position is value|.",
                    "Type exactly x on the soft keyboard.",
                    "After the editor shows valuex| or equivalent cursor state, tap Next."),
            new TraceCase("EN_WORD_MID_CANDIDATE", "en", VALUE_MID_COLUMN,
                    "Before Start, switch the IME to English mode with suggestions enabled.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after a, so the text position is va|lue.",
                    "If the IME shows an English suggestion for value or a replacement candidate, tap that candidate.",
                    "If no English suggestion appears after about two seconds, tap Next without typing.",
                    "After the candidate action or timeout, tap Next."),
            new TraceCase("EN_WORD_TAIL_CANDIDATE", "en", VALUE_END_COLUMN,
                    "Before Start, switch the IME to English mode with suggestions enabled.",
                    "After this case starts, manually tap the visible word value in the EditText.",
                    "Place the caret after e, so the text position is value|.",
                    "If the IME shows an English suggestion for value or a replacement candidate, tap that candidate.",
                    "If no English suggestion appears after about two seconds, tap Next without typing.",
                    "After the candidate action or timeout, tap Next.")
    };

    private TraceSweetEditor mSweetEditor;
    private TraceEditText mEditText;
    private TextView mTargetLabel;
    private TextView mCaseTitleText;
    private TextView mStepsText;
    private TextView mStatusText;
    private Button mStartButton;
    private Button mTargetButton;
    private Button mNextButton;
    private Button mRetryButton;
    private Button mSkipButton;
    private Button mStopButton;
    @Nullable private ImeTraceSession mSession;
    @Nullable private TraceCase mCurrentCase;
    private int mCurrentCaseIndex = -1;
    private String mActiveTarget = TARGET_EDITTEXT;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTitle("IME Trace");
        setContentView(createContentView());
        configureTargets();
        updateTargetVisibility();
        resetTargetsForIdle();
    }

    @Override
    protected void onDestroy() {
        finishCurrentSession("activityDestroyed");
        super.onDestroy();
    }

    private View createContentView() {
        ScrollView scrollView = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(8);
        root.setPadding(pad, pad, pad, pad);
        scrollView.addView(root, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout targetRow = horizontalRow();
        TextView baselineTitle = label("IME trace runner");
        targetRow.addView(baselineTitle, new LinearLayout.LayoutParams(0, dp(44), 1f));
        mTargetButton = button("Target");
        mStartButton = button("Start");
        mStopButton = button("Stop");
        targetRow.addView(mTargetButton, weightedButtonParams());
        targetRow.addView(mStartButton, weightedButtonParams());
        targetRow.addView(mStopButton, weightedButtonParams());
        root.addView(targetRow);

        LinearLayout flowRow = horizontalRow();
        mNextButton = button("Next");
        mRetryButton = button("Retry");
        mSkipButton = button("Skip");
        flowRow.addView(mNextButton, weightedButtonParams());
        flowRow.addView(mRetryButton, weightedButtonParams());
        flowRow.addView(mSkipButton, weightedButtonParams());
        root.addView(flowRow);

        LinearLayout markerRow = horizontalRow();
        Button candidateMarker = button("Candidate");
        Button deleteMarker = button("Delete");
        Button switchMarker = button("Switch");
        Button waitMarker = button("Wait");
        markerRow.addView(candidateMarker, weightedButtonParams());
        markerRow.addView(deleteMarker, weightedButtonParams());
        markerRow.addView(switchMarker, weightedButtonParams());
        markerRow.addView(waitMarker, weightedButtonParams());
        root.addView(markerRow);

        mCaseTitleText = new TextView(this);
        mCaseTitleText.setText("No active case");
        mCaseTitleText.setTypeface(Typeface.DEFAULT_BOLD);
        mCaseTitleText.setTextSize(14f);
        mCaseTitleText.setSingleLine(false);
        root.addView(mCaseTitleText, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        mStepsText = new TextView(this);
        mStepsText.setText("Tap Start and choose the first case to record.");
        mStepsText.setSingleLine(false);
        mStepsText.setTextSize(13f);
        root.addView(mStepsText, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        mStatusText = new TextView(this);
        mStatusText.setText("Ready");
        mStatusText.setSingleLine(false);
        mStatusText.setTextSize(12f);
        root.addView(mStatusText, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        mSweetEditor = new TraceSweetEditor(this);
        mSweetEditor.setVisibility(View.GONE);
        root.addView(mSweetEditor, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(420)));

        mTargetLabel = label("EditText baseline");
        root.addView(mTargetLabel);

        mEditText = new TraceEditText(this);
        root.addView(mEditText, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(420)));

        mTargetButton.setOnClickListener(v -> toggleTarget());
        mStartButton.setOnClickListener(v -> showStartCaseDialog());
        mStopButton.setOnClickListener(v -> stopRun());
        mNextButton.setOnClickListener(v -> finishAndOpenNextCase("finished"));
        mRetryButton.setOnClickListener(v -> retryCurrentCase());
        mSkipButton.setOnClickListener(v -> finishAndOpenNextCase("skipped"));
        candidateMarker.setOnClickListener(v -> logUserMarker("candidateTap"));
        deleteMarker.setOnClickListener(v -> logUserMarker("softDelete"));
        switchMarker.setOnClickListener(v -> logUserMarker("keyboardModeSwitch"));
        waitMarker.setOnClickListener(v -> logUserMarker("wait"));
        updateFlowButtons(false);
        return scrollView;
    }

    private void configureTargets() {
        mSweetEditor.setTraceActivity(this);
        EditorSettings settings = mSweetEditor.getSettings();
        settings.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        settings.setEditorTextSize(20f);

        mSweetEditor.subscribe(CursorChangedEvent.class,
                e -> logSystemEvent("sweeteditor", "cursorChanged"));
        mSweetEditor.subscribe(SelectionChangedEvent.class,
                e -> logSystemEvent("sweeteditor", "selectionChanged"));
        mSweetEditor.subscribe(TextChangedEvent.class,
                e -> logSystemEvent("sweeteditor", "textChanged"));

        mEditText.setTraceActivity(this);
        mEditText.setTypeface(Typeface.MONOSPACE);
        mEditText.setTextSize(16f);
        mEditText.setGravity(android.view.Gravity.START | android.view.Gravity.TOP);
        mEditText.setSingleLine(false);
        mEditText.setHorizontallyScrolling(false);
        mEditText.setInputType(InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_FLAG_MULTI_LINE
                | InputType.TYPE_TEXT_FLAG_AUTO_CORRECT);
        mEditText.setImeOptions(EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_ACTION_NONE);
    }

    private void resetTargetsForIdle() {
        TraceCase traceCase = mCurrentCase != null
                ? mCurrentCase
                : TRACE_CASES[0];
        resetTargets(traceCase);
    }

    private void resetTargets(@NonNull TraceCase traceCase) {
        String initialText = traceCase.initialText;
        mSweetEditor.loadDocument(new Document(initialText));
        mSweetEditor.setCursorPosition(new TextPosition(0, 0));
        mEditText.setText(initialText);
        mEditText.setSelection(0);
    }

    private void showStartCaseDialog() {
        String[] labels = new String[TRACE_CASES.length];
        for (int i = 0; i < TRACE_CASES.length; i++) {
            TraceCase traceCase = TRACE_CASES[i];
            labels[i] = String.format(Locale.US,
                    "%02d  %s  [%s]",
                    i + 1,
                    traceCase.caseId,
                    traceCase.keyboardMode);
        }
        new AlertDialog.Builder(this)
                .setTitle("Start from case")
                .setItems(labels, (dialog, which) -> startRunFromCase(which))
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void startRunFromCase(int caseIndex) {
        finishCurrentSession("restarted");
        mCurrentCaseIndex = caseIndex;
        beginCurrentCase();
    }

    private void beginCurrentCase() {
        if (mCurrentCaseIndex < 0 || mCurrentCaseIndex >= TRACE_CASES.length) {
            mCurrentCase = null;
            updateCaseText();
            updateFlowButtons(false);
            updateStatus("Run complete for " + currentInputMethodPackageName());
            return;
        }
        mCurrentCase = TRACE_CASES[mCurrentCaseIndex];
        updateCaseText();
        updateTargetVisibility();
        updateFlowButtons(true);
        mSweetEditor.setTraceSession(null);
        mEditText.setTraceSession(null);
        try {
            mSession = ImeTraceSession.start(this,
                    currentInputMethodPackageName(),
                    mActiveTarget,
                    mCurrentCaseIndex,
                    mCurrentCase.caseId,
                    buildManifest(mCurrentCase));
            if (TARGET_SWEETEDITOR.equals(mActiveTarget)) {
                mSweetEditor.setTraceSession(mSession);
            } else {
                mEditText.setTraceSession(mSession);
            }
            resetTargets(mCurrentCase);
            logUserMarker("caseStarted");
            prepareForManualTap();
            updateStatus("Recording: " + mSession.getDirectory().getAbsolutePath());
        } catch (IOException | JSONException e) {
            mSweetEditor.setTraceSession(null);
            mEditText.setTraceSession(null);
            mSession = null;
            updateFlowButtons(false);
            updateStatus("Failed to start case: " + e.getMessage());
            Toast.makeText(this, "Failed to start trace", Toast.LENGTH_LONG).show();
        }
    }

    private void finishAndOpenNextCase(String status) {
        finishCurrentSession(status);
        mCurrentCaseIndex++;
        beginCurrentCase();
    }

    private void retryCurrentCase() {
        if (mCurrentCaseIndex < 0) {
            return;
        }
        finishCurrentSession("retry");
        beginCurrentCase();
    }

    private void stopRun() {
        finishCurrentSession("stopped");
        mCurrentCase = null;
        mCurrentCaseIndex = -1;
        updateCaseText();
        updateFlowButtons(false);
    }

    private void finishCurrentSession(String status) {
        ImeTraceSession session = mSession;
        if (session == null) {
            return;
        }
        try {
            logUserMarker("caseFinished:" + status);
            JSONObject finalState = new JSONObject();
            finalState.put("target", mActiveTarget);
            finalState.put("sweeteditor", mSweetEditor.snapshot());
            finalState.put("edittext", mEditText.snapshot());
            session.finish(finalState, status);
            updateStatus("Saved: " + session.getDirectory().getAbsolutePath());
        } catch (IOException | JSONException e) {
            updateStatus("Failed to finish trace: " + e.getMessage());
        } finally {
            mSweetEditor.setTraceSession(null);
            mEditText.setTraceSession(null);
            mSession = null;
        }
    }

    private JSONObject buildManifest(@NonNull TraceCase traceCase) throws JSONException {
        JSONObject manifest = new JSONObject();
        manifest.put("schemaVersion", 4);
        manifest.put("inputMethodPackageName", currentInputMethodPackageName());
        manifest.put("target", mActiveTarget);
        manifest.put("caseId", traceCase.caseId);
        manifest.put("caseIndex", mCurrentCaseIndex);
        manifest.put("caseCount", TRACE_CASES.length);
        manifest.put("keyboardMode", traceCase.keyboardMode);
        manifest.put("steps", stepsToJson(traceCase));
        manifest.put("startedAt", wallClockNow());
        manifest.put("appPackage", getPackageName());
        manifest.put("repo", buildRepoInfo());
        manifest.put("device", buildDeviceInfo());
        manifest.put("inputMethod", buildInputMethodInfo());
        manifest.put("initialDocument", traceCase.initialText);
        return manifest;
    }

    private JSONObject buildRepoInfo() throws JSONException {
        JSONObject repo = new JSONObject();
        repo.put("source", "android-demo");
        repo.put("gitSha", BuildConfig.GIT_SHA);
        repo.put("gitBranch", BuildConfig.GIT_BRANCH);
        repo.put("buildTime", BuildConfig.BUILD_TIME);
        repo.put("versionName", BuildConfig.VERSION_NAME);
        return repo;
    }

    private JSONObject buildDeviceInfo() throws JSONException {
        JSONObject device = new JSONObject();
        device.put("manufacturer", Build.MANUFACTURER);
        device.put("brand", Build.BRAND);
        device.put("model", Build.MODEL);
        device.put("androidRelease", Build.VERSION.RELEASE);
        device.put("sdkInt", Build.VERSION.SDK_INT);
        device.put("fingerprint", Build.FINGERPRINT);
        return device;
    }

    private JSONObject buildInputMethodInfo() throws JSONException {
        JSONObject ime = new JSONObject();
        InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        String currentId = Settings.Secure.getString(getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
        ime.put("id", currentId != null ? currentId : "");
        String packageName = packageNameFromInputMethodId(currentId);
        ime.put("packageName", packageName);
        ime.put("versionName", "");
        ime.put("versionCode", "");
        if (!packageName.isEmpty()) {
            try {
                PackageInfo info = getPackageManager().getPackageInfo(packageName, 0);
                ime.put("versionName", info.versionName != null ? info.versionName : "");
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    ime.put("versionCode", info.getLongVersionCode());
                } else {
                    ime.put("versionCode", info.versionCode);
                }
            } catch (PackageManager.NameNotFoundException ignored) {
            }
        }
        if (imm != null) {
            List<InputMethodInfo> methods = imm.getEnabledInputMethodList();
            for (InputMethodInfo method : methods) {
                if (currentId != null && currentId.equals(method.getId())) {
                    ime.put("className", method.getServiceName());
                    CharSequence label = method.loadLabel(getPackageManager());
                    ime.put("label", label != null ? label.toString() : "");
                    break;
                }
            }
            InputMethodSubtype subtype = imm.getCurrentInputMethodSubtype();
            if (subtype != null) {
                ime.put("subtype", describeSubtype(subtype));
            }
        }
        return ime;
    }

    private JSONObject describeSubtype(InputMethodSubtype subtype) throws JSONException {
        JSONObject json = new JSONObject();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            json.put("languageTag", subtype.getLanguageTag());
        } else {
            json.put("languageTag", "");
        }
        json.put("locale", subtype.getLocale());
        json.put("mode", subtype.getMode());
        json.put("extraValue", subtype.getExtraValue());
        json.put("isAsciiCapable", subtype.isAsciiCapable());
        json.put("isAuxiliary", subtype.isAuxiliary());
        return json;
    }

    private String packageNameFromInputMethodId(@Nullable String id) {
        if (id == null || id.isEmpty()) {
            return "";
        }
        int slash = id.indexOf('/');
        return slash >= 0 ? id.substring(0, slash) : id;
    }

    private String currentInputMethodPackageName() {
        String currentId = Settings.Secure.getString(getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
        String packageName = packageNameFromInputMethodId(currentId);
        return packageName.isEmpty() ? UNKNOWN_IME_PACKAGE : packageName;
    }

    private JSONArray stepsToJson(@NonNull TraceCase traceCase) {
        JSONArray array = new JSONArray();
        for (String step : traceCase.steps) {
            array.put(step);
        }
        return array;
    }

    private String currentKeyboardMode() {
        return mCurrentCase != null ? mCurrentCase.keyboardMode : "unknown";
    }

    private void prepareForManualTap() {
        mSweetEditor.clearFocus();
        mEditText.clearFocus();
    }

    private void updateTargetVisibility() {
        boolean sweetEditorActive = TARGET_SWEETEDITOR.equals(mActiveTarget);
        if (mSweetEditor != null) {
            mSweetEditor.setVisibility(sweetEditorActive ? View.VISIBLE : View.GONE);
        }
        if (mEditText != null) {
            mEditText.setVisibility(sweetEditorActive ? View.GONE : View.VISIBLE);
        }
        if (mTargetLabel != null) {
            mTargetLabel.setText(sweetEditorActive ? "SweetEditor" : "EditText baseline");
        }
        if (mTargetButton != null) {
            mTargetButton.setText(sweetEditorActive ? "Target: Sweet" : "Target: EditText");
        }
    }

    private void updateFlowButtons(boolean recording) {
        if (mTargetButton != null) {
            mTargetButton.setEnabled(!recording);
        }
        if (mNextButton != null) {
            mNextButton.setEnabled(recording);
        }
        if (mRetryButton != null) {
            mRetryButton.setEnabled(recording);
        }
        if (mSkipButton != null) {
            mSkipButton.setEnabled(recording);
        }
        if (mStopButton != null) {
            mStopButton.setEnabled(recording);
        }
        if (mStartButton != null) {
            mStartButton.setEnabled(!recording);
        }
    }

    private void toggleTarget() {
        if (mSession != null) {
            return;
        }
        mActiveTarget = TARGET_SWEETEDITOR.equals(mActiveTarget)
                ? TARGET_EDITTEXT
                : TARGET_SWEETEDITOR;
        updateTargetVisibility();
        updateCaseText();
        resetTargetsForIdle();
        updateStatus("Target: " + mActiveTarget);
    }

    private void updateCaseText() {
        if (mCurrentCase == null) {
            if (mCaseTitleText != null) {
                mCaseTitleText.setText("No active case");
            }
            if (mStepsText != null) {
                mStepsText.setText("Tap Start and choose the first case to record.");
            }
            return;
        }
        String title = String.format(Locale.US,
                "%02d/%02d  %s  [%s, %s]",
                mCurrentCaseIndex + 1,
                TRACE_CASES.length,
                mCurrentCase.caseId,
                mActiveTarget,
                mCurrentCase.keyboardMode);
        mCaseTitleText.setText(title);
        StringBuilder steps = new StringBuilder();
        for (int i = 0; i < mCurrentCase.steps.length; i++) {
            if (i > 0) {
                steps.append('\n');
            }
            steps.append(i + 1).append(". ").append(mCurrentCase.steps[i]);
        }
        mStepsText.setText(steps.toString());
    }

    private void logUserMarker(String marker) {
        ImeTraceSession session = mSession;
        if (session == null) {
            return;
        }
        try {
            JSONObject args = new JSONObject();
            args.put("marker", marker);
            args.put("keyboardMode", currentKeyboardMode());
            args.put("target", mActiveTarget);
            if (mCurrentCase != null) {
                args.put("caseId", mCurrentCase.caseId);
                args.put("caseIndex", mCurrentCaseIndex);
            }
            JSONObject snapshots = new JSONObject();
            snapshots.put("sweeteditor", mSweetEditor.snapshot());
            snapshots.put("edittext", mEditText.snapshot());
            session.log("user", "marker", "event", args, null, snapshots);
        } catch (JSONException ignored) {
        }
    }

    private void logSystemEvent(String target, String method) {
        ImeTraceSession session = mSession;
        if (session == null) {
            return;
        }
        try {
            JSONObject snapshot = "sweeteditor".equals(target)
                    ? mSweetEditor.snapshot()
                    : mEditText.snapshot();
            session.log(target, method, "system", new JSONObject(), null, snapshot);
        } catch (JSONException ignored) {
        }
    }

    private void updateStatus(String message) {
        mStatusText.setText(message);
    }

    private LinearLayout horizontalRow() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setBaselineAligned(false);
        return row;
    }

    private TextView label(String text) {
        TextView label = new TextView(this);
        label.setText(text);
        label.setTextSize(13f);
        label.setTypeface(Typeface.DEFAULT_BOLD);
        label.setPadding(0, dp(8), 0, dp(4));
        return label;
    }

    private Button button(String text) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(text);
        return button;
    }

    private LinearLayout.LayoutParams weightedButtonParams() {
        return new LinearLayout.LayoutParams(0, dp(44), 1f);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static String wallClockNow() {
        return new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US).format(new Date());
    }

    private static final class TraceCase {
        final String caseId;
        final String keyboardMode;
        final int focusColumn;
        final String initialText;
        final String[] steps;

        TraceCase(String caseId,
                  String keyboardMode,
                  int focusColumn,
                  String... steps) {
            this.caseId = caseId;
            this.keyboardMode = keyboardMode;
            this.focusColumn = focusColumn;
            this.initialText = resolveInitialText(caseId);
            this.steps = steps;
        }

        private static String resolveInitialText(String caseId) {
            if ("EN_HELLO_CANDIDATE_DELETE_TO_EMPTY".equals(caseId)) {
                return "";
            }
            return SAMPLE_TEXT;
        }
    }

    public static class TraceSweetEditor extends SweetEditor implements TraceSnapshotProvider {
        @Nullable private ImeTraceActivity mTraceActivity;
        @Nullable private ImeTraceSession mSession;

        public TraceSweetEditor(Context context) {
            super(context);
        }

        public TraceSweetEditor(Context context, AttributeSet attrs) {
            super(context, attrs);
        }

        public TraceSweetEditor(Context context, AttributeSet attrs, int defStyleAttr) {
            super(context, attrs, defStyleAttr);
        }

        void setTraceActivity(@Nullable ImeTraceActivity activity) {
            mTraceActivity = activity;
        }

        void setTraceSession(@Nullable ImeTraceSession session) {
            mSession = session;
        }

        @Override
        public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
            InputConnection connection = super.onCreateInputConnection(outAttrs);
            ImeTraceSession session = mSession;
            if (session == null || connection == null) {
                return connection;
            }
            try {
                session.log("sweeteditor", "createInputConnection", "after",
                        new JSONObject(),
                        editorInfoToJson(outAttrs),
                        snapshot());
            } catch (JSONException ignored) {
            }
            return new TraceInputConnection(connection, true, session, "sweeteditor", this);
        }

        @Override
        public JSONObject snapshot() throws JSONException {
            JSONObject json = new JSONObject();
            Document document = getDocument();
            String text = document != null ? document.getText() : "";
            TextPosition cursor = getCursorPosition();
            TextRange selection = getSelection();
            json.put("documentText", text);
            json.put("cursor", positionToJson(cursor));
            json.put("cursorOffset", document != null ? document.getCharIndexFromPosition(cursor) : 0);
            json.put("selection", rangeToJson(selection));
            if (document != null && selection != null) {
                json.put("selectionStartOffset", document.getCharIndexFromPosition(selection.start));
                json.put("selectionEndOffset", document.getCharIndexFromPosition(selection.end));
            } else {
                json.put("selectionStartOffset", JSONObject.NULL);
                json.put("selectionEndOffset", JSONObject.NULL);
            }
            appendCoreSnapshot(json);
            return json;
        }

        private void appendCoreSnapshot(JSONObject json) throws JSONException {
            try {
                Method method = SweetEditor.class.getDeclaredMethod("getEditorCore");
                method.setAccessible(true);
                EditorCore core = (EditorCore) method.invoke(this);
                json.put("isComposing", core.isComposing());
                json.put("composingRange", rangeToJson(core.getComposingRange()));
                json.put("keyboardScriptClass", core.getImeKeyboardScriptClass());
                ImeSyncSnapshot snapshot = core.getImeSyncSnapshot();
                JSONObject sync = new JSONObject();
                sync.put("cursor", positionToJson(snapshot.cursor));
                sync.put("selection", rangeToJson(snapshot.selection));
                sync.put("hasComposingSession", snapshot.hasComposingSession);
                sync.put("visibleCompositionRange", rangeToJson(snapshot.visibleCompositionRange));
                sync.put("systemMarkRange", rangeToJson(snapshot.systemMarkRange));
                sync.put("preeditStorage", snapshot.preeditStorage);
                sync.put("contextPolicy", snapshot.contextPolicy);
                sync.put("clearSystemMark", snapshot.clearSystemMark);
                json.put("imeSync", sync);
            } catch (ReflectiveOperationException e) {
                json.put("coreSnapshotError", e.getClass().getSimpleName() + ": " + e.getMessage());
            }
        }
    }

    public static class TraceEditText extends EditText implements TraceSnapshotProvider {
        @Nullable private ImeTraceActivity mTraceActivity;
        @Nullable private ImeTraceSession mSession;

        public TraceEditText(Context context) {
            super(context);
        }

        public TraceEditText(Context context, AttributeSet attrs) {
            super(context, attrs);
        }

        public TraceEditText(Context context, AttributeSet attrs, int defStyleAttr) {
            super(context, attrs, defStyleAttr);
        }

        void setTraceActivity(@Nullable ImeTraceActivity activity) {
            mTraceActivity = activity;
        }

        void setTraceSession(@Nullable ImeTraceSession session) {
            mSession = session;
        }

        @Override
        public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
            InputConnection connection = super.onCreateInputConnection(outAttrs);
            ImeTraceSession session = mSession;
            if (session == null || connection == null) {
                return connection;
            }
            try {
                session.log("edittext", "createInputConnection", "after",
                        new JSONObject(),
                        editorInfoToJson(outAttrs),
                        snapshot());
            } catch (JSONException ignored) {
            }
            return new TraceInputConnection(connection, true, session, "edittext", this);
        }

        @Override
        protected void onSelectionChanged(int selStart, int selEnd) {
            super.onSelectionChanged(selStart, selEnd);
            ImeTraceActivity activity = mTraceActivity;
            if (activity != null) {
                activity.logSystemEvent("edittext", "selectionChanged");
            }
        }

        @Override
        public JSONObject snapshot() throws JSONException {
            JSONObject json = new JSONObject();
            Editable editable = getText();
            json.put("documentText", editable != null ? editable.toString() : "");
            json.put("selectionStartOffset", getSelectionStart());
            json.put("selectionEndOffset", getSelectionEnd());
            appendComposingSpan(json, editable);
            return json;
        }

        private void appendComposingSpan(JSONObject json, @Nullable Editable editable) throws JSONException {
            int composingStart = -1;
            int composingEnd = -1;
            if (editable != null) {
                Object[] spans = editable.getSpans(0, editable.length(), Object.class);
                for (Object span : spans) {
                    if ((editable.getSpanFlags(span) & Spanned.SPAN_COMPOSING) != 0) {
                        int start = editable.getSpanStart(span);
                        int end = editable.getSpanEnd(span);
                        if (start >= 0 && end >= 0) {
                            composingStart = composingStart < 0 ? start : Math.min(composingStart, start);
                            composingEnd = Math.max(composingEnd, end);
                        }
                    }
                }
            }
            json.put("composingStart", composingStart);
            json.put("composingEnd", composingEnd);
            json.put("hasComposingSpan", composingStart >= 0 && composingEnd >= composingStart);
        }
    }

    private static class TraceInputConnection extends InputConnectionWrapper {
        private final ImeTraceSession mSession;
        private final String mTarget;
        private final InputConnection mWrappedConnection;
        private final TraceSnapshotProvider mSnapshotProvider;

        TraceInputConnection(InputConnection target,
                             boolean mutable,
                             ImeTraceSession session,
                             String traceTarget,
                             TraceSnapshotProvider snapshotProvider) {
            super(target, mutable);
            mSession = session;
            mTarget = traceTarget;
            mWrappedConnection = target;
            mSnapshotProvider = snapshotProvider;
        }

        @Override
        public boolean beginBatchEdit() {
            return trace("beginBatchEdit", new JSONObject(), () -> super.beginBatchEdit());
        }

        @Override
        public boolean endBatchEdit() {
            return trace("endBatchEdit", new JSONObject(), () -> super.endBatchEdit());
        }

        @Override
        public boolean commitText(CharSequence text, int newCursorPosition) {
            return trace("commitText", args("text", text, "newCursorPosition", newCursorPosition),
                    () -> super.commitText(text, newCursorPosition));
        }

        @Override
        public boolean setComposingText(CharSequence text, int newCursorPosition) {
            return trace("setComposingText", args("text", text, "newCursorPosition", newCursorPosition),
                    () -> super.setComposingText(text, newCursorPosition));
        }

        @Override
        public boolean setComposingRegion(int start, int end) {
            return trace("setComposingRegion", args("start", start, "end", end),
                    () -> super.setComposingRegion(start, end));
        }

        @Override
        public boolean finishComposingText() {
            return trace("finishComposingText", new JSONObject(), () -> super.finishComposingText());
        }

        @Override
        public boolean setSelection(int start, int end) {
            return trace("setSelection", args("start", start, "end", end),
                    () -> super.setSelection(start, end));
        }

        @Override
        public boolean deleteSurroundingText(int beforeLength, int afterLength) {
            return trace("deleteSurroundingText", args("beforeLength", beforeLength, "afterLength", afterLength),
                    () -> super.deleteSurroundingText(beforeLength, afterLength));
        }

        @Override
        public boolean deleteSurroundingTextInCodePoints(int beforeLength, int afterLength) {
            return trace("deleteSurroundingTextInCodePoints",
                    args("beforeLength", beforeLength, "afterLength", afterLength),
                    () -> super.deleteSurroundingTextInCodePoints(beforeLength, afterLength));
        }

        @Override
        public CharSequence getTextBeforeCursor(int n, int flags) {
            return trace("getTextBeforeCursor", args("requestedLength", n, "flags", flags),
                    () -> super.getTextBeforeCursor(n, flags));
        }

        @Override
        public CharSequence getTextAfterCursor(int n, int flags) {
            return trace("getTextAfterCursor", args("requestedLength", n, "flags", flags),
                    () -> super.getTextAfterCursor(n, flags));
        }

        @Override
        public CharSequence getSelectedText(int flags) {
            return trace("getSelectedText", args("flags", flags), () -> super.getSelectedText(flags));
        }

        @Nullable
        @Override
        @TargetApi(Build.VERSION_CODES.S)
        public SurroundingText getSurroundingText(int beforeLength, int afterLength, int flags) {
            return trace("getSurroundingText",
                    args("beforeLength", beforeLength, "afterLength", afterLength, "flags", flags),
                    () -> super.getSurroundingText(beforeLength, afterLength, flags));
        }

        @Override
        public ExtractedText getExtractedText(ExtractedTextRequest request, int flags) {
            return trace("getExtractedText", args("request", request, "flags", flags),
                    () -> super.getExtractedText(request, flags));
        }

        @Override
        public boolean sendKeyEvent(KeyEvent event) {
            return trace("sendKeyEvent", args("event", keyEventToJson(event)),
                    () -> super.sendKeyEvent(event));
        }

        @Override
        public boolean performEditorAction(int editorAction) {
            return trace("performEditorAction", args("editorAction", editorAction),
                    () -> super.performEditorAction(editorAction));
        }

        @Override
        public boolean performContextMenuAction(int id) {
            return trace("performContextMenuAction", args("id", id),
                    () -> super.performContextMenuAction(id));
        }

        @Override
        public boolean requestCursorUpdates(int cursorUpdateMode) {
            return trace("requestCursorUpdates", args("cursorUpdateMode", cursorUpdateMode),
                    () -> super.requestCursorUpdates(cursorUpdateMode));
        }

        @Override
        public boolean commitCompletion(CompletionInfo text) {
            return trace("commitCompletion", args("completion", text),
                    () -> super.commitCompletion(text));
        }

        @Override
        public boolean commitCorrection(CorrectionInfo correctionInfo) {
            return trace("commitCorrection", args("correction", correctionInfo),
                    () -> super.commitCorrection(correctionInfo));
        }

        @Override
        public boolean setImeConsumesInput(boolean imeConsumesInput) {
            return trace("setImeConsumesInput", args("imeConsumesInput", imeConsumesInput),
                    () -> super.setImeConsumesInput(imeConsumesInput));
        }

        @Override
        @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
        public boolean replaceText(int start,
                                   int end,
                                   @NonNull CharSequence text,
                                   int newCursorPosition,
                                   @Nullable TextAttribute textAttribute) {
            return trace("replaceText",
                    args("start", start,
                            "end", end,
                            "text", text,
                            "newCursorPosition", newCursorPosition,
                            "textAttribute", textAttribute),
                    () -> super.replaceText(start, end, text, newCursorPosition, textAttribute));
        }

        @Override
        public void closeConnection() {
            traceVoid("closeConnection", new JSONObject(), super::closeConnection);
        }

        private <T> T trace(String method, JSONObject args, TraceCall<T> call) {
            log(method, "before", args, null);
            try {
                T result = call.run();
                log(method, "after", args, safeValueToJson(result));
                return result;
            } catch (RuntimeException e) {
                log(method, "error", args, e.getClass().getSimpleName() + ": " + e.getMessage());
                throw e;
            }
        }

        private void traceVoid(String method, JSONObject args, TraceVoidCall call) {
            log(method, "before", args, null);
            try {
                call.run();
                log(method, "after", args, "void");
            } catch (RuntimeException e) {
                log(method, "error", args, e.getClass().getSimpleName() + ": " + e.getMessage());
                throw e;
            }
        }

        private void log(String method, String phase, JSONObject args, @Nullable Object result) {
            try {
                JSONObject snapshot = mSnapshotProvider.snapshot();
                appendInputConnectionSnapshot(snapshot);
                mSession.log(mTarget, method, phase, args, result, snapshot);
            } catch (JSONException ignored) {
            }
        }

        private void appendInputConnectionSnapshot(JSONObject snapshot) throws JSONException {
            JSONObject json = new JSONObject();
            json.put("className", mWrappedConnection.getClass().getName());
            appendEditableSnapshot(json);
            appendPrivateField(json, "editableMarkedRole", "mEditableMarkedRole");
            appendPrivateField(json, "inputContextId", "mInputContextId");
            appendPrivateField(json, "inputContextRevision", "mInputContextRevision");
            appendPrivateField(json, "inputDocumentStartOffset", "mInputDocumentStartOffset");
            snapshot.put("inputConnection", json);
        }

        private void appendEditableSnapshot(JSONObject json) throws JSONException {
            try {
                Method method = mWrappedConnection.getClass().getMethod("getEditable");
                method.setAccessible(true);
                Object value = method.invoke(mWrappedConnection);
                if (value instanceof Editable) {
                    Editable editable = (Editable) value;
                    json.put("editableText", editable.toString());
                    json.put("editableSelectionStart", Selection.getSelectionStart(editable));
                    json.put("editableSelectionEnd", Selection.getSelectionEnd(editable));
                    appendComposingSpan(json, editable);
                }
            } catch (ReflectiveOperationException e) {
                json.put("editableSnapshotError", e.getClass().getSimpleName() + ": " + e.getMessage());
            }
        }

        private void appendPrivateField(JSONObject json, String jsonName, String fieldName) throws JSONException {
            Class<?> type = mWrappedConnection.getClass();
            while (type != null) {
                try {
                    Field field = type.getDeclaredField(fieldName);
                    field.setAccessible(true);
                    json.put(jsonName, safeValueToJson(field.get(mWrappedConnection)));
                    return;
                } catch (NoSuchFieldException e) {
                    type = type.getSuperclass();
                } catch (IllegalAccessException e) {
                    json.put(jsonName + "Error", e.getClass().getSimpleName() + ": " + e.getMessage());
                    return;
                }
            }
        }
    }

    private interface TraceSnapshotProvider {
        JSONObject snapshot() throws JSONException;
    }

    private interface TraceCall<T> {
        T run();
    }

    private interface TraceVoidCall {
        void run();
    }

    private static class ImeTraceSession {
        private final File mDirectory;
        private final BufferedWriter mEventsWriter;
        private final long mStartedElapsedNanos;
        private int mNextIndex;

        private ImeTraceSession(File directory, BufferedWriter eventsWriter) {
            mDirectory = directory;
            mEventsWriter = eventsWriter;
            mStartedElapsedNanos = SystemClock.elapsedRealtimeNanos();
        }

        static ImeTraceSession start(Context context,
                                     String inputMethodPackageName,
                                     String target,
                                     int caseIndex,
                                     String caseId,
                                     JSONObject manifest) throws IOException, JSONException {
            File root = new File(context.getExternalFilesDir(null), "ime-traces-v4");
            String caseDirectory = String.format(Locale.US,
                    "%02d_%s",
                    caseIndex + 1,
                    sanitize(caseId));
            File dir = new File(new File(new File(root, sanitize(inputMethodPackageName)), sanitize(target)),
                    caseDirectory);
            deleteRecursively(dir);
            if (!dir.mkdirs() && !dir.isDirectory()) {
                throw new IOException("Cannot create " + dir.getAbsolutePath());
            }
            writeJson(new File(dir, "manifest.json"), manifest);
            return new ImeTraceSession(dir, new BufferedWriter(new FileWriter(new File(dir, "events.ndjson"), true)));
        }

        File getDirectory() {
            return mDirectory;
        }

        synchronized void log(String target,
                              String method,
                              String phase,
                              JSONObject args,
                              @Nullable Object result,
                              @Nullable JSONObject snapshot) throws JSONException {
            JSONObject event = new JSONObject();
            event.put("index", mNextIndex++);
            event.put("elapsedNanos", SystemClock.elapsedRealtimeNanos() - mStartedElapsedNanos);
            event.put("thread", Thread.currentThread().getName());
            event.put("target", target);
            event.put("method", method);
            event.put("phase", phase);
            event.put("args", args);
            event.put("result", result != null ? result : JSONObject.NULL);
            event.put("snapshot", snapshot != null ? snapshot : JSONObject.NULL);
            try {
                mEventsWriter.write(event.toString());
                mEventsWriter.newLine();
                mEventsWriter.flush();
            } catch (IOException e) {
                throw new JSONException(e);
            }
        }

        synchronized void finish(JSONObject finalState, String status) throws IOException, JSONException {
            JSONObject json = new JSONObject();
            json.put("finishedAt", wallClockNow());
            json.put("status", status);
            json.put("eventCount", mNextIndex);
            json.put("finalState", finalState);
            writeJson(new File(mDirectory, "final.json"), json);
            mEventsWriter.flush();
            mEventsWriter.close();
        }

        private static void writeJson(File file, JSONObject json) throws IOException, JSONException {
            try (BufferedWriter writer = new BufferedWriter(new FileWriter(file, false))) {
                writer.write(json.toString(2));
                writer.newLine();
            }
        }

        private static void deleteRecursively(File file) throws IOException {
            if (!file.exists()) {
                return;
            }
            if (file.isDirectory()) {
                File[] children = file.listFiles();
                if (children != null) {
                    for (File child : children) {
                        deleteRecursively(child);
                    }
                }
            }
            if (!file.delete()) {
                throw new IOException("Cannot delete " + file.getAbsolutePath());
            }
        }
    }

    private static JSONObject editorInfoToJson(EditorInfo info) throws JSONException {
        JSONObject json = new JSONObject();
        json.put("inputType", info.inputType);
        json.put("imeOptions", info.imeOptions);
        json.put("initialSelStart", info.initialSelStart);
        json.put("initialSelEnd", info.initialSelEnd);
        json.put("initialCapsMode", info.initialCapsMode);
        return json;
    }

    private static JSONObject positionToJson(@Nullable TextPosition position) throws JSONException {
        if (position == null) {
            return null;
        }
        JSONObject json = new JSONObject();
        json.put("line", position.line);
        json.put("column", position.column);
        return json;
    }

    private static Object rangeToJson(@Nullable TextRange range) throws JSONException {
        if (range == null) {
            return JSONObject.NULL;
        }
        JSONObject json = new JSONObject();
        json.put("start", positionToJson(range.start));
        json.put("end", positionToJson(range.end));
        return json;
    }

    private static Object intRangeToJson(@Nullable IntRange range) throws JSONException {
        if (range == null) {
            return JSONObject.NULL;
        }
        JSONObject json = new JSONObject();
        json.put("start", range.start);
        json.put("end", range.end);
        return json;
    }

    private static JSONObject keyEventToJson(@Nullable KeyEvent event) {
        JSONObject json = new JSONObject();
        if (event == null) {
            return json;
        }
        try {
            json.put("action", event.getAction());
            json.put("keyCode", event.getKeyCode());
            json.put("unicodeChar", event.getUnicodeChar());
            json.put("repeatCount", event.getRepeatCount());
            json.put("metaState", event.getMetaState());
        } catch (JSONException ignored) {
        }
        return json;
    }

    private static void appendComposingSpan(JSONObject json, @Nullable Editable editable) throws JSONException {
        int composingStart = -1;
        int composingEnd = -1;
        if (editable != null) {
            Object[] spans = editable.getSpans(0, editable.length(), Object.class);
            for (Object span : spans) {
                if ((editable.getSpanFlags(span) & Spanned.SPAN_COMPOSING) != 0) {
                    int start = editable.getSpanStart(span);
                    int end = editable.getSpanEnd(span);
                    if (start >= 0 && end >= 0) {
                        composingStart = composingStart < 0 ? start : Math.min(composingStart, start);
                        composingEnd = Math.max(composingEnd, end);
                    }
                }
            }
        }
        json.put("composingStart", composingStart);
        json.put("composingEnd", composingEnd);
        json.put("hasComposingSpan", composingStart >= 0 && composingEnd >= composingStart);
    }

    private static JSONObject args(Object... pairs) {
        JSONObject json = new JSONObject();
        for (int i = 0; i + 1 < pairs.length; i += 2) {
            try {
                json.put(String.valueOf(pairs[i]), valueToJson(pairs[i + 1]));
            } catch (JSONException ignored) {
            }
        }
        return json;
    }

    private static Object safeValueToJson(@Nullable Object value) {
        try {
            return valueToJson(value);
        } catch (JSONException e) {
            return String.valueOf(value);
        }
    }

    private static Object valueToJson(@Nullable Object value) throws JSONException {
        if (value == null) {
            return JSONObject.NULL;
        }
        if (value instanceof CharSequence) {
            return describeCharSequence((CharSequence) value);
        }
        if (value instanceof JSONObject || value instanceof Number || value instanceof Boolean) {
            return value;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && value instanceof SurroundingText) {
            SurroundingText text = (SurroundingText) value;
            JSONObject json = new JSONObject();
            json.put("text", text.getText() != null ? text.getText().toString() : "");
            json.put("selectionStart", text.getSelectionStart());
            json.put("selectionEnd", text.getSelectionEnd());
            json.put("offset", text.getOffset());
            return json;
        }
        return String.valueOf(value);
    }

    private static JSONObject describeCharSequence(CharSequence value) throws JSONException {
        JSONObject json = new JSONObject();
        json.put("text", value.toString());
        json.put("length", value.length());
        if (value instanceof Spanned) {
            Spanned spanned = (Spanned) value;
            int composingStart = -1;
            int composingEnd = -1;
            Object[] spans = spanned.getSpans(0, spanned.length(), Object.class);
            for (Object span : spans) {
                if ((spanned.getSpanFlags(span) & Spanned.SPAN_COMPOSING) != 0) {
                    int start = spanned.getSpanStart(span);
                    int end = spanned.getSpanEnd(span);
                    composingStart = composingStart < 0 ? start : Math.min(composingStart, start);
                    composingEnd = Math.max(composingEnd, end);
                }
            }
            json.put("composingStart", composingStart);
            json.put("composingEnd", composingEnd);
        }
        return json;
    }

    private static String sanitize(String value) {
        String trimmed = value == null ? "" : value.trim();
        if (trimmed.isEmpty()) {
            return "trace";
        }
        return trimmed.replaceAll("[^A-Za-z0-9._-]+", "_");
    }
}
