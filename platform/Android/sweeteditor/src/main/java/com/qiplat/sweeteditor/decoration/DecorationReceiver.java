package com.qiplat.sweeteditor.decoration;

import androidx.annotation.NonNull;

public interface DecorationReceiver {
    boolean accept(@NonNull DecorationResult result);

    boolean isCancelled();
}
