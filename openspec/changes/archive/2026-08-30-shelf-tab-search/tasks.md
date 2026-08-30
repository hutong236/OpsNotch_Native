## 1. Tab 键分支

- [x] 1.1 在 `ShelfWindowController` 本地 keyDown monitor 增加 keyCode 48(Tab)分支:焦点非 `NSTextView` → `model.focusRequestToken = UUID()` 并消费;焦点为搜索框 field editor → 消费但不动焦点;编辑草稿态沿用顶部 guard 放行。验证:`swift build` 通过;`python3 scripts/static_checks.py` 通过。
- [x] 1.2 确认 `ShelfView` 对重复 `focusRequestToken` 的 `onReceive` 幂等(连续按 Tab 不产生副作用)。验证:代码审阅 + `swift test` 无回归。

## 2. 验收与文档

- [x] 2.1 `VERIFY_ON_MAC.md` 键盘取回流小节补 Tab 验收项:鼠标点击条目后按 Tab 焦点回到搜索框、搜索框内按 Tab 焦点不移出、编辑态 Tab 为普通输入。验证:文档更新完成。
- [x] 2.2 真机验收:打包 `./script/build_and_run.sh`,按 2.1 清单人工验证(GUI 验收交用户执行,提供清单)。验证:用户确认或记录待验收。
