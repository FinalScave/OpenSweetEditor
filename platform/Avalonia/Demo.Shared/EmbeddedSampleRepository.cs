using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;

namespace SweetEditor.Avalonia.Demo;

public static class EmbeddedSampleRepository
{
    private const string ResourcePrefix = "SweetEditor.PlatformRes.files.";
    private const int GeneratedChunkTargetChars = 64 * 1024;
    private static readonly string[] EmbeddedSampleNames =
	{
		"example.java",
		"example.kt",
		"example.lua",
		"gc.cpp",
	};

    public static List<DemoSampleFile> LoadAll(Assembly assembly)
    {
        List<DemoSampleFile> embedded = LoadEmbeddedSamples(assembly);
        embedded.AddRange(BuildGeneratedSamples());
        return embedded;
    }

    private static List<DemoSampleFile> LoadEmbeddedSamples(Assembly assembly)
    {
        var result = new List<DemoSampleFile>(EmbeddedSampleNames.Length);
        foreach (string relativeName in EmbeddedSampleNames)
        {
            string resourceName = ResourcePrefix + relativeName;
            if (assembly.GetManifestResourceInfo(resourceName) == null)
                continue;

            result.Add(new DemoSampleFile(
                relativeName,
                ParseLanguageId(relativeName),
                () => ReadEmbeddedResourceText(assembly, resourceName)));
        }

        return result;
    }

    private static IEnumerable<DemoSampleFile> BuildGeneratedSamples()
    {
        yield return new DemoSampleFile(
            "generated/large-demo.cpp",
            "cpp",
            BuildLargeCppDocumentChunks,
            isGenerated: true,
            isLargeDocument: true);

        yield return new DemoSampleFile(
            "generated/huge-script.lua",
            "lua",
            BuildLargeLuaDocumentChunks,
            isGenerated: true,
            isLargeDocument: true);
    }

    private static IEnumerable<string> BuildLargeCppDocumentChunks()
    {
        var sb = new StringBuilder(GeneratedChunkTargetChars + 4096);
        sb.AppendLine("#include <string>");
        sb.AppendLine("#include <vector>");
        sb.AppendLine("#include <cstdint>");
        sb.AppendLine();
        sb.AppendLine("class GeneratedLargeDemo {");
        sb.AppendLine("public:");
        sb.AppendLine("    int checksum = 0;");
        for (int i = 0; i < 10000; i++)
        {
            sb.AppendLine($"    int section_{i}(int seed) {{");
            sb.AppendLine($"        int local = seed + {i}; // TODO: review section_{i}");
            sb.AppendLine($"        if ((local % 7) == 0) {{ checksum += local; }}");
            sb.AppendLine($"        std::string color = \"#{(i * 97) & 0xFFFFFF:X6}\";");
            sb.AppendLine($"        return local + checksum; }}");
            sb.AppendLine();

            if (sb.Length >= GeneratedChunkTargetChars)
                yield return DrainBuilder(sb);
        }
        sb.AppendLine("};");
        if (sb.Length > 0)
            yield return DrainBuilder(sb);
    }

    private static IEnumerable<string> BuildLargeLuaDocumentChunks()
    {
        var sb = new StringBuilder(GeneratedChunkTargetChars + 4096);
        sb.AppendLine("local Demo = {}");
        sb.AppendLine();
        for (int i = 0; i < 12000; i++)
        {
            sb.AppendLine($"function Demo.block_{i}(value)");
            sb.AppendLine($"    local current = value + {i}");
            sb.AppendLine("    if current % 5 == 0 then");
            sb.AppendLine("        return current, \"#22AAFF\"");
            sb.AppendLine("    end");
            sb.AppendLine("    return current");
            sb.AppendLine("end");
            sb.AppendLine();

            if (sb.Length >= GeneratedChunkTargetChars)
                yield return DrainBuilder(sb);
        }
        sb.AppendLine("return Demo");
        if (sb.Length > 0)
            yield return DrainBuilder(sb);
    }

    private static string DrainBuilder(StringBuilder builder)
    {
        string chunk = builder.ToString();
        builder.Clear();
        return chunk;
    }

    private static string ParseLanguageId(string fileName)
    {
        string extension = Path.GetExtension(fileName).ToLowerInvariant();
        return extension switch
        {
            ".kt" => "kotlin",
            ".java" => "java",
            ".lua" => "lua",
            ".cpp" or ".cc" or ".cxx" or ".hpp" or ".h" or ".c" => "cpp",
            _ => "plaintext",
        };
    }

    private static string ReadEmbeddedResourceText(Assembly assembly, string resourceName)
    {
        using Stream? stream = assembly.GetManifestResourceStream(resourceName);
        if (stream == null)
            return string.Empty;

        using var reader = new StreamReader(stream, Encoding.UTF8, true, 4096, leaveOpen: false);
        return reader.ReadToEnd();
    }
}
