# SweetEditor IME Composition 标准

本文定义 SweetEditor 在不同 `compositionEnabled` 设置与不同输入法语言状态下的 IME composition 行为。这里的 `editor composition` 指 SweetEditor core 自己维护的可见 composition 状态，包括下划线与替换范围；`platform composing range` 指平台 IME API 能感知的 composing/marked range。二者不是同一个概念。

“键盘为英文输入情况”和“键盘为中文输入情况”以当前输入法的语言/脚本状态为准，而不是以待输入文本是否是英文字母为准。比如中文键盘停在英文单词中间时，仍按中文键盘规则处理。

## 1. `compositionEnabled=true`，键盘为英文输入情况下

### （1）空白处输入英文持续处于 `editor composition` 状态

输入英文字符会进入 `editor composition`；删除时正常删除已输入字符，并在删空前保持 composition。删到空后，composition 消失。

举例：输入 `how`，`how` 处于 composition；按删除，剩 `ho` 且仍处于 composition；再按删除，剩 `h` 且仍处于 composition；再按删除，`h` 被删除，composition 消失。

### （2）输入英文状态下切换光标或选区会取消当前 composition

点击 editor 光标切换到其他处，或发生选区变化、拖选、双击选中时，当前 composition 状态消失，光标或选区切换到目标位置。

如果新光标处是可 composition 的英文单词，则新光标处单词开启 `editor composition`；如果新位置不是可 composition 单词，则不重新开启 composition。

举例：输入 `how`，此时 `how` 处于 composition；点击其他行切换光标到其他行后，`how` 的 composition 取消；如果新光标处是可 composition 的英文单词，则该单词呈现 composition 状态。

### （3）英文键盘状态下，光标放到英文单词任意位置都会先开启整词 `editor composition`

光标放到英文单词任意位置时，core 会先开启整词 `editor composition`，下划线覆盖该单词。

但 `editor composition` 和平台 IME composing range 是两个概念：core 可以显示 `editor composition`，下划线可以存在；平台层是否暴露 composing range 由 core 决定。

如果光标在单词末尾，则该整词 `editor composition` 可以暴露给平台 IME。无论后续输入、删除，还是点击英文候选区，单词都处于 composition 状态；点击英文候选区时，候选词替换整段 composition 单词。

举例：第 N 行有单词 `hello`，光标放到 `o` 后面，即 `hello|`，此时 `hello` 处于 composition；继续输入或删除时，单词仍处于 composition；点击英文候选 `helloWorld` 时，`hello` 被替换为 `helloWorld`。

如果光标不在单词末尾，则首次只开启 `editor-only composition`。也就是 core 显示整词下划线，但平台层不把该整词暴露成 IME composing range，避免输入法把普通输入误当成整词替换。

举例：第 N 行有单词 `hello`，光标放到 `e` 后面，即 `he|llo`，此时 `hello` 处于 `editor composition`，下划线覆盖 `hello`；但 Android 侧不通过 `updateSelection` / `TextSnapshot` 暴露该 composing range。

如果光标不在单词末尾，并且首次输入或删除前直接点击英文候选区，则候选词替换整段 `editor composition` 单词。

举例：`he|llo` 且 `hello` 仍处于 `editor composition` 时，直接点击候选 `helloWorld`，则整个 `hello` 被替换为 `helloWorld`。

如果光标不在单词末尾，并且发生首次输入或删除，则该次输入或删除按普通编辑处理，同时立即取消 `editor composition`，下划线消失。之后进入普通英文输入状态，不再重开 `editor composition`，不再向平台暴露 composing range。即使输入法后续继续发送 `setComposingRegion` / 累积式 `setComposingText`，editor 也按普通插入或删除处理。

举例：`he|llo` 输入 `x` 后，结果为 `hex|llo`，composition 立即取消；继续输入 `y` 后，结果为 `hexy|llo`，后续没有 `editor composition`，也没有下划线。

### （4）候选区选择的替换规则只看 core 当前是否仍有 `editor composition`

当前有 `editor composition` 时，候选区选择替换整段 composition。

当前没有 `editor composition` 时，候选区选择按普通文本插入到当前光标处，不替换单词。

举例：`he|llo` 且 `hello` 仍处于 `editor composition` 时，点击候选 `helloWorld` 替换整个 `hello`；如果已经输入 `x` 变成 `hex|llo` 且 composition 已取消，此时再点击残留候选，只能在光标处插入，不能替换整个单词。

### （5）输入法候选栏是否仍显示联想，不等于 editor 是否处于 composition

有些输入法即使 editor 没有提供 composing range 或上下文，也可能基于自己的内部状态显示候选。SweetEditor 不以候选栏外观判断替换范围，只以 core 当前 `editor composition` 判断。

## 2. `compositionEnabled=true`，键盘为中文输入情况下

### （1）editor 内没有任何中文 preedit composition

editor 内不显示中文 preedit 下划线，不建立中文 `editor composing session`。

### （2）点击或移动光标到英文单词内，不开启 `editor composition`

中文键盘状态下，光标放到英文单词任意位置，都只移动 editor 光标，不开启整词 `editor composition`，不显示下划线，也不建立 `editor composing session`。

即使平台输入法因为内部行为发送 `setComposingRegion` / `MARK_DOCUMENT_RANGE` 这类 document range 请求，core 也必须拒绝为中文键盘建立 `editor composition`。如果此前已经存在英文键盘产生的 `editor composition`，切到中文键盘或收到中文键盘的 document range 请求时，当前 `editor composition` 应安全结束，下划线消失，文本保持不变。

举例：中文键盘状态下，光标位于 `he|llo`，结果仍是普通光标 `he|llo`；`hello` 不出现下划线，也不会成为候选替换范围。

### （3）输入中文拼音但未点击候选时，未确认 preedit 不输入到 editor

输入法自己的拼音串、候选栏、联想栏属于输入法内部状态，不属于 `editor composition`。

举例：中文键盘状态下，光标位于 `va|lue`，输入拼音 `nihao` 但未点击候选时，editor 内容仍为 `value`，光标仍在原位置；`nihao` 不写入 editor，也不显示 editor 下划线。

### （4）点击中文候选区后，候选文本按当前光标位置普通插入到 editor

中文候选文本不会替换英文单词。

举例：光标位于 `va|lue`，输入拼音并点击中文候选 `你好` 后，结果为 `va你好|lue`；不会替换成 `你好`。

### （5）中文候选输入到 editor 后，输入法自己的联想候选应正常可用

点击输入法自己的联想候选可继续输入。输入法自己的候选栏或联想栏不属于 `editor composition`，也不决定 editor 替换范围。

## 3. `compositionEnabled=false`，无论键盘为英文还是中文

### （1）editor 内没有任何 `editor composition`

editor 不显示下划线，不建立 `editor composing session`。

### （2）英文键盘使用正常按键输入和删除

英文键盘输入和删除不触发 `editor composition`。

### （3）中文键盘输入拼音但未点击候选时，未确认 preedit 不输入到 editor

输入法自己的未确认 preedit 留在输入法内部，不写入 editor。

### （4）点击中文候选区后，候选文本按当前光标位置普通插入到 editor

中文候选文本不会替换英文单词。

### （5）中文候选输入到 editor 后，输入法自己的联想候选应正常可用

点击输入法自己的联想候选可继续输入。输入法自己的候选栏或联想栏不属于 `editor composition`。
