#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/decoration.h>

using namespace NS_SWEETEDITOR;

namespace {
  const Diagnostic* findDiag(const Vector<Diagnostic>& diags, DiagnosticSeverity severity) {
    for (const auto& diag : diags) {
      if (diag.severity == severity) return &diag;
    }
    return nullptr;
  }
}

TEST_CASE("Decorations adjustForEdit shifts same-line point and span decorations") {
  Decorations decorations;

  decorations.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 1, 0, "lhs"}, InlayHint{InlayType::TEXT, 3, 0, "rhs"}});
  decorations.setLinePhantomTexts(0, {PhantomText{4, "ghost"}});
  decorations.setLineLinks(0, {{1, 3, "doc://lhs"}, {5, 2, "doc://rhs"}});

  Vector<Diagnostic> diagnostics;
  diagnostics.push_back({0, 2, DiagnosticSeverity::DIAG_WARNING});
  diagnostics.push_back({1, 3, DiagnosticSeverity::DIAG_ERROR});
  diagnostics.push_back({3, 2, DiagnosticSeverity::DIAG_INFO});
  decorations.setLineDiagnostics(0, std::move(diagnostics));

  // Insert 3 columns at (0,2).
  decorations.adjustForEdit({{0, 2}, {0, 2}}, {0, 5});

  const auto& hints = decorations.getLineInlayHints(0);
  REQUIRE(hints.size() == 2);
  CHECK(hints[0].column == 1);
  CHECK(hints[1].column == 6);

  const auto& phantoms = decorations.getLinePhantomTexts(0);
  REQUIRE(phantoms.size() == 1);
  CHECK(phantoms[0].column == 7);

  const auto& diags = decorations.getLineDiagnostics(0);
  REQUIRE(diags.size() == 3);

  const Diagnostic* warning = findDiag(diags, DiagnosticSeverity::DIAG_WARNING);
  REQUIRE(warning != nullptr);
  CHECK(warning->column == 0);
  CHECK(warning->length == 2);

  const Diagnostic* error = findDiag(diags, DiagnosticSeverity::DIAG_ERROR);
  REQUIRE(error != nullptr);
  CHECK(error->column == 1);
  CHECK(error->length == 6);

  const Diagnostic* info = findDiag(diags, DiagnosticSeverity::DIAG_INFO);
  REQUIRE(info != nullptr);
  CHECK(info->column == 6);
  CHECK(info->length == 2);
}

TEST_CASE("Decorations adjustForEdit updates fold regions and line-based decorations across line delta") {
  Decorations decorations;

  decorations.setLineInlayHints(5, {InlayHint{InlayType::TEXT, 2, 0, "tail"}});
  decorations.setLinePhantomTexts(6, {PhantomText{1, "p"}});
  decorations.setLineLinks(5, {{2, 4, "doc://tail"}});
  decorations.setLineGutterIcons(2, {GutterIcon{11}});
  decorations.setLineGutterIcons(6, {GutterIcon{22}});

  Vector<FoldRegion> regions;
  regions.push_back({1, 3, false});
  regions.push_back({5, 7, true});
  decorations.setFoldRegions(std::move(regions));

  // Replace range [2:1, 4:2] with text ending at 3:0 => line_delta = -1.
  decorations.adjustForEdit({{2, 1}, {4, 2}}, {3, 0});

  const auto& hints_line4 = decorations.getLineInlayHints(4);
  REQUIRE(hints_line4.size() == 1);
  CHECK(hints_line4[0].column == 2);
  CHECK(decorations.getLineInlayHints(5).empty());

  const auto& phantom_line5 = decorations.getLinePhantomTexts(5);
  REQUIRE(phantom_line5.size() == 1);
  CHECK(phantom_line5[0].column == 1);
  CHECK(decorations.getLinePhantomTexts(6).empty());

  const auto& links_line4 = decorations.getLineLinks(4);
  REQUIRE(links_line4.size() == 1);
  CHECK(links_line4[0].column == 2);
  CHECK(links_line4[0].length == 4);
  CHECK(links_line4[0].target == "doc://tail");
  CHECK(decorations.getLineLinks(5).empty());

  CHECK(decorations.getLineGutterIcons(2).size() == 1);
  CHECK(decorations.getLineGutterIcons(5).size() == 1);
  CHECK(decorations.getLineGutterIcons(6).empty());

  const auto& adjusted_regions = decorations.getFoldRegions();
  REQUIRE(adjusted_regions.size() == 2);
  CHECK(adjusted_regions[0].start_line == 1);
  CHECK(adjusted_regions[0].end_line == 2);
  CHECK(adjusted_regions[0].collapsed == false);
  CHECK(adjusted_regions[1].start_line == 4);
  CHECK(adjusted_regions[1].end_line == 6);
  CHECK(adjusted_regions[1].collapsed == true);
}
