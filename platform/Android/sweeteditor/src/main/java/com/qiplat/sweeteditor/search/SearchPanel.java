package com.qiplat.sweeteditor.search;

import android.content.Context;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.drawable.GradientDrawable;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.R;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.search.SearchOptions;
import com.qiplat.sweeteditor.core.search.SearchRequest;
import com.qiplat.sweeteditor.core.search.SearchState;
import com.qiplat.sweeteditor.core.search.SearchStatus;
import com.qiplat.sweeteditor.event.EditorEventListener;
import com.qiplat.sweeteditor.event.TextChangedEvent;

public class SearchPanel extends LinearLayout {
    private static final String NEWLINE_TOKEN = "\\n";

    public interface OnSearchStateChangedListener {
        void onSearchStateChanged(@NonNull SearchState state);
    }

    private final ImageView mSearchIcon;
    private final EditText mQueryInput;
    private final EditText mReplaceInput;
    private final TextView mCounterView;
    private final TextView mCaseToggle;
    private final TextView mWholeWordToggle;
    private final TextView mRegexToggle;
    private final TextView mReplaceButton;
    private final TextView mReplaceAllButton;
    private final ImageButton mPreviousButton;
    private final ImageButton mNextButton;
    private final ImageButton mCloseButton;
    private final ImageButton mQueryNewlineButton;
    private final ImageButton mReplaceNewlineButton;
    private final EditorEventListener<TextChangedEvent> mTextChangedListener;

    @Nullable
    private SweetEditor mEditor;
    @Nullable
    private OnSearchStateChangedListener mStateChangedListener;
    private boolean mCaseSensitive;
    private boolean mWholeWord;
    private boolean mUseRegex;
    private boolean mSubscribed;
    private boolean mInternalTextChange;
    private boolean mHasActiveSearch;
    private boolean mReplacing;
    private int mForegroundColor = Color.WHITE;
    private int mMutedColor = 0x99FFFFFF;
    private int mAccentColor = 0xFF7AA2F7;
    private int mErrorColor = 0xFFF7768E;

    public SearchPanel(@NonNull Context context) {
        this(context, null);
    }

