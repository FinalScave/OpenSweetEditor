package com.qiplat.sweeteditor.demo;

import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsetsController;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ImageButton;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;

import com.qiplat.sweeteditor.EditorSettings;
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.LanguageConfiguration;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.copilot.InlineSuggestion;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.foundation.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.foundation.FoldArrowMode;
import com.qiplat.sweeteditor.core.foundation.WrapMode;
import com.qiplat.sweeteditor.event.CursorChangedEvent;
import com.qiplat.sweeteditor.event.GutterIconClickEvent;
import com.qiplat.sweeteditor.event.InlayHintClickEvent;
import com.qiplat.sweeteditor.event.TextChangedEvent;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class MainActivity extends AppCompatActivity {
    private static final int STYLE_COLOR = EditorTheme.STYLE_PREPROCESSOR + 1;
    private static final String DEMO_FILES_ASSET_DIR = "files";
    private static final String FALLBACK_FILE_NAME = "sample.cpp";

    private static final int DARK_BG = 0xFF1B1E24;
    private static final int DARK_FG = 0xFFD7DEE9;
    private static final int DARK_SECONDARY = 0xFF5E6778;
    private static final int LIGHT_BG = 0xFFFAFBFD;
    private static final int LIGHT_FG = 0xFF1F2937;
    private static final int LIGHT_SECONDARY = 0xFF8A94A6;

    private SweetEditor mEditor;
    private TextView mStatusBar;
    private View mToolbarContainer;
    private ImageButton mBtnUndo;
    private ImageButton mBtnRedo;
    private ImageButton mBtnTheme;
    private ImageButton mBtnWrap;
    private Spinner mFileSpinner;

    private boolean mIsDarkTheme = true;
    private WrapMode mWrapModePreset = WrapMode.NONE;
    private final List<String> mDemoFiles = new ArrayList<>();

    private DemoDecorationProvider mDemoProvider;
    private DemoCompletionProvider mDemoCompletionProvider;
    private final Handler mSuggestionHandler = new Handler(Looper.getMainLooper());
    private Runnable mPendingSuggestion;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setupImmersiveWindow();
        setContentView(R.layout.activity_main);

        mEditor = findViewById(R.id.editor);
        mStatusBar = findViewById(R.id.tv_status);
        mToolbarContainer = findViewById(R.id.toolbar_container);
        mBtnUndo = findViewById(R.id.btn_undo);
        mBtnRedo = findViewById(R.id.btn_redo);
        mBtnTheme = findViewById(R.id.btn_switch_theme);
        mBtnWrap = findViewById(R.id.btn_wrap_mode);
        mFileSpinner = findViewById(R.id.spn_files);

        applyToolbarInsets();

        EditorSettings settings = mEditor.getSettings();
        settings.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        settings.setEditorTextSize(28f);
        settings.setFoldArrowMode(FoldArrowMode.AUTO);
        settings.setMaxGutterIcons(1);
        settings.setGutterSticky(true);
        settings.setGutterVisible(false);
        settings.setCurrentLineRenderMode(CurrentLineRenderMode.BORDER);
        registerColorStyleForCurrentTheme();

        try {
            DemoDecorationProvider.ensureSweetLineReady(this);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        mDemoProvider = new DemoDecorationProvider(mEditor);
        mEditor.addDecorationProvider(mDemoProvider);

        mDemoCompletionProvider = new DemoCompletionProvider();
        mEditor.addCompletionProvider(mDemoCompletionProvider);

        mEditor.setEditorIconProvider(iconId -> {
            if (iconId == DemoDecorationProvider.ICON_TYPE) {
                return ContextCompat.getDrawable(this, R.mipmap.ic_gutter_down);
            } else if (iconId == DemoDecorationProvider.ICON_AT) {
                return ContextCompat.getDrawable(this, R.mipmap.ic_gutter_at);
            }
            return null;
        });

        setupToolbar();
        setupFileSpinner();
        subscribeEditorEvents();
        applyAppTheme();
    }

    private void setupImmersiveWindow() {
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        Window window = getWindow();
        window.setStatusBarColor(Color.TRANSPARENT);
        window.setNavigationBarColor(Color.TRANSPARENT);
    }

    private void applyToolbarInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(mToolbarContainer, (v, insets) -> {
            int top = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top;
            v.setPadding(v.getPaddingLeft(), top + 6, v.getPaddingRight(), v.getPaddingBottom());
            return insets;
        });
    }

    private void applyAppTheme() {
        int bg = mIsDarkTheme ? DARK_BG : LIGHT_BG;
        int fg = mIsDarkTheme ? DARK_FG : LIGHT_FG;
        int secondary = mIsDarkTheme ? DARK_SECONDARY : LIGHT_SECONDARY;

        mToolbarContainer.setBackgroundColor(bg);
        tintImageButton(mBtnUndo, fg);
        tintImageButton(mBtnRedo, fg);
        tintImageButton(mBtnTheme, fg);
        tintImageButton(mBtnWrap, fg);

        mStatusBar.setBackgroundColor(bg);
        mStatusBar.setTextColor(secondary);

        updateStatusBarAppearance();
        updateSpinnerTheme(fg, bg);
    }

    private void tintImageButton(ImageButton btn, int color) {
        btn.setColorFilter(color, PorterDuff.Mode.SRC_IN);
    }

    private void updateStatusBarAppearance() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsetsController ctrl = getWindow().getInsetsController();
            if (ctrl != null) {
                if (mIsDarkTheme) {
                    ctrl.setSystemBarsAppearance(0,
                            WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS);
                } else {
                    ctrl.setSystemBarsAppearance(
                            WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS,
                            WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS);
                }
            }
        } else {
            View decorView = getWindow().getDecorView();
            int flags = decorView.getSystemUiVisibility();
            if (mIsDarkTheme) {
                flags &= ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            } else {
                flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            }
            decorView.setSystemUiVisibility(flags);
        }
    }

    private void updateSpinnerTheme(int textColor, int bgColor) {
        ArrayAdapter<String> adapter = new ArrayAdapter<String>(this,
                android.R.layout.simple_spinner_item, mDemoFiles) {
            @NonNull
            @Override
            public View getView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
                TextView tv = (TextView) super.getView(position, convertView, parent);
                tv.setTextColor(textColor);
                tv.setTextSize(13f);
                return tv;
            }

            @Override
            public View getDropDownView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
                TextView tv = (TextView) super.getDropDownView(position, convertView, parent);
                tv.setTextColor(textColor);
                tv.setBackgroundColor(bgColor);
                tv.setPadding(24, 20, 24, 20);
                return tv;
            }
        };
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        int currentSelection = mFileSpinner.getSelectedItemPosition();
        mFileSpinner.setAdapter(adapter);
        if (currentSelection >= 0 && currentSelection < mDemoFiles.size()) {
            mFileSpinner.setSelection(currentSelection);
        }
    }

    private void subscribeEditorEvents() {
        mEditor.subscribe(TextChangedEvent.class, e -> {
            String rangeStr = e.changeRange != null
                    ? e.changeRange.start.line + ":" + e.changeRange.start.column
                    + "-" + e.changeRange.end.line + ":" + e.changeRange.end.column
                    : "null";
            String textPreview = e.text != null
                    ? (e.text.length() > 50 ? e.text.substring(0, 50) + "..." : e.text).replace("\n", "\\n")
                    : "null";
            Log.d("SweetEditor", "[TextChanged] action=" + e.action.name() + " range=" + rangeStr + " text=" + textPreview);
        });
        mEditor.subscribe(InlayHintClickEvent.class, e -> {
            if (e.isColor) {
                Toast.makeText(this, "Click color: " + String.format("0X%X", e.colorValue), Toast.LENGTH_SHORT).show();
            } else if (!e.isIcon) {
                Toast.makeText(this, "Click inlay hint: (" + e.line + "," + e.column + ")", Toast.LENGTH_SHORT).show();
            }
        });
        mEditor.subscribe(GutterIconClickEvent.class, e ->
                Toast.makeText(this, "Click icon at line: " + e.line, Toast.LENGTH_SHORT).show());

        mEditor.subscribe(CursorChangedEvent.class, e -> scheduleSuggestionIfAtLineEnd(e));

        mEditor.setInlineSuggestionListener(new com.qiplat.sweeteditor.copilot.InlineSuggestionListener() {
            @Override
            public void onSuggestionAccepted(@NonNull InlineSuggestion suggestion) {
                updateStatus("Accepted suggestion at line " + suggestion.line);
            }

            @Override
            public void onSuggestionDismissed(@NonNull InlineSuggestion suggestion) {
                updateStatus("Dismissed suggestion at line " + suggestion.line);
            }
        });
    }

    private void scheduleSuggestionIfAtLineEnd(@NonNull CursorChangedEvent event) {
        cancelPendingSuggestion();
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return;
        }
        int line = event.cursorPosition.line;
        int column = event.cursorPosition.column;
        String lineText = doc.getLineText(line);
        if (lineText == null || column != lineText.length() || lineText.trim().isEmpty()) {
            return;
        }
        mPendingSuggestion = () -> {
            if (mEditor.isInlineSuggestionShowing()) {
                return;
            }
            String demoText = "\nvoid autoGenerated() {\n    std::cout << \"hello\" << std::endl;\n    return;\n}";
            mEditor.showInlineSuggestion(new InlineSuggestion(line, column, demoText));
        };
        mSuggestionHandler.postDelayed(mPendingSuggestion, 1000);
    }

    private void cancelPendingSuggestion() {
        if (mPendingSuggestion != null) {
            mSuggestionHandler.removeCallbacks(mPendingSuggestion);
            mPendingSuggestion = null;
        }
    }

    private void setupFileSpinner() {
        mDemoFiles.clear();
        mDemoFiles.addAll(listDemoFiles());
        if (mDemoFiles.isEmpty()) {
            mDemoFiles.add(FALLBACK_FILE_NAME);
        }

        mFileSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (position < 0 || position >= mDemoFiles.size()) {
                    return;
                }
                loadDemoFile(mDemoFiles.get(position));
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
    }

    private List<String> listDemoFiles() {
        List<String> files = new ArrayList<>();
        try {
            String[] entries = getAssets().list(DEMO_FILES_ASSET_DIR);
            if (entries == null) {
                return files;
            }
            for (String name : entries) {
                if (name == null || name.trim().isEmpty()) {
                    continue;
                }
                String assetPath = DEMO_FILES_ASSET_DIR + "/" + name;
                try (InputStream ignored = getAssets().open(assetPath)) {
                    files.add(name);
                } catch (IOException ignored) {
                }
            }
            Collections.sort(files, String.CASE_INSENSITIVE_ORDER);
        } catch (IOException e) {
            Log.e("SweetEditor", "Failed to list demo files", e);
        }
        return files;
    }

    private void loadDemoFile(String fileName) {
        String assetPath = DEMO_FILES_ASSET_DIR + "/" + fileName;
        String code = loadAsset(assetPath);
        mEditor.loadDocument(new Document(code));
        mEditor.setMetadata(new DemoFileMetadata(fileName));
        mEditor.post(mEditor::requestDecorationRefresh);
        updateStatus("Loaded: " + fileName);
    }

    private String loadAsset(String fileName) {
        StringBuilder sb = new StringBuilder();
        try (InputStream is = getAssets().open(fileName);
             BufferedReader reader = new BufferedReader(new InputStreamReader(is))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (sb.length() > 0) {
                    sb.append('\n');
                }
                sb.append(line);
            }
        } catch (IOException e) {
            Log.e("SweetEditor", "Failed to load asset: " + fileName, e);
        }
        return sb.toString();
    }

    private void setupToolbar() {
        mBtnUndo.setOnClickListener(v -> {
            if (mEditor.canUndo()) {
                mEditor.undo();
                updateStatus("Undo");
            } else {
                updateStatus("Nothing to undo");
            }
        });

        mBtnRedo.setOnClickListener(v -> {
            if (mEditor.canRedo()) {
                mEditor.redo();
                updateStatus("Redo");
            } else {
                updateStatus("Nothing to redo");
            }
        });

        mBtnTheme.setOnClickListener(v -> {
            mIsDarkTheme = !mIsDarkTheme;
            mEditor.applyTheme(mIsDarkTheme ? EditorTheme.dark() : EditorTheme.light());
            registerColorStyleForCurrentTheme();
            applyAppTheme();
            updateStatus(mIsDarkTheme ? "Dark theme" : "Light theme");
        });

        mBtnWrap.setOnClickListener(v -> cycleWrapMode());
    }

    private void cycleWrapMode() {
        WrapMode[] wrapModes = WrapMode.values();
        mWrapModePreset = wrapModes[(mWrapModePreset.ordinal() + 1) % wrapModes.length];
        mEditor.getSettings().setWrapMode(mWrapModePreset);
        updateStatus("WrapMode: " + mWrapModePreset.name());
    }

    private void updateStatus(String message) {
        mStatusBar.setText(message);
    }

    private void registerColorStyleForCurrentTheme() {
        int color = mIsDarkTheme ? 0xFFB5CEA8 : 0xFF098658;
        mEditor.registerTextStyle(STYLE_COLOR, color, 0);
    }
}

