## 1. Core 存储层(ShelfStoreService)

- [x] 1.1 `load()` 写盘条件化:仅当实际发生版本迁移(含 legacy 根数组解码)或 TTL 过期条目非空时才 `writeUnlocked`,其余读取零写入;新增测试「无迁移无过期时 load 不改写文件(mtime 与内容不变)」「legacy 根数组读取后仍迁移并写回、条目一致」,`swift test` 通过
- [x] 1.2 编码紧凑化:去掉 `.prettyPrinted` 保留 `.sortedKeys`;新增/更新测试断言写出文件可再次解码且体积字段完整,现有 legacy 迁移测试全部通过
- [x] 1.3 条目软上限:`ShelfStoreService.maxItems = 500`,在 `mutate` 的 `normalizeWorkingSet` 之后执行淘汰(按 `updatedAt` 升序,跳过 pinned 与 Working Set 成员);测试覆盖「超限淘汰最旧未保护条目」「最旧条目被 pinned/Working Set 豁免时落到下一个」「未超限不删除任何条目」
- [x] 1.4 捕获单趟化:`captureText` 重写为单次 `mutate`(命中相同文本→仅刷新 `updatedAt`;未命中→追加),新增对称的 `captureURL`(相同 http/https URL→上浮);测试覆盖「新文本一次读一次写语义(单趟 mutate)」「重复文本不新增且上浮」「重复 URL 不新增」「手动 `addText`/`addURL` 仍允许内容相同的多条目」

## 2. Core 排序(SmartShelfRanking)

- [x] 2.1 `ordered` 改为评分预计算:每条目调用 `score` 恰好一次,再按 score → `updatedAt` → `createdAt` → `id` 排序;新增等价性测试(测试内保留旧比较器作参考实现,随机生成的条目集上两种实现输出逐项一致),`swift test` 通过

## 3. App 接线(OpsNotchApp)

- [x] 3.1 触发路径去 I/O:删除 `SensorManager.onMouseEnter` 中的 `model.reload()`(`catchIfChanged()` 兜底保留);`AppModel.reload()` 仅保留 `init` 调用点;`grep -rn "reload()" Sources/` 确认无多余调用点,`swift build` 通过
- [x] 3.2 捕获链路接线:`AppModel.captureClipboardText` 改为 `apply(try store.captureText(text))` + toast(删除 `reload()`);新增拖入文本/URL 的 capture 入口并让 `SensorManager.handle` 的 text/url 分支改调;`swift test` 与 `swift build` 通过
- [x] 3.3 轮询自适应:`AppDelegate` 向 `ClipboardManager` 注入面板可见性闭包,poll 循环按可见性取 100ms(可见)/400ms(不可见),`startMonitoring`/`stopMonitoring` 语义不变;`swift build` 通过

## 4. 全量校验与人工验收

- [x] 4.1 全量门禁:`swift test`、`swift build`、`python3 scripts/static_checks.py` 全部通过(确认受检 API 调用点字符串未被改动)
- [x] 4.2 人工验收(留待用户实测):`./scripts/build_app.sh` 打包安装后,按以下步骤确认——① 300+ 条数据下鼠标移入刘海,抽屉弹出无额外停顿;② 连续两次拖入相同文本,Recent 中只有一条且上浮;③ 任意应用 ⌘C 捕获正常、无卡顿;④ `~/Library/Application Support/lab.hutong.opsnotch/shelf.json` 体积明显缩小且反复触发刘海时 mtime 不变(用户发起 archive 视为实测通过;纯 hover 未写盘与预期一致)
