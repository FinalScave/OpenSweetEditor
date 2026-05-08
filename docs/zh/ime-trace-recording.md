# IME Trace 录制说明

Android demo 提供 `IME Trace` 入口，用于录制系统 `EditText` 的 IME baseline 行为。录制结果用于判断输入法在系统编辑框上是否调用 Android composition API。

## 打开方式

安装 debug APK 后，桌面会出现 `IME Trace` 入口。打开后页面只显示 `EditText baseline`。

点击 `Start` 后会弹出 case 选择框。选择任意 case 后，录制器从该 case 开始，后续点击 `Next` 会自动保存当前 case、重置文档状态，并进入下一个 case。这样中断后可以直接从中断的 case 继续录，不需要从头开始。

录制中页面会显示当前 case 的键盘模式和操作步骤。点击 `value`、输入、候选点击都需要手动完成；完成当前步骤后点击 `Next`。

控制按钮含义：

- `Next`：保存当前 case 并自动进入下一个 case。
- `Retry`：保存当前 case 为 retry 状态，并重新开始同一个 case。
- `Skip`：保存当前 case 为 skipped 状态，并进入下一个 case。
- `Stop`：保存当前 case 为 stopped 状态，并停止当前批次。

## 推荐场景

每个输入法至少录以下场景。case 开始后录制器只重置文档，不会自动移动光标；必须按表格手动点击 `value` 的指定位置：

| Case | 开始前 | 手动点击位置 | 手动操作 |
|---|---|---|---|
| `CN_WORD_MID_USER_TAP` | 切到中文模式 | 点击 `value` 中 `a` 后面，形成 `va\|lue` | 不输入、不删除、不点候选，等待约 1 秒后点 `Next` |
| `CN_WORD_MID_PINYIN_PREEDIT` | 切到中文模式 | 点击 `value` 中 `a` 后面，形成 `va\|lue` | 输入 `nihao`，不点候选、不按回车，候选 UI 仍可见时点 `Next` |
| `CN_WORD_MID_CANDIDATE` | 切到中文模式 | 点击 `value` 中 `a` 后面，形成 `va\|lue` | 输入 `nihao`，点击第一个中文候选，通常是 `你好`，提交后点 `Next` |
| `CN_WORD_TAIL_USER_TAP` | 切到中文模式 | 点击 `value` 中 `e` 后面，形成 `value\|` | 不输入、不删除、不点候选，等待约 1 秒后点 `Next` |
| `CN_WORD_TAIL_CANDIDATE` | 切到中文模式 | 点击 `value` 中 `e` 后面，形成 `value\|` | 输入 `nihao`，点击第一个中文候选，通常是 `你好`，提交后点 `Next` |
| `EN_WORD_MID_USER_TAP` | 切到英文模式 | 点击 `value` 中 `a` 后面，形成 `va\|lue` | 不输入、不删除、不点候选，等待约 1 秒后点 `Next` |
| `EN_WORD_MID_TYPE` | 切到英文模式 | 点击 `value` 中 `a` 后面，形成 `va\|lue` | 输入 `x`，看到 `vax\|lue` 或等价光标状态后点 `Next` |
| `EN_WORD_MID_DELETE` | 切到英文模式 | 点击 `value` 中 `a` 后面，形成 `va\|lue` | 按软键盘删除键一次，看到删除结果后点 `Next` |
| `EN_WORD_TAIL_TYPE` | 切到英文模式 | 点击 `value` 中 `e` 后面，形成 `value\|` | 输入 `x`，看到 `valuex\|` 或等价光标状态后点 `Next` |
| `EN_WORD_MID_CANDIDATE` | 切到英文模式并开启候选/纠错 | 点击 `value` 中 `a` 后面，形成 `va\|lue` | 如果输入法显示 `value` 相关英文建议或替换候选，点击该候选；如果约 2 秒后没有候选，直接点 `Next` |
| `EN_WORD_TAIL_CANDIDATE` | 切到英文模式并开启候选/纠错 | 点击 `value` 中 `e` 后面，形成 `value\|` | 如果输入法显示 `value` 相关英文建议或替换候选，点击该候选；如果约 2 秒后没有候选，直接点 `Next` |

录候选前可以点 `Candidate` marker，等待时可以点 `Wait` marker。

## 输出位置

trace 写入 app external files：

```text
/sdcard/Android/data/com.qiplat.sweeteditor.demo/files/ime-traces-v4/
```

可用 adb 拉取：

```bash
adb pull /sdcard/Android/data/com.qiplat.sweeteditor.demo/files/ime-traces-v4 D:\Projects\Data\SweetEditor-IME-Traces-v4
```

每个 trace 目录包含：

- `manifest.json`：设备、输入法、subtype、git commit、场景信息。
- `events.ndjson`：逐行事件流。
- `final.json`：最终文档和控件状态。

目录结构按输入法包名与目标控件分组。同一个输入法、目标控件和 case 重录时会覆盖旧目录：

```text
ime-traces-v4/
  com.sohu.inputmethod.sogou/
    edittext/
      01_CN_WORD_MID_USER_TAP/
      02_CN_WORD_MID_PINYIN_PREEDIT/
```

## 分析重点

判断某个输入法是否应该显示下划线时，以 `EditText baseline` 为基准。如果 `EditText` 中没有 `setComposingText` / `setComposingRegion` 或 composing span，SweetEditor 也不应凭空创建平台 composing 下划线。
