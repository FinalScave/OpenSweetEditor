package com.qiplat.sweeteditor;

/**
 * Editor metadata marker interface.
 * External implementations can use this interface to define custom metadata and attach it to the editor instance.
 * When used, cast to the specific subtype.
 *
 * <pre>
 * public class FileMetadata implements EditorMetadata {
 *     public final String filePath;
 *     public FileMetadata(String filePath) { this.filePath = filePath; }
 * }
 * editor.setMetadata(new FileMetadata("/a/b.cpp"));
 * FileMetadata file = (FileMetadata) editor.getMetadata();
 * </pre>
 */
public interface EditorMetadata {
}
