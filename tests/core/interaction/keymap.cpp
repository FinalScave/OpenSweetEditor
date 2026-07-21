#include <catch2/catch_amalgamated.hpp>
#include <chrono>
#include <thread>
#include <sweeteditor/keymap.h>

using namespace NS_SWEETEDITOR;

namespace {
  EditorCommandId commandId(EditorBuiltinCommand command) {
    return static_cast<EditorCommandId>(command);
  }
}

TEST_CASE("KeyResolver resolves default completion shortcuts") {
  KeyResolver resolver;
  resolver.setKeyMap(KeyMap::createDefault());

  const ResolveResult ctrl_result = resolver.resolve({KeyModifier::CTRL, KeyCode::SPACE});
  REQUIRE(ctrl_result.status == ResolveStatus::MATCHED);
  CHECK(ctrl_result.command == commandId(EditorBuiltinCommand::TRIGGER_COMPLETION));

  const ResolveResult meta_result = resolver.resolve({KeyModifier::META, KeyCode::SPACE});
  REQUIRE(meta_result.status == ResolveStatus::MATCHED);
  CHECK(meta_result.command == commandId(EditorBuiltinCommand::TRIGGER_COMPLETION));
}

TEST_CASE("KeyResolver handles pending multi-chord bindings and clears on mismatch") {
  KeyMap key_map;
  key_map.addBinding(
      {{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::C}, commandId(EditorBuiltinCommand::COPY)});
  key_map.addBinding(
      {{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::X}, commandId(EditorBuiltinCommand::CUT)});

  KeyResolver resolver;
  resolver.setKeyMap(std::move(key_map));

  const ResolveResult first = resolver.resolve({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(first.status == ResolveStatus::PENDING);
  CHECK_FALSE(first.command != commandId(EditorBuiltinCommand::NONE));
  CHECK(resolver.isPending());

  const ResolveResult matched = resolver.resolve({KeyModifier::CTRL, KeyCode::C});
  REQUIRE(matched.status == ResolveStatus::MATCHED);
  CHECK(matched.command == commandId(EditorBuiltinCommand::COPY));
  CHECK_FALSE(resolver.isPending());

  const ResolveResult second_pending = resolver.resolve({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(second_pending.status == ResolveStatus::PENDING);
  CHECK(resolver.isPending());

  const ResolveResult mismatch = resolver.resolve({KeyModifier::CTRL, KeyCode::V});
  CHECK(mismatch.status == ResolveStatus::NO_MATCH);
  CHECK(mismatch.command == commandId(EditorBuiltinCommand::NONE));
  CHECK_FALSE(resolver.isPending());
}

TEST_CASE("KeyResolver pending sequence expires after timeout") {
  KeyMap key_map;
  key_map.addBinding(
      {{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::C}, commandId(EditorBuiltinCommand::COPY)});

  KeyResolver resolver(1);
  resolver.setKeyMap(std::move(key_map));

  const ResolveResult pending = resolver.resolve({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(pending.status == ResolveStatus::PENDING);
  CHECK(resolver.isPending());

  std::this_thread::sleep_for(std::chrono::milliseconds(5));

  const ResolveResult expired = resolver.resolve({KeyModifier::CTRL, KeyCode::C});
  CHECK(expired.status == ResolveStatus::NO_MATCH);
  CHECK(expired.command == commandId(EditorBuiltinCommand::NONE));
  CHECK_FALSE(resolver.isPending());
}

TEST_CASE("KeyMap second chord overrides prior single-chord entry on same first chord") {
  KeyMap key_map;
  key_map.addBinding({{KeyModifier::CTRL, KeyCode::K}, {}, commandId(EditorBuiltinCommand::DELETE_LINE)});
  key_map.addBinding(
      {{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::C}, commandId(EditorBuiltinCommand::COPY)});

  const KeyMapEntry* entry = key_map.lookup({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(entry != nullptr);
  REQUIRE(std::holds_alternative<HashMap<KeyChord, EditorCommandId, KeyChordHash>>(*entry));

  const auto* sub_map = std::get_if<HashMap<KeyChord, EditorCommandId, KeyChordHash>>(entry);
  REQUIRE(sub_map != nullptr);
  const auto it = sub_map->find({KeyModifier::CTRL, KeyCode::C});
  REQUIRE(it != sub_map->end());
  CHECK(it->second == commandId(EditorBuiltinCommand::COPY));
}
