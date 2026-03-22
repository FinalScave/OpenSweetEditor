package com.qiplat.sweeteditor.demo;

import android.graphics.Typeface;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.qiplat.sweeteditor.EditorSettings;
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.foundation.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.foundation.FoldArrowMode;
import com.qiplat.sweeteditor.core.foundation.WrapMode;
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

    private SweetEditor mEditor;
    private TextView mStatusBar;
    private boolean mIsDarkTheme = true;
    private WrapMode mWrapModePreset = WrapMode.NONE;
    private final List<String> mDemoFiles = new ArrayList<>();

    private DemoDecorationProvider mDemoProvider;
    private DemoCompletionProvider mDemoCompletionProvider;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mEditor = findViewById(R.id.editor);
        mStatusBar = findViewById(R.id.tv_status);

        EditorSettings settings = mEditor.getSettings();
        settings.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        settings.setEditorTextSize(36f);
        settings.setFoldArrowMode(FoldArrowMode.AUTO);
        settings.setMaxGutterIcons(1);
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
    }

    private void setupFileSpinner() {
        Spinner fileSpinner = findViewById(R.id.spn_files);
        mDemoFiles.clear();
        mDemoFiles.addAll(listDemoFiles());
        if (mDemoFiles.isEmpty()) {
            mDemoFiles.add(FALLBACK_FILE_NAME);
        }

        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, mDemoFiles);
        fileSpinner.setAdapter(adapter);

        fileSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (position < 0 || position >= mDemoFiles.size()) {
                    return;
                }
                loadDemoFile(mDemoFiles.get(position));
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // no-op
            }
        });

        if (!mDemoFiles.isEmpty()) {
            fileSpinner.setSelection(0);
        }
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
                    // Ignore directory entries under assets/files.
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
        Button btnUndo = findViewById(R.id.btn_undo);
        btnUndo.setOnClickListener(v -> {
            if (mEditor.canUndo()) {
                mEditor.undo();
                updateStatus("Undo");
            } else {
                updateStatus("Nothing to undo");
            }
        });

        Button btnRedo = findViewById(R.id.btn_redo);
        btnRedo.setOnClickListener(v -> {
            if (mEditor.canRedo()) {
                mEditor.redo();
                updateStatus("Redo");
            } else {
                updateStatus("Nothing to redo");
            }
        });

        Button btnSwitchTheme = findViewById(R.id.btn_switch_theme);
        btnSwitchTheme.setOnClickListener(v -> {
            mIsDarkTheme = !mIsDarkTheme;
            mEditor.applyTheme(mIsDarkTheme ? EditorTheme.dark() : EditorTheme.light());
            registerColorStyleForCurrentTheme();
            updateStatus(mIsDarkTheme ? "Switched to dark theme" : "Switched to light theme");
        });

        Button btnWrapMode = findViewById(R.id.btn_wrap_mode);
        btnWrapMode.setOnClickListener(v -> cycleWrapMode());
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