    public SearchPanel(@NonNull Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public SearchPanel(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setOrientation(VERTICAL);
        setPadding(dp(8), dp(2), dp(4), dp(4));

        LinearLayout searchRow = createRow(context);
        addView(searchRow, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));

        mSearchIcon = new ImageView(context);
        mSearchIcon.setImageResource(R.drawable.se_ic_search_24);
        searchRow.addView(mSearchIcon, new LayoutParams(dp(24), dp(36)));

        mQueryInput = new EditText(context);
        mQueryInput.setSingleLine(true);
        mQueryInput.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        mQueryInput.setHint("Search");
        mQueryInput.setPadding(dp(2), 0, dp(8), 0);
        mQueryInput.setBackgroundColor(Color.TRANSPARENT);
        mQueryInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        mQueryInput.setImeOptions(EditorInfo.IME_ACTION_SEARCH | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        mQueryInput.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                findNextSearchMatch();
                return true;
            }
            return false;
        });
        mQueryInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                if (!mInternalTextChange) {
                    performSearch();
                }
            }
        });
        searchRow.addView(mQueryInput, new LayoutParams(0, dp(36), 1f));

        mQueryNewlineButton = createImageButton(R.drawable.se_ic_keyboard_return_24, "Insert Newline");
        mQueryNewlineButton.setOnClickListener(v -> insertNewlineToken(mQueryInput));
        searchRow.addView(mQueryNewlineButton, new LayoutParams(dp(32), dp(36)));

        mTextChangedListener = event -> {
            if (!mReplacing && getVisibility() == VISIBLE && mQueryInput.length() > 0) {
                performSearch();
            }
        };

        mCounterView = new TextView(context);
        mCounterView.setGravity(Gravity.CENTER);
        mCounterView.setSingleLine(true);
        mCounterView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        mCounterView.setText("0/0");
        searchRow.addView(mCounterView, new LayoutParams(dp(58), dp(36)));

        mCaseToggle = createToggleButton("Aa", "Match Case");
        mCaseToggle.setOnClickListener(v -> {
            mCaseSensitive = !mCaseSensitive;
            updateOptionToggles();
            performSearch();
        });
        searchRow.addView(mCaseToggle, new LayoutParams(dp(30), dp(36)));

        mWholeWordToggle = createToggleButton("W", "Whole Word");
        mWholeWordToggle.setOnClickListener(v -> {
            mWholeWord = !mWholeWord;
            updateOptionToggles();
            performSearch();
        });
        searchRow.addView(mWholeWordToggle, new LayoutParams(dp(30), dp(36)));

        mRegexToggle = createToggleButton(".*", "Use Regex");
        mRegexToggle.setOnClickListener(v -> {
            mUseRegex = !mUseRegex;
            updateOptionToggles();
            performSearch();
        });
        searchRow.addView(mRegexToggle, new LayoutParams(dp(30), dp(36)));

        mPreviousButton = createImageButton(R.drawable.se_ic_expand_less_24, "Previous Match");
        mPreviousButton.setOnClickListener(v -> findPreviousSearchMatch());
        searchRow.addView(mPreviousButton, new LayoutParams(dp(32), dp(36)));

        mNextButton = createImageButton(R.drawable.se_ic_expand_more_24, "Next Match");
        mNextButton.setOnClickListener(v -> findNextSearchMatch());
        searchRow.addView(mNextButton, new LayoutParams(dp(32), dp(36)));

        mCloseButton = createImageButton(R.drawable.se_ic_close_24, "Close Search");
        mCloseButton.setOnClickListener(v -> close());
        searchRow.addView(mCloseButton, new LayoutParams(dp(32), dp(36)));

        LinearLayout replaceRow = createRow(context);
        replaceRow.setPadding(dp(24), dp(2), 0, 0);
        addView(replaceRow, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));

        mReplaceInput = new EditText(context);
        mReplaceInput.setSingleLine(true);
        mReplaceInput.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        mReplaceInput.setHint("Replace");
        mReplaceInput.setPadding(dp(2), 0, dp(8), 0);
        mReplaceInput.setBackgroundColor(Color.TRANSPARENT);
        mReplaceInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        mReplaceInput.setImeOptions(EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        mReplaceInput.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                replaceCurrentSearchMatch();
                return true;
            }
            return false;
        });
        replaceRow.addView(mReplaceInput, new LayoutParams(0, dp(36), 1f));

        mReplaceNewlineButton = createImageButton(R.drawable.se_ic_keyboard_return_24, "Insert Newline");
        mReplaceNewlineButton.setOnClickListener(v -> insertNewlineToken(mReplaceInput));
        replaceRow.addView(mReplaceNewlineButton, new LayoutParams(dp(32), dp(36)));

        mReplaceButton = createCommandButton("Replace", "Replace Current Match");
        mReplaceButton.setOnClickListener(v -> replaceCurrentSearchMatch());
        replaceRow.addView(mReplaceButton, new LayoutParams(dp(68), dp(36)));

        mReplaceAllButton = createCommandButton("All", "Replace All Matches");
        mReplaceAllButton.setOnClickListener(v -> replaceAllSearchMatches());
        replaceRow.addView(mReplaceAllButton, new LayoutParams(dp(42), dp(36)));

        setVisibility(GONE);
        applyTheme(EditorTheme.dark());
        updateControls(new SearchState());
    }

    public void setEditor(@Nullable SweetEditor editor) {
        if (mEditor == editor) {
            return;
        }
        detachEditorListener();
        mEditor = editor;
        if (isAttachedToWindow()) {
            attachEditorListener();
        }
        if (editor != null) {
            applyTheme(editor.getTheme());
        }
        updateControls(new SearchState());
    }

    public void setOnSearchStateChangedListener(@Nullable OnSearchStateChangedListener listener) {
        mStateChangedListener = listener;
    }

    public void open() {
        setVisibility(VISIBLE);
        updateControls(currentSearchState());
        mQueryInput.requestFocus();
        post(this::showKeyboard);
        if (mQueryInput.length() > 0) {
            performSearch();
        }
    }

    public void close() {
        clearSearch();
        hideKeyboard();
        setVisibility(GONE);
        if (mEditor != null) {
            mEditor.requestFocus();
        }
    }

    public void clearSearch() {
        mInternalTextChange = true;
        mQueryInput.setText("");
        mInternalTextChange = false;
        if (mEditor != null && mHasActiveSearch) {
            mEditor.clearSearch();
        }
        mHasActiveSearch = false;
        applySearchState(new SearchState());
    }

    public void resetForDocument() {
        clearSearch();
        mReplaceInput.setText("");
    }

    public void refreshSearch() {
        if (mQueryInput.length() > 0) {
            performSearch();
        } else {
            refreshSearchState();
        }
    }

    @NonNull
    public SearchState refreshSearchState() {
        SearchState state = currentSearchState();
        applySearchState(state);
        return state;
    }

    public void applyTheme(@NonNull EditorTheme theme) {
        mForegroundColor = theme.textColor;
        mMutedColor = theme.lineNumberColor != 0 ? theme.lineNumberColor : mForegroundColor;
        mAccentColor = theme.currentLineNumberColor != 0 ? theme.currentLineNumberColor : theme.cursorColor;
        mErrorColor = theme.diagnosticErrorColor != 0 ? theme.diagnosticErrorColor : mAccentColor;

        GradientDrawable background = new GradientDrawable();
        background.setColor(theme.backgroundColor);
        setBackground(background);

        mQueryInput.setTextColor(mForegroundColor);
        mQueryInput.setHintTextColor(mMutedColor);
        mReplaceInput.setTextColor(mForegroundColor);
        mReplaceInput.setHintTextColor(mMutedColor);
        mCounterView.setTextColor(mMutedColor);
        mReplaceButton.setTextColor(mForegroundColor);
        mReplaceAllButton.setTextColor(mForegroundColor);
        tintImageView(mSearchIcon, mMutedColor);
        tintImageButton(mPreviousButton, mForegroundColor);
        tintImageButton(mNextButton, mForegroundColor);
        tintImageButton(mCloseButton, mForegroundColor);
        tintImageButton(mQueryNewlineButton, mMutedColor);
        tintImageButton(mReplaceNewlineButton, mMutedColor);
        updateOptionToggles();
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        attachEditorListener();
    }

    @Override
    protected void onDetachedFromWindow() {
        detachEditorListener();
        super.onDetachedFromWindow();
    }

    private void performSearch() {
        if (mEditor == null) {
            applySearchState(new SearchState());
            return;
        }
        String pattern = decodeNewlineTokens(mQueryInput.getText().toString());
        if (pattern.isEmpty()) {
            if (mHasActiveSearch) {
                mEditor.clearSearch();
                mHasActiveSearch = false;
            }
            applySearchState(new SearchState());
            return;
        }
        SearchOptions options = new SearchOptions();
        options.caseSensitive = mCaseSensitive;
        options.wholeWord = mWholeWord;
        options.useRegex = mUseRegex;
        SearchRequest request = new SearchRequest(pattern, options);
        mEditor.search(request);
        mHasActiveSearch = true;
        refreshSearchState();
    }

    private void findNextSearchMatch() {
        if (!canNavigate()) {
            return;
        }
        mEditor.findNextSearchMatch();
        refreshSearchState();
    }

    private void findPreviousSearchMatch() {
        if (!canNavigate()) {
            return;
        }
        mEditor.findPreviousSearchMatch();
        refreshSearchState();
    }

    private void replaceCurrentSearchMatch() {
        if (mEditor == null) {
            return;
        }
        SearchState state = currentSearchState();
        if (mQueryInput.length() == 0
                || state.status == SearchStatus.FAILED
                || !state.hasCurrentMatch) {
            return;
        }
        mReplacing = true;
        try {
            mEditor.replaceCurrentSearchMatch(decodeNewlineTokens(mReplaceInput.getText().toString()));
        } finally {
            mReplacing = false;
        }
        performSearch();
    }

    private void replaceAllSearchMatches() {
        if (mEditor == null) {
            return;
        }
        SearchState state = currentSearchState();
        if (mQueryInput.length() == 0
                || state.status == SearchStatus.FAILED
                || state.matchCount <= 0) {
            return;
        }
        mReplacing = true;
        try {
            mEditor.replaceAllSearchMatches(decodeNewlineTokens(mReplaceInput.getText().toString()));
        } finally {
            mReplacing = false;
        }
        performSearch();
    }

    private boolean canNavigate() {
        return mEditor != null && mQueryInput.length() > 0 && currentSearchState().matchCount > 0;
    }

    @NonNull
    private SearchState currentSearchState() {
        if (mEditor == null || mQueryInput.length() == 0) {
            return new SearchState();
        }
        return mEditor.getSearchState();
    }

    private void applySearchState(@NonNull SearchState state) {
        if (mQueryInput.length() == 0 || state.status == SearchStatus.INACTIVE) {
            mCounterView.setText("0/0");
            mCounterView.setTextColor(mMutedColor);
        } else if (state.status == SearchStatus.FAILED) {
            mCounterView.setText("Error");
            mCounterView.setTextColor(mErrorColor);
        } else if (state.status == SearchStatus.SEARCHING) {
            mCounterView.setText("...");
            mCounterView.setTextColor(mMutedColor);
        } else if (state.matchCount <= 0) {
            mCounterView.setText("0/0");
            mCounterView.setTextColor(mMutedColor);
        } else {
            int current = state.currentIndex >= 0 ? state.currentIndex + 1 : 0;
            mCounterView.setText(current + "/" + state.matchCount);
            mCounterView.setTextColor(mForegroundColor);
        }
        updateControls(state);
        if (mStateChangedListener != null) {
            mStateChangedListener.onSearchStateChanged(state);
        }
    }

    private void updateControls(@NonNull SearchState state) {
        boolean hasEditor = mEditor != null;
        boolean hasQuery = mQueryInput.length() > 0;
        boolean canNavigate = hasEditor && hasQuery && state.matchCount > 0 && state.status != SearchStatus.FAILED;

        mQueryInput.setEnabled(hasEditor);
        setToggleEnabled(mCaseToggle, hasEditor);
        setToggleEnabled(mWholeWordToggle, hasEditor);
        setToggleEnabled(mRegexToggle, hasEditor);
        mReplaceInput.setEnabled(hasEditor);
        setImageButtonEnabled(mQueryNewlineButton, hasEditor);
        setImageButtonEnabled(mReplaceNewlineButton, hasEditor);
        setImageButtonEnabled(mPreviousButton, canNavigate);
        setImageButtonEnabled(mNextButton, canNavigate);
        setImageButtonEnabled(mCloseButton, true);
        setTextButtonEnabled(mReplaceButton, canNavigate && state.hasCurrentMatch);
        setTextButtonEnabled(mReplaceAllButton, canNavigate);
    }

    private void updateOptionToggles() {
        updateToggle(mCaseToggle, mCaseSensitive);
        updateToggle(mWholeWordToggle, mWholeWord);
        updateToggle(mRegexToggle, mUseRegex);
    }

    private void updateToggle(@NonNull TextView toggle, boolean checked) {
        toggle.setSelected(checked);
        toggle.setTextColor(checked ? mAccentColor : mMutedColor);
    }

    private void setToggleEnabled(@NonNull TextView toggle, boolean enabled) {
        toggle.setEnabled(enabled);
        toggle.setAlpha(enabled ? 1f : 0.35f);
    }

    private void setImageButtonEnabled(@NonNull ImageButton button, boolean enabled) {
        button.setEnabled(enabled);
        button.setAlpha(enabled ? 1f : 0.35f);
    }

    private void setTextButtonEnabled(@NonNull TextView button, boolean enabled) {
        button.setEnabled(enabled);
        button.setAlpha(enabled ? 1f : 0.35f);
    }

    @NonNull
    private LinearLayout createRow(@NonNull Context context) {
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        return row;
    }

    @NonNull
    private TextView createToggleButton(@NonNull String text, @NonNull String contentDescription) {
        TextView view = new TextView(getContext());
        view.setText(text);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        view.setGravity(Gravity.CENTER);
        view.setSingleLine(true);
        view.setClickable(true);
        view.setFocusable(true);
        view.setContentDescription(contentDescription);
        view.setBackgroundResource(resolveSelectableBorderless());
        return view;
    }

    @NonNull
    private TextView createCommandButton(@NonNull String text, @NonNull String contentDescription) {
        TextView view = createToggleButton(text, contentDescription);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        return view;
    }

    @NonNull
    private ImageButton createImageButton(int drawableRes, @NonNull String contentDescription) {
        ImageButton button = new ImageButton(getContext());
        button.setImageResource(drawableRes);
        button.setBackgroundResource(resolveSelectableBorderless());
        button.setContentDescription(contentDescription);
        button.setScaleType(ImageView.ScaleType.CENTER_INSIDE);
        button.setPadding(dp(8), dp(8), dp(8), dp(8));
        return button;
    }

    private int resolveSelectableBorderless() {
        TypedValue outValue = new TypedValue();
        getContext().getTheme().resolveAttribute(
                android.R.attr.selectableItemBackgroundBorderless,
                outValue,
                true);
        return outValue.resourceId;
    }

    private void attachEditorListener() {
        if (mEditor == null || mSubscribed) {
            return;
        }
        mEditor.subscribe(TextChangedEvent.class, mTextChangedListener);
        mSubscribed = true;
    }

    private void detachEditorListener() {
        if (mEditor == null || !mSubscribed) {
            return;
        }
        mEditor.unsubscribe(TextChangedEvent.class, mTextChangedListener);
        mSubscribed = false;
    }

    private void insertNewlineToken(@NonNull EditText input) {
        int start = Math.max(input.getSelectionStart(), 0);
        int end = Math.max(input.getSelectionEnd(), 0);
        if (start > end) {
            int temp = start;
            start = end;
            end = temp;
        }
        input.getText().replace(start, end, NEWLINE_TOKEN);
        input.setSelection(start + NEWLINE_TOKEN.length());
    }

    @NonNull
    private String decodeNewlineTokens(@NonNull String text) {
        StringBuilder builder = new StringBuilder(text.length());
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if (ch == '\\' && i + 1 < text.length()) {
                char next = text.charAt(i + 1);
                if (next == 'n') {
                    builder.append('\n');
                    i++;
                    continue;
                }
                if (next == '\\') {
                    builder.append('\\');
                    i++;
                    continue;
                }
            }
            builder.append(ch);
        }
        return builder.toString();
    }

    private void showKeyboard() {
        InputMethodManager imm = (InputMethodManager) getContext()
                .getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm != null) {
            imm.showSoftInput(mQueryInput, InputMethodManager.SHOW_IMPLICIT);
        }
    }

    private void hideKeyboard() {
        InputMethodManager imm = (InputMethodManager) getContext()
                .getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm != null) {
            imm.hideSoftInputFromWindow(mQueryInput.getWindowToken(), 0);
        }
    }

    private void tintImageView(@NonNull ImageView view, int color) {
        view.setColorFilter(color, PorterDuff.Mode.SRC_IN);
    }

    private void tintImageButton(@NonNull ImageButton button, int color) {
        button.setColorFilter(color, PorterDuff.Mode.SRC_IN);
    }

    private int dp(int value) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                value,
                getResources().getDisplayMetrics());
    }
}
