package com.qiplat.sweeteditor.demo;

import android.app.Activity;
import android.app.Application;
import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import androidx.test.platform.app.InstrumentationRegistry;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;

import org.junit.rules.ExternalResource;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Reusable test rule that launches EditorTestActivity and provides helper methods
 * for running operations on the editor from the UI thread.
 */
public class EditorTestRule extends ExternalResource {

    private EditorTestActivity mActivity;
    private final AtomicReference<SweetEditor> mEditorRef = new AtomicReference<>();

    @Override
    protected void before() {
        Instrumentation instrumentation = InstrumentationRegistry.getInstrumentation();
        Context targetContext = instrumentation.getTargetContext();
        Application application = (Application) targetContext.getApplicationContext();
        AtomicReference<EditorTestActivity> activityRef = new AtomicReference<>();
        CountDownLatch activityCreated = new CountDownLatch(1);
        Application.ActivityLifecycleCallbacks callbacks = new Application.ActivityLifecycleCallbacks() {
            @Override
            public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
                if (activity instanceof EditorTestActivity) {
                    activityRef.set((EditorTestActivity) activity);
                    activityCreated.countDown();
                }
            }

            @Override
            public void onActivityStarted(Activity activity) {
            }

            @Override
            public void onActivityResumed(Activity activity) {
            }

            @Override
            public void onActivityPaused(Activity activity) {
            }

            @Override
            public void onActivityStopped(Activity activity) {
            }

            @Override
            public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
            }

            @Override
            public void onActivityDestroyed(Activity activity) {
            }
        };
        application.registerActivityLifecycleCallbacks(callbacks);
        try {
            Intent intent = new Intent();
            intent.setClass(targetContext, EditorTestActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            targetContext.startActivity(intent);
            if (!activityCreated.await(10, TimeUnit.SECONDS)) {
                throw new AssertionError("Timed out launching EditorTestActivity");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new AssertionError("Interrupted while launching EditorTestActivity", e);
        } finally {
            application.unregisterActivityLifecycleCallbacks(callbacks);
        }
        mActivity = activityRef.get();
        mEditorRef.set(mActivity.getEditor());
        waitForIdle();
    }

    @Override
    protected void after() {
        EditorTestActivity activity = mActivity;
        if (activity != null) {
            InstrumentationRegistry.getInstrumentation().runOnMainSync(activity::finish);
        }
        mActivity = null;
        mEditorRef.set(null);
    }

    public SweetEditor getEditor() {
        return mEditorRef.get();
    }

    public EditorTestActivity getActivity() {
        return mActivity;
    }

    /**
     * Run an action on the UI thread and wait for completion.
     */
    public void runOnEditor(EditorAction action) {
        EditorTestActivity activity = requireActivity();
        InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> action.run(activity.getEditor()));
        waitForIdle();
    }

    /**
     * Run an action on the UI thread and return a result.
     */
    public <T> T runOnEditorSync(EditorFunction<T> func) {
        AtomicReference<T> result = new AtomicReference<>();
        EditorTestActivity activity = requireActivity();
        InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> result.set(func.apply(activity.getEditor())));
        waitForIdle();
        return result.get();
    }

    /**
     * Load a document with the given text content.
     */
    public void loadText(String text) {
        runOnEditor(editor -> editor.loadDocument(new Document(text)));
    }

    private EditorTestActivity requireActivity() {
        EditorTestActivity activity = mActivity;
        if (activity == null) {
            throw new AssertionError("EditorTestActivity is not running");
        }
        return activity;
    }

    public void waitForIdle() {
        Instrumentation instrumentation = InstrumentationRegistry.getInstrumentation();
        SweetEditor editor = mEditorRef.get();
        if (editor == null) {
            instrumentation.runOnMainSync(() -> {
            });
            return;
        }

        CountDownLatch latch = new CountDownLatch(1);
        editor.post(latch::countDown);
        try {
            if (!latch.await(5, TimeUnit.SECONDS)) {
                throw new AssertionError("Timed out waiting for editor UI queue");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new AssertionError("Interrupted while waiting for editor UI queue", e);
        }
    }

    @FunctionalInterface
    public interface EditorAction {
        void run(SweetEditor editor);
    }

    @FunctionalInterface
    public interface EditorFunction<T> {
        T apply(SweetEditor editor);
    }
}
