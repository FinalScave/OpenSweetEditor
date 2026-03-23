# Pull Request

## Pre-submission Checklist

- [ ] Read the contribution guide (docs/zh/join.md) and followed the guidelines
- [ ] Local build passed
- [ ] Unit tests passed (if applicable)
- [ ] Self-review completed

---

## Change Type (select one)

- [ ] `feat` New feature
- [ ] `fix` Bug fix
- [ ] `docs` Documentation/Templates
- [ ] `style` Code style (does not affect functionality)
- [ ] `refactor` Refactor (neither fixes a bug nor adds a feature)
- [ ] `perf` Performance improvement
- [ ] `test` Testing related
- [ ] `chore` Build/CI/Dependencies/Toolchain
- [ ] `revert` Revert
- [ ] `security` Security fix

---

## Testing Status (required)

- [ ] Unit tests completed - All tests passed
- [ ] Unit tests completed - Some tests passed (explain below)
- [ ] Manual testing completed
- [ ] No testing required (documentation/comment changes only)
- [ ] Test plan to be added

**Tested modules/features:**

> Fill in here

**Test environment:**

> Fill in here (e.g., Windows 11 + Visual Studio 2022, Android API 34, etc.)

---

## Impact Scope (select all that apply)

### Core Layer (C++)

- [ ] Document Model (Document)
- [ ] Layout Engine (Layout)
- [ ] Decoration Management (Decoration)
- [ ] EditorCore
- [ ] Gesture Handling (Gesture)
- [ ] C API Bridge (c_api.h)
- [ ] Other core modules

### Platform Layer

- [ ] Android Platform
- [ ] iOS/macOS Platform
- [ ] Windows Platform
- [ ] Swing Platform
- [ ] Web/Emscripten
- [ ] OHOS Platform
- [ ] No platform-related changes

### Infrastructure

- [ ] CI/CD Configuration
- [ ] Build scripts (CMake/Gradle, etc.)
- [ ] Third-party dependencies (3dparty/)

**Platform sync checklist key points:**

- New or modified functions in c_api.h
- Structural changes to TextEditResult / GestureResult / KeyEventResult / ScrollMetrics / LayoutMetrics, etc.
- Rendering model field changes
- Core behavior changes related to IME, gestures, folding, decorations

---

## Change Details

### Summary

<!-- One sentence describing this change -->

### Motivation/Background

> Tip: You can reference an Issue for background

<!-- Why is this change needed? What problem does it solve? -->

### Specific Changes

<!-- Technical implementation details and key notes -->

### Breaking Changes

> Are there any breaking changes? If so, please explain the impact on existing APIs or behavior in detail

---

## Related Issues

> If none, ignore this section

- Fix #`Fill in Issue number`

<details><summary>Example:</summary>

```markdown
- Close #123
  Closes Issue #123
```

| Common keywords                       | Example         |
| ------------------------------------- | --------------- |
| `close` / `closes` / `closed`         | `Close #123`    |
| `fix` / `fixes` / `fixed`             | `Fixes #123`    |
| `resolve` / `resolves` / `resolved`   | `Resolve #123`  |

| Other prefixes                 | Purpose                            | Example           |
| ------------------------------ | ---------------------------------- | ----------------- |
| `ref` / `references` / `refs`  | Reference, does not close          | `Ref #123`        |
| `related` / `relates to`       | Indicates relation                 | `Related to #123` |
| `part of`                      | Indicates part of                  | `Part of #123`    |
| `see` / `see also`             | Reference other Issues             | `See #123`        |
| `re`                           | About/reply to an Issue            | `Re #123`         |
| `addresses`                    | Involves but not fully resolved    | `Addresses #123`  |
| `implements`                   | Implements a feature request       | `Implements #123` |

</details>
