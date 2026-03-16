package com.qiplat.sweeteditor.core;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * Extracts the current platform's native library from JAR resources to a specified directory.
 * <p>
 * After extraction, the target directory is automatically set to the {@code sweeteditor.lib.path} system property.
 * {@link EditorNative} static initialization will preferentially read this property to load the native library.
 * <p>
 * Internally determines whether extraction has already occurred (file exists with matching size), avoiding redundant extraction.
 *
 * <h3>Usage</h3>
 * <pre>{@code
 * // Option 1: Extract to a specified directory
 * NativeLibraryExtractor.extract(Path.of("/opt/myapp/native"));
 *
 * // Option 2: Extract to the system default directory (Windows: %LOCALAPPDATA%\SweetEditor\native\, macOS: ~/Library/Application Support/SweetEditor/native/, Linux: ~/.local/share/sweeteditor/native/)
 * NativeLibraryExtractor.extractToDefaultDir();
 *
 * // Then use the editor as normal, the library path is already set
 * EditorCore core = new EditorCore(...);
 * }</pre>
 */
public final class NativeLibraryExtractor {

    /** Root path of native library resources within the JAR */
    private static final String NATIVE_RESOURCE_ROOT = "/native/";

    private NativeLibraryExtractor() {}

    /**
     * Extract the current platform's native library from JAR resources to the specified directory,
     * and automatically set {@code sweeteditor.lib.path}.
     * <p>
     * If a native library file of the same size already exists in the target directory, extraction is skipped
     * and only the system property is set.
     *
     * @param targetDir extraction target directory (created automatically if it does not exist)
     * @return the path to the extracted native library file
     * @throws IOException if extraction fails or the current platform's native library cannot be found in the JAR
     */
    public static Path extract(Path targetDir) throws IOException {
        String libName = System.mapLibraryName("sweeteditor");
        String platform = detectPlatform();
        String resourcePath = NATIVE_RESOURCE_ROOT + platform + "/" + libName;

        Files.createDirectories(targetDir);
        Path targetFile = targetDir.resolve(libName);

        // Check whether extraction has already occurred (file exists with matching size)
        if (!needsExtraction(targetFile, resourcePath)) {
            // Already exists with matching size, skip extraction, just register path
            registerLibraryPath(targetDir);
            return targetFile;
        }

        // Perform extraction
        try (InputStream is = NativeLibraryExtractor.class.getResourceAsStream(resourcePath)) {
            if (is == null) {
                throw new FileNotFoundException(
                        "Native library for the current platform not found in JAR: " + resourcePath +
                        " (platform=" + platform + ", libName=" + libName + ")");
            }
            Files.copy(is, targetFile, StandardCopyOption.REPLACE_EXISTING);
        }

        // Register path
        registerLibraryPath(targetDir);
        return targetFile;
    }

    /**
     * Extract the current platform's native library to the default directory,
     * and automatically set {@code sweeteditor.lib.path}.
     * <p>
     * The default directory varies by operating system:
     * <ul>
     *   <li><b>Windows</b>: {@code %LOCALAPPDATA%\SweetEditor\native\} (e.g. {@code C:\Users\xxx\AppData\Local\SweetEditor\native\})</li>
     *   <li><b>macOS</b>: {@code ~/Library/Application Support/SweetEditor/native/}</li>
     *   <li><b>Linux</b>: {@code $XDG_DATA_HOME/sweeteditor/native/} (default {@code ~/.local/share/sweeteditor/native/})</li>
     * </ul>
     *
     * @return the path to the extracted native library file
     * @throws IOException if extraction fails
     */
    public static Path extractToDefaultDir() throws IOException {
        Path defaultDir = getDefaultNativeDir();
        return extract(defaultDir);
    }

    /**
     * Get the default native library storage directory for the current platform.
     */
    private static Path getDefaultNativeDir() {
        String os = System.getProperty("os.name", "").toLowerCase();
        String userHome = System.getProperty("user.home");

        if (os.contains("win")) {
            // Windows: Prefer using the LOCALAPPDATA environment variable
            String localAppData = System.getenv("LOCALAPPDATA");
            if (localAppData != null && !localAppData.isEmpty()) {
                return Path.of(localAppData, "SweetEditor", "native");
            }
            return Path.of(userHome, "AppData", "Local", "SweetEditor", "native");
        } else if (os.contains("mac") || os.contains("darwin")) {
            // macOS: ~/Library/Application Support/SweetEditor/native/
            return Path.of(userHome, "Library", "Application Support", "SweetEditor", "native");
        } else {
            // Linux: Follow the XDG Base Directory specification
            String xdgDataHome = System.getenv("XDG_DATA_HOME");
            if (xdgDataHome != null && !xdgDataHome.isEmpty()) {
                return Path.of(xdgDataHome, "sweeteditor", "native");
            }
            return Path.of(userHome, ".local", "share", "sweeteditor", "native");
        }
    }

    /**
     * Check whether the current platform's native library already exists in the specified directory.
     *
     * @param targetDir target directory
     * @return {@code true} if the native library already exists
     */
    public static boolean isExtracted(Path targetDir) {
        String libName = System.mapLibraryName("sweeteditor");
        return Files.exists(targetDir.resolve(libName));
    }

    // ===================== Internal Methods =====================

    /**
     * Determine whether re-extraction is needed.
     * If the target file does not exist, or its size does not match the JAR resource, extraction is needed.
     */
    private static boolean needsExtraction(Path targetFile, String resourcePath) throws IOException {
        if (!Files.exists(targetFile)) {
            return true;
        }

        // Get the size of the JAR resource
        long resourceSize = getResourceSize(resourcePath);
        if (resourceSize < 0) {
            // Unable to get resource size (resource does not exist), will report error during extraction
            return true;
        }

        // Compare sizes
        long existingSize = Files.size(targetFile);
        return existingSize != resourceSize;
    }

    /**
     * Get the size (in bytes) of a JAR resource.
     * @return resource size, or -1 if the resource does not exist
     */
    private static long getResourceSize(String resourcePath) throws IOException {
        try (InputStream is = NativeLibraryExtractor.class.getResourceAsStream(resourcePath)) {
            if (is == null) return -1;
            // Read all bytes to get size (resource streams do not support getting size directly)
            return is.readAllBytes().length;
        }
    }

    /**
     * Set the target directory to the system property {@code sweeteditor.lib.path},
     * so that {@link EditorNative} static initialization will preferentially use this path to load the native library.
     */
    private static void registerLibraryPath(Path targetDir) {
        System.setProperty("sweeteditor.lib.path", targetDir.toAbsolutePath().toString());
    }

    /**
     * Automatically detect the current platform, returning the resource subdirectory name.
     * Format is {@code <os>-<arch>}, e.g. {@code macos-aarch64}, {@code windows-x86_64}.
     */
    private static String detectPlatform() {
        String os = System.getProperty("os.name", "").toLowerCase();
        String arch = System.getProperty("os.arch", "").toLowerCase();

        String osName;
        if (os.contains("win")) {
            osName = "windows";
        } else if (os.contains("mac") || os.contains("darwin")) {
            osName = "macos";
        } else {
            osName = "linux";
        }

        String archName;
        if (arch.contains("aarch64") || arch.contains("arm64")) {
            archName = "aarch64";
        } else if (arch.contains("amd64") || arch.contains("x86_64") || arch.contains("x64")) {
            archName = "x86_64";
        } else {
            archName = arch; // Fallback, use original value
        }

        return osName + "-" + archName;
    }
}
