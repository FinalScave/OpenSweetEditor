package com.qiplat.sweeteditor.demo;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.Typeface;
import android.net.Uri;
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
import android.widget.PopupMenu;
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
import com.qiplat.sweeteditor.core.adornment.InlayType;
import com.qiplat.sweeteditor.core.config.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.config.FoldArrowMode;
import com.qiplat.sweeteditor.core.config.WhitespaceRenderMode;
import com.qiplat.sweeteditor.core.config.WrapMode;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.search.SearchState;
import com.qiplat.sweeteditor.core.search.SearchStatus;
import com.qiplat.sweeteditor.demo.search.SearchPanel;
import com.qiplat.sweeteditor.event.CursorChangedEvent;
import com.qiplat.sweeteditor.event.CodeLensClickEvent;
import com.qiplat.sweeteditor.event.GutterIconClickEvent;
import com.qiplat.sweeteditor.event.InlayHintClickEvent;
import com.qiplat.sweeteditor.event.LinkClickEvent;
import com.qiplat.sweeteditor.event.TextChangedEvent;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class MainActivity extends AppCompatActivity {
    private static final int STYLE_COLOR = DemoDecorationProvider.STYLE_COLOR;
    private static final int STYLE_LINK = DemoDecorationProvider.STYLE_LINK;
    private static final String DEMO_FILES_ASSET_DIR = "files";
    private static final String FALLBACK_FILE_NAME = "sample.cpp";

    private static final int DARK_BG = 0xFF1B1E24;
    private static final int DARK_FG = 0xFFD7DEE9;
    private static final int DARK_SECONDARY = 0xFF5E6778;
    private static final int LIGHT_BG = 0xFFFAFBFD;
    private static final int LIGHT_FG = 0xFF1F2937;
    private static final int LIGHT_SECONDARY = 0xFF8A94A6;
    private static final int MENU_SEARCH = 1;
    private static final int MENU_REPLACE = 2;
    private static final int MENU_WRAP = 3;

    private SweetEditor mEditor;
    private TextView mStatusBar;
    private View mToolbarContainer;
    private SearchPanel mSearchPanel;
    private ImageButton mBtnUndo;
    private ImageButton mBtnRedo;
    private ImageButton mBtnTheme;
    private ImageButton mBtnMore;
    private Spinner mFileSpinner;
    private ArrayAdapter<String> mFileAdapter;

    private boolean mIsDarkTheme = true;
    private WrapMode mWrapModePreset = WrapMode.NONE;
    private final List<String> mDemoFiles = new ArrayList<>();

    private DemoDecorationProvider mDemoProvider;
    private DemoCompletionProvider mDemoCompletionProvider;
    private final Handler mSuggestionHandler = new Handler(Looper.getMainLooper());
    private Runnable mPendingSuggestion;
    private int mSuggestionShownCount = 0;
    private static final int MAX_SUGGESTION_SHOWN = 2;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setupImmersiveWindow();
        setContentView(R.layout.activity_main);

        mEditor = findViewById(R.id.editor);
        mStatusBar = findViewById(R.id.tv_status);
        mToolbarContainer = findViewById(R.id.toolbar_container);
        mSearchPanel = findViewById(R.id.search_panel);
        mBtnUndo = findViewById(R.id.btn_undo);
        mBtnRedo = findViewById(R.id.btn_redo);
        mBtnTheme = findViewById(R.id.btn_switch_theme);
        mBtnMore = findViewById(R.id.btn_more);
        mFileSpinner = findViewById(R.id.spn_files);

        applyToolbarInsets();

        EditorSettings settings = mEditor.getSettings();
        settings.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        settings.setEditorTextSize(28f);
        settings.setFoldArrowMode(FoldArrowMode.AUTO);
        settings.setMaxGutterIcons(1);
        settings.setCurrentLineRenderMode(CurrentLineRenderMode.BORDER);
        settings.setRenderWhitespace(WhitespaceRenderMode.ALL);
        settings.setRenderLineBreaks(true);

        LanguageConfiguration configuration = new LanguageConfiguration.Builder("test")
                .addAutoClosingPair("\"", "\"")
                .addAutoClosingPair("(", ")")
                .setInsertSpaces(true)
                .build();
        mEditor.setLanguageConfiguration(configuration);
        registerDemoStylesForCurrentTheme();
        mSearchPanel.setEditor(mEditor);
        mSearchPanel.setOnSearchStateChangedListener(state -> updateStatus(describeSearchState(state)));

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
        tintImageButton(mBtnTheme, fg);
        tintImageButton(mBtnUndo, fg);
        tintImageButton(mBtnRedo, fg);
        tintImageButton(mBtnMore, fg);
        mSearchPanel.applyTheme(mEditor.getTheme());

        mStatusBar.setBackgroundColor(bg);
        mStatusBar.setTextColor(secondary);

        updateStatusBarAppearance();
        updateSpinnerTheme();
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

    private void updateSpinnerTheme() {
        if (mFileAdapter == null) {
            mFileAdapter = new ArrayAdapter<String>(this,
                    android.R.layout.simple_spinner_item, mDemoFiles) {
                @NonNull
                @Override
                public View getView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
                    TextView tv = (TextView) super.getView(position, convertView, parent);
                    tv.setTextColor(mIsDarkTheme ? DARK_FG : LIGHT_FG);
                    tv.setTextSize(13f);
                    return tv;
                }

                @Override
                public View getDropDownView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
                    TextView tv = (TextView) super.getDropDownView(position, convertView, parent);
                    tv.setTextColor(mIsDarkTheme ? DARK_FG : LIGHT_FG);
                    tv.setBackgroundColor(mIsDarkTheme ? DARK_BG : LIGHT_BG);
                    tv.setPadding(24, 20, 24, 20);
                    return tv;
                }
            };
            mFileAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
            mFileSpinner.setAdapter(mFileAdapter);
        } else {
            mFileAdapter.notifyDataSetChanged();
        }
    }

    private void subscribeEditorEvents() {
        mEditor.subscribe(TextChangedEvent.class, e -> {
            int count = e.changes.size();
            String summary = "empty";
            if (count > 0) {
                TextChange first = e.changes.get(0);
                String rangeStr = first.range.start.line + ":" + first.range.start.column
                        + "-" + first.range.end.line + ":" + first.range.end.column;
                String textPreview = first.newText.length() > 50
                        ? first.newText.substring(0, 50) + "..."
                        : first.newText;
                summary = "range=" + rangeStr + " text=" + textPreview.replace("\n", "\\n");
            }
            Log.d("SweetEditor", "[TextChanged] changes=" + count + " " + summary);
        });
        mEditor.subscribe(InlayHintClickEvent.class, e -> {
            if (e.type == InlayType.COLOR) {
                Toast.makeText(this, "Click color: " + String.format("0X%X", e.intValue), Toast.LENGTH_SHORT).show();
            } else if (e.type != InlayType.ICON) {
                Toast.makeText(this, "Click inlay hint: (" + e.line + "," + e.column + ")", Toast.LENGTH_SHORT).show();
            }
        });
        mEditor.subscribe(GutterIconClickEvent.class, e ->
                Toast.makeText(this, "Click icon at line: " + e.line, Toast.LENGTH_SHORT).show());
        mEditor.subscribe(CodeLensClickEvent.class, e -> {
            String commandLabel = describeCodeLensCommand(e.commandId);
            String message = "CodeLens " + commandLabel + " at line: " + (e.line + 1);
            updateStatus(message);
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
        });
        mEditor.subscribe(LinkClickEvent.class, e -> openLinkInBrowser(e.target));
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
        if (mEditor.hasSelection()) {
            return;
        }
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
            if (mEditor.isInlineSuggestionShowing() || mSuggestionShownCount >= MAX_SUGGESTION_SHOWN) {
                return;
            }
            String demoText = "\nvoid autoGenerated() {\n    std::cout << \"hello\" << std::endl;\n    return;\n}";
            mEditor.showInlineSuggestion(new InlineSuggestion(line, column, demoText));
            mSuggestionShownCount++;
        };
        mSuggestionHandler.postDelayed(mPendingSuggestion, 1000);
    }

    private void cancelPendingSuggestion() {
        if (mPendingSuggestion != null) {
            mSuggestionHandler.removeCallbacks(mPendingSuggestion);
            mPendingSuggestion = null;
        }
    }

    private void openLinkInBrowser(@Nullable String target) {
        if (target == null || target.isEmpty()) {
            updateStatus("Link target is empty");
            Toast.makeText(this, "Link target is empty", Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            Intent viewIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(target));
            viewIntent.addCategory(Intent.CATEGORY_BROWSABLE);
            Intent chooserIntent = Intent.createChooser(viewIntent, "Open link with");
            startActivity(chooserIntent);
            updateStatus("Open link " + target);
        } catch (ActivityNotFoundException ex) {
            updateStatus("No browser found for " + target);
            Toast.makeText(this, "No browser found", Toast.LENGTH_SHORT).show();
        }
    }

    @NonNull
    private String describeCodeLensCommand(int commandId) {
        if (commandId == DemoDecorationProvider.CODELENS_RUN) {
            return "▶ Run";
        }
        if (commandId == DemoDecorationProvider.CODELENS_DEBUG) {
            return "◎ Debug";
        }
        return "Command#" + commandId;
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
        mSearchPanel.resetForDocument();
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
        mBtnTheme.setOnClickListener(v -> toggleTheme());
        mBtnUndo.setOnClickListener(v -> undo());
        mBtnRedo.setOnClickListener(v -> redo());
        mBtnMore.setOnClickListener(this::showToolbarMenu);
    }

    private void showToolbarMenu(@NonNull View anchor) {
        PopupMenu popup = new PopupMenu(this, anchor);
        popup.getMenu().add(0, MENU_SEARCH, 0, "Search");
        popup.getMenu().add(0, MENU_REPLACE, 1, "Replace");
        popup.getMenu().add(0, MENU_WRAP, 2, "Wrap");
        popup.setOnMenuItemClickListener(item -> {
            switch (item.getItemId()) {
                case MENU_SEARCH:
                    openSearch(false);
                    return true;
                case MENU_REPLACE:
                    openSearch(true);
                    return true;
                case MENU_WRAP:
                    cycleWrapMode();
                    return true;
                default:
                    return false;
            }
        });
        popup.show();
    }

    private void openSearch(boolean replaceMode) {
        mSearchPanel.open(replaceMode);
        updateStatus(replaceMode ? "Replace" : "Search");
    }

    private void undo() {
        if (mEditor.canUndo()) {
            mEditor.undo();
            updateStatus("Undo");
        } else {
            updateStatus("Nothing to undo");
        }
    }

    private void redo() {
        if (mEditor.canRedo()) {
            mEditor.redo();
            updateStatus("Redo");
        } else {
            updateStatus("Nothing to redo");
        }
    }

    private void toggleTheme() {
        mIsDarkTheme = !mIsDarkTheme;
        mEditor.applyTheme(mIsDarkTheme ? EditorTheme.dark() : EditorTheme.light());
        registerDemoStylesForCurrentTheme();
        applyAppTheme();
        updateStatus(mIsDarkTheme ? "Dark theme" : "Light theme");
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

    private void registerDemoStylesForCurrentTheme() {
        int color = mIsDarkTheme ? 0xFFB5CEA8 : 0xFF098658;
        int linkColor = mIsDarkTheme ? 0xFF7DCFFF : 0xFF005FB8;
        mEditor.registerTextStyle(STYLE_COLOR, color, 0);
        mEditor.registerTextStyle(STYLE_LINK, linkColor, 0);
    }

    @NonNull
    private String describeSearchState(@NonNull SearchState state) {
        String pattern = state.pattern == null ? "" : state.pattern;
        if (pattern.isEmpty() || state.status == SearchStatus.INACTIVE) {
            return "Search";
        }
        if (state.status == SearchStatus.FAILED) {
            String message = state.errorMessage == null || state.errorMessage.isEmpty()
                    ? "invalid pattern"
                    : state.errorMessage;
            return "Search failed: " + message;
        }
        if (state.matchCount <= 0) {
            return "No matches: " + pattern;
        }
        int current = state.currentIndex >= 0 ? state.currentIndex + 1 : 0;
        return "Search " + current + "/" + state.matchCount + ": " + pattern;
    }
}
