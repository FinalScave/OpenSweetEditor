#include <catch2/catch_amalgamated.hpp>
#include <chrono>
#include <thread>
#include "keymap.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("KeyResolver resolves default completion shortcuts") {
  KeyResolver resolver;
  resolver.setKeyMap(KeyMap::createDefault());

  const ResolveResult ctrl_result = resolver.resolve({KeyModifier::CTRL, KeyCode::SPACE});
  REQUIRE(ctrl_result.status == ResolveStatus::MATCHED);
  CHECK(ctrl_result.command == EditorCommand::TRIGGER_COMPLETION);

  const ResolveResult meta_result = resolver.resolve({KeyModifier::META, KeyCode::SPACE});
  REQUIRE(meta_result.status == ResolveStatus::MATCHED);
  CHECK(meta_result.command == EditorCommand::TRIGGER_COMPLETION);
}

TEST_CASE("KeyResolver handles pending multi-chord bindings and clears on mismatch") {
  KeyMap key_map;
  key_map.addBinding({{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::C}, EditorCommand::COPY});
  key_map.addBinding({{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::X}, EditorCommand::CUT});

  KeyResolver resolver;
  resolver.setKeyMap(std::move(key_map));

  const ResolveResult first = resolver.resolve({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(first.status == ResolveStatus::PENDING);
  CHECK_FALSE(first.command != EditorCommand::NONE);
  CHECK(resolver.isPending());

  const ResolveResult matched = resolver.resolve({KeyModifier::CTRL, KeyCode::C});
  REQUIRE(matched.status == ResolveStatus::MATCHED);
  CHECK(matched.command == EditorCommand::COPY);
  CHECK_FALSE(resolver.isPending());

  const ResolveResult second_pending = resolver.resolve({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(second_pending.status == ResolveStatus::PENDING);
  CHECK(resolver.isPending());

  const ResolveResult mismatch = resolver.resolve({KeyModifier::CTRL, KeyCode::V});
  CHECK(mismatch.status == ResolveStatus::NO_MATCH);
  CHECK(mismatch.command == EditorCommand::NONE);
  CHECK_FALSE(resolver.isPending());
}

TEST_CASE("KeyResolver pending sequence expires after timeout") {
  KeyMap key_map;
  key_map.addBinding({{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::C}, EditorCommand::COPY});

  KeyResolver resolver(1);
  resolver.setKeyMap(std::move(key_map));

  const ResolveResult pending = resolver.resolve({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(pending.status == ResolveStatus::PENDING);
  CHECK(resolver.isPending());

  std::this_thread::sleep_for(std::chrono::milliseconds(5));

  const ResolveResult expired = resolver.resolve({KeyModifier::CTRL, KeyCode::C});
  CHECK(expired.status == ResolveStatus::NO_MATCH);
  CHECK(expired.command == EditorCommand::NONE);
  CHECK_FALSE(resolver.isPending());
}

TEST_CASE("KeyMap second chord overrides prior single-chord entry on same first chord") {
  KeyMap key_map;
  key_map.addBinding({{KeyModifier::CTRL, KeyCode::K}, {}, EditorCommand::DELETE_LINE});
  key_map.addBinding({{KeyModifier::CTRL, KeyCode::K}, {KeyModifier::CTRL, KeyCode::C}, EditorCommand::COPY});

  const KeyMapEntry* entry = key_map.lookup({KeyModifier::CTRL, KeyCode::K});
  REQUIRE(entry != nullptr);
  REQUIRE(std::holds_alternative<HashMap<KeyChord, EditorCommand, KeyChordHash>>(*entry));

  const auto* sub_map = std::get_if<HashMap<KeyChord, EditorCommand, KeyChordHash>>(entry);
  REQUIRE(sub_map != nullptr);
  const auto it = sub_map->find({KeyModifier::CTRL, KeyCode::C});
  REQUIRE(it != sub_map->end());
  CHECK(it->second == EditorCommand::COPY);
}
