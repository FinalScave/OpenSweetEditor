package com.qiplat.sweeteditor.decoration;

public interface DecorationReceiver {
    boolean accept(DecorationResult result);

    boolean isCancelled();
}
