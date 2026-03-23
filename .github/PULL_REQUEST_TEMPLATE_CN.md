# Pull Request

## 提交前检查清单

- [ ] 已阅读贡献指南 (docs/zh/join.md) 并遵循规范
- [ ] 本地构建通过
- [ ] 单元测试通过 (如有)
- [ ] 代码审查 (Self-review) 完成

---

## 变更分类 (必选其一)

- [ ] `feat` 新功能
- [ ] `fix` Bug 修复
- [ ] `docs` 文档/模板
- [ ] `style` 代码格式 (不影响功能)
- [ ] `refactor` 重构 (既不修复 bug 也不添加功能)
- [ ] `perf` 性能优化
- [ ] `test` 测试相关
- [ ] `chore` 构建/CI/依赖/工具链
- [ ] `revert` 回滚
- [ ] `security` 安全修复

---

## 测试情况 (必选)

- [ ] 已完成单元测试 - 所有测试通过
- [ ] 已完成单元测试 - 部分测试通过 (需在下方说明原因)
- [ ] 已完成手动测试
- [ ] 无需测试 (仅文档/注释等修改)
- [ ] 测试计划待补充

**测试覆盖的模块/功能:**

> 在此填写

**测试环境说明:**

> 在此填写 (如: Windows 11 + Visual Studio 2022, Android API 34 等)

---

## 影响范围 (可多选)

### 核心层 Core (C++)

- [ ] 文档模型 (Document)
- [ ] 布局引擎 (Layout)
- [ ] 装饰管理 (Decoration)
- [ ] 编辑核心 (EditorCore)
- [ ] 手势处理 (Gesture)
- [ ] C API 桥接 (c_api.h)
- [ ] 其他核心模块

### 平台适配层 Platform

- [ ] Android 平台
- [ ] iOS/macOS 平台
- [ ] Windows 平台
- [ ] Swing 平台
- [ ] Web/Emscripten
- [ ] OHOS 平台
- [ ] 不涉及平台相关改动

### 基础设施 Infrastructure

- [ ] CI/CD 配置
- [ ] 构建脚本 (CMake/Gradle等)
- [ ] 第三方依赖 (3dparty/)

**平台同步检查关键点:**

- c_api.h 新增或修改函数
- TextEditResult / GestureResult / KeyEventResult / ScrollMetrics / LayoutMetrics 等结构变更
- 渲染模型字段变更
- IME、手势、折叠、装饰相关的核心行为变更

---

## 变更详情

### 摘要

<!-- 一句话概括本次变更 -->

### 动机/背景

> 提示: 可引用 Issue 作为背景说明

<!-- 为什么需要这个变更? 解决了什么问题? -->

### 具体改动

<!-- 技术实现细节, 以及关键说明 -->

### Breaking Changes

> 是否有破坏性变更? 如有, 请详细说明对现有API或行为的影响

---

## 关联 Issue

> 如果不存在关联, 此项请忽略

- Fix #`填写 Issue 编号`

<details><summary>示例:</summary>

```markdown
- Close #123
  关闭 Issue #123
```

| 常见关键词                          | 示例           |
| ----------------------------------- | -------------- |
| `close` / `closes` / `closed`       | `Close #123`   |
| `fix` / `fixes` / `fixed`           | `Fixes #123`   |
| `resolve` / `resolves` / `resolved` | `Resolve #123` |

| 其他前缀                      | 用途                | 示例              |
| ----------------------------- | ------------------- | ----------------- |
| `ref` / `references` / `refs` | 引用关联, 不关闭    | `Ref #123`        |
| `related` / `relates to`      | 表明相关            | `Related to #123` |
| `part of`                     | 表明是其中一部分    | `Part of #123`    |
| `see` / `see also`            | 参考其他 Issue      | `See #123`        |
| `re`                          | 关于/回复某个 Issue | `Re #123`         |
| `addresses`                   | 涉及但未完全解决    | `Addresses #123`  |
| `implements`                  | 实现某个功能请求    | `Implements #123` |

</details>