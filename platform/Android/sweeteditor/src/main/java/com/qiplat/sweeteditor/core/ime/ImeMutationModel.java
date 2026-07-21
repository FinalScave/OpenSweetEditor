package com.qiplat.sweeteditor.core.ime;

public enum ImeMutationModel {
    COMMAND(0),
    TEXT_UPDATE(1);

    public final int value;

    ImeMutationModel(int value) {
        this.value = value;
    }

    public static ImeMutationModel fromValue(int value) {
        switch (value) {
            case 0: return COMMAND;
            case 1: return TEXT_UPDATE;
            default: throw new IllegalArgumentException("Unknown ImeMutationModel value: " + value);
        }
    }
}
