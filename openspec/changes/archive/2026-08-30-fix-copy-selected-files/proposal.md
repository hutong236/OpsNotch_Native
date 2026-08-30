# fix-copy-selected-files — 提案

## Why

柜内多选条目后点击"复制所选"对文件类条目完全无效:`ShelfLogic.copyText` 只映射 text/url 条目,文件/文件夹/应用条目(含图片文件)产出空串后 `AppModel.copySelected` 静默返回——既不写剪贴板、也无任何提示。混合选择时文件被静默丢弃,只复制文字部分。用户预期是"选中文件或图片后复制得到真实的文件/图片"(可在 Finder 等处 ⌘V 粘贴),当前该核心取回路径失效。

## What Changes

- **复制所选语义补全**:文件/文件夹/应用条目按文件 URL 写入剪贴板(与 Finder 复制文件同语义、与拖出行为一致),支持一次多选多个文件,粘贴端可取回真实文件;图片文件条目同属文件条目,同样按文件 URL 复制。
- **混合选择多 flavor 写入**:同一剪贴板事务中同时写入文件 URL 与文本两种 flavor,粘贴端按自身能力取用。
- **action 条目归类**:action 条目按 `actionKind` 归入对应 payload(open_path → 文件 URL,open_url → URL 文本),消除"选中 action 条目后复制为空"的死角。
- **剪贴板基线同步**:应用自身写入剪贴板后立即同步 `ClipboardManager` 的 `changeCount` 基线,复制的文件/文本不得回灌 Recent。
- **反馈兜底**:复制成功显示既有"已复制" toast;任何非空选择不再静默无效果。

## Capabilities

### New Capabilities

- `shelf-selection-copy`:柜内多选(⌘/⇧ 点选)与选择条上"复制所选"的取回行为——各条目类型复制到系统剪贴板的 payload 语义、混合选择的多 flavor 写入、自身复制不回灌 Recent、复制反馈。

### Modified Capabilities

<!-- 无:现有 spec 未覆盖"复制所选"行为,拖出/键盘流/右键复制均不在本变更需求面内。 -->

## Impact

- `Sources/OpsNotchCore/ShelfLogic.swift`:新增纯逻辑的复制 payload 归类函数(现有 `copyText` 被取代或收窄),可单测。
- `Sources/OpsNotchApp/ClipboardManager.swift`:新增多 flavor 剪贴板写入方法,写后同步 `handledChangeCount`。
- `Sources/OpsNotchApp/AppModel.swift`:`copySelected(using:)` 改走新的 payload 归类 + 写入路径。
- `Tests/OpsNotchCoreTests/`:新增 payload 归类用例(纯 Core 逻辑,CI 可覆盖)。
- 不触及传感器、拖放注册类型、存储格式;静态检查要求的 `changeCount` 等 API 调用点保持不变。
