package com.qiplat.sweeteditor.core.ime;

public class ImeInputContext {
    public long id;
    public int revision;
    public int documentStartOffset;
    public String text = "";
    public ImeTextRange selection = new ImeTextRange();
    public boolean hasComposition;
    public ImeTextRange composition = new ImeTextRange(-1, -1);
}
