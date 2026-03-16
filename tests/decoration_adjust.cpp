#include <catch2/catch_amalgamated.hpp>
#include "decoration.h"

using namespace NS_SWEETEDITOR;

namespace {
  const DiagnosticSpan* findDiag(const Vector<DiagnosticSpan>& diags, DiagnosticSeverity severity) {
    for (const auto& diag : diags) {
      if (diag.severity == severity) return &diag;
    }
    return nullptr;
  }
}

TEST_CASE("DecorationManager adjustForEdit shifts same-line point and span decorations") {
  DecorationManager manager;

  manager.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 1, "lhs"}, InlayHint{InlayType::TEXT, 3, "rhs"}});
  manager.setLinePhantomTexts(0, {PhantomText{4, "ghost"}});

  Vector<DiagnosticSpan> diagnostics;
  diagnostics.push_back({0, 2, DiagnosticSeverity::DIAG_WARNING, 0});
  diagnostics.push_back({1, 3, DiagnosticSeverity::DIAG_ERROR, 0});
  diagnostics.push_back({3, 2, DiagnosticSeverity::DIAG_INFO, 0});
  manager.setLineDiagnostics(0, std::move(diagnostics));

  // Insert 3 columns at (0,2).
  manager.adjustForEdit({{0, 2}, {0, 2}}, {0, 5});

  const auto& hints = manager.getLineInlayHints(0);
  REQUIRE(hints.size() == 2);
  CHECK(hints[0].column == 1);
  CHECK(hints[1].column == 6);

  const auto& phantoms = manager.getLinePhantomTexts(0);
  REQUIRE(phantoms.size() == 1);
  CHECK(phantoms[0].column == 7);

  const auto& diags = manager.getLineDiagnostics(0);
  REQUIRE(diags.size() == 3);

  const DiagnosticSpan* warning = findDiag(diags, DiagnosticSeverity::DIAG_WARNING);
  REQUIRE(warning != nullptr);
  CHECK(warning->column == 0);
  CHECK(warning->length == 2);

  const DiagnosticSpan* error = findDiag(diags, DiagnosticSeverity::DIAG_ERROR);
  REQUIRE(error != nullptr);
  CHECK(error->column == 1);
  CHECK(error->length == 6);

  const DiagnosticSpan* info = findDiag(diags, DiagnosticSeverity::DIAG_INFO);
  REQUIRE(info != nullptr);
  CHECK(info->column == 6);
  CHECK(info->length == 2);
}

TEST_CASE("DecorationManager adjustForEdit updates fold regions and line-based decorations across line delta") {
  DecorationManager manager;

  manager.setLineInlayHints(5, {InlayHint{InlayType::TEXT, 2, "tail"}});
  manager.setLinePhantomTexts(6, {PhantomText{1, "p"}});
  manager.setLineGutterIcons(2, {GutterIcon{11}});
  manager.setLineGutterIcons(6, {GutterIcon{22}});

  Vector<FoldRegion> regions;
  regions.push_back({1, 3, false});
  regions.push_back({5, 7, true});
  manager.setFoldRegions(std::move(regions));

  // Replace range [2:1, 4:2] with text ending at 3:0 => line_delta = -1.
  manager.adjustForEdit({{2, 1}, {4, 2}}, {3, 0});

  const auto& hints_line4 = manager.getLineInlayHints(4);
  REQUIRE(hints_line4.size() == 1);
  CHECK(hints_line4[0].column == 2);
  CHECK(manager.getLineInlayHints(5).empty());

  const auto& phantom_line5 = manager.getLinePhantomTexts(5);
  REQUIRE(phantom_line5.size() == 1);
  CHECK(phantom_line5[0].column == 1);
  CHECK(manager.getLinePhantomTexts(6).empty());

  CHECK(manager.getLineGutterIcons(2).size() == 1);
  CHECK(manager.getLineGutterIcons(5).size() == 1);
  CHECK(manager.getLineGutterIcons(6).empty());

  const auto& adjusted_regions = manager.getFoldRegions();
  REQUIRE(adjusted_regions.size() == 2);
  CHECK(adjusted_regions[0].start_line == 1);
  CHECK(adjusted_regions[0].end_line == 2);
  CHECK(adjusted_regions[0].collapsed == false);
  CHECK(adjusted_regions[1].start_line == 4);
  CHECK(adjusted_regions[1].end_line == 6);
  CHECK(adjusted_regions[1].collapsed == true);
}
