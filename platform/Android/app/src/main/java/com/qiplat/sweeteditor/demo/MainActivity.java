package com.qiplat.sweeteditor.demo;

import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.util.Log;
import android.util.SparseArray;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.InlayType;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.foundation.FoldArrowMode;
import com.qiplat.sweeteditor.core.foundation.WrapMode;
import com.qiplat.sweeteditor.event.GutterIconClickEvent;
import com.qiplat.sweeteditor.event.InlayHintClickEvent;
import com.qiplat.sweeteditor.event.TextChangedEvent;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Arrays;

public class MainActivity extends AppCompatActivity {
    private SweetEditor mEditor;
    private TextView mStatusBar;
    private boolean mIsDarkTheme = true;
    private WrapMode mWrapModePreset = WrapMode.NONE;

    // Gutter icon ID constants
    private static final int GUTTER_ICON_BREAKPOINT = 1;
    private static final int GUTTER_ICON_ERROR = 2;
    private static final int GUTTER_ICON_WARNING = 3;
    private static final int GUTTER_ICON_BOOKMARK = 4;
    private static final int STYLE_COLOR = 9;

    private DemoDecorationProvider mDemoProvider;
    private DemoCompletionProvider mDemoCompletionProvider;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mEditor = findViewById(R.id.editor);
        mStatusBar = findViewById(R.id.tv_status);

        // Set editor initial properties
        mEditor.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        mEditor.setEditorTextSize(36f);
        mEditor.setFoldArrowMode(FoldArrowMode.AUTO);
        mEditor.setMaxGutterIcons(1);
        registerColorStyleForCurrentTheme();

        // Load initial document and apply decorations
        loadSampleDocument();

        // Register DecorationProvider (demonstrates Receiver callback mode)
        mDemoProvider = new DemoDecorationProvider(this, mEditor);
        mEditor.addDecorationProvider(mDemoProvider);

        // Register CompletionProvider (demonstrates completion callback mode)
        mDemoCompletionProvider = new DemoCompletionProvider();
        mEditor.addCompletionProvider(mDemoCompletionProvider);

        // Provide icon for editor
        mEditor.setEditorIconProvider(iconId -> {
            if (iconId == DemoDecorationProvider.ICON_CLASS) {
                return ContextCompat.getDrawable(this, R.mipmap.ic_gutter_icon1);
            }
            return null;
        });

        // Bind toolbar buttons
        setupToolbar();

        // Listen to text change events
        mEditor.subscribe(TextChangedEvent.class, e -> {
            String rangeStr = e.changeRange != null
                    ? e.changeRange.start.line + ":" + e.changeRange.start.column
                      + "-" + e.changeRange.end.line + ":" + e.changeRange.end.column
                    : "null";
            String textPreview = e.text != null
                    ? (e.text.length() > 50 ? e.text.substring(0, 50) + "..." : e.text).replace("\n", "↵")
                    : "null";
            Log.d("SweetEditor", "[TextChanged] action=" + e.action.name() + " range=" + rangeStr + " text=" + textPreview);
        });
        mEditor.subscribe(InlayHintClickEvent.class, e -> {
            if (e.isColor) {
                Toast.makeText(this, "Click color: "
                        + String.format("0X%X", e.colorValue), Toast.LENGTH_SHORT).show();
            }
        });
        mEditor.subscribe(GutterIconClickEvent.class, e -> {
            Toast.makeText(this, "Click icon at line: " + e.line, Toast.LENGTH_SHORT).show();
        });

        updateStatus("Document loaded");
    }

    private void loadSampleDocument() {
        String code = loadAsset("sample.cpp");
        Document document = new Document(code);
        mEditor.loadDocument(document);
    }

    private String loadAsset(String fileName) {
        StringBuilder sb = new StringBuilder();
        try (InputStream is = getAssets().open(fileName);
             BufferedReader reader = new BufferedReader(new InputStreamReader(is))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (sb.length() > 0) sb.append('\n');
                sb.append(line);
            }
        } catch (IOException e) {
            Log.e("SweetEditor", "Failed to load asset: " + fileName, e);
        }
        return sb.toString();
    }

    private void setupToolbar() {
        // Undo
        Button btnUndo = findViewById(R.id.btn_undo);
        btnUndo.setOnClickListener(v -> {
            if (mEditor.canUndo()) {
                mEditor.undo();
                updateStatus("Undo");
            } else {
                updateStatus("Nothing to undo");
            }
        });

        // Redo
        Button btnRedo = findViewById(R.id.btn_redo);
        btnRedo.setOnClickListener(v -> {
            if (mEditor.canRedo()) {
                mEditor.redo();
                updateStatus("Redo");
            } else {
                updateStatus("Nothing to redo");
            }
        });

        // Select All
        Button btnSelectAll = findViewById(R.id.btn_select_all);
        btnSelectAll.setOnClickListener(v -> {
            mEditor.selectAll();
            updateStatus("All selected");
        });

        // Get Selection
        Button btnGetSelection = findViewById(R.id.btn_get_selection);
        btnGetSelection.setOnClickListener(v -> {
            String selected = mEditor.getSelectedText();
            if (selected != null && !selected.isEmpty()) {
                String preview = selected.length() > 100
                        ? selected.substring(0, 100) + "..."
                        : selected;
                updateStatus("Selection: " + preview.replace("\n", "↵"));
                Toast.makeText(this, "Selection length: " + selected.length() + " chars", Toast.LENGTH_SHORT).show();
            } else {
                updateStatus("No selection");
            }
        });

        // Toggle theme
        Button btnSwitchTheme = findViewById(R.id.btn_switch_theme);
        btnSwitchTheme.setOnClickListener(v -> {
            mIsDarkTheme = !mIsDarkTheme;
            mEditor.applyTheme(mIsDarkTheme ? EditorTheme.dark() : EditorTheme.light());
            registerColorStyleForCurrentTheme();
            updateStatus(mIsDarkTheme ? "Switched to dark theme" : "Switched to light theme");
        });

        // WrapMode
        Button btnWrapMode = findViewById(R.id.btn_wrap_mode);
        btnWrapMode.setOnClickListener(v -> cycleWrapMode());
    }

    private void cycleWrapMode() {
        WrapMode[] wrapModes = WrapMode.values();
        mWrapModePreset = wrapModes[(mWrapModePreset.ordinal() + 1) % wrapModes.length];
        mEditor.setWrapMode(mWrapModePreset);
        updateStatus("WrapMode: " + mWrapModePreset.name());
    }

    private void updateStatus(String message) {
        mStatusBar.setText(message);
    }

    private void registerColorStyleForCurrentTheme() {
        int color = mIsDarkTheme ? 0xFFB5CEA8 : 0xFF098658;
        mEditor.registerStyle(STYLE_COLOR, color, 0);
    }
}
