## 1. Clipboard resident memory

- [x] 1.1 将完整上一份文本去重缓存改为固定大小指纹
- [x] 1.2 将完整上一份文件路径数组去重缓存改为固定大小指纹
- [x] 1.3 保持 changeCount baseline 与现有轮询间隔不变

## 2. Local search work control

- [x] 2.1 增加 120ms 查询 debounce
- [x] 2.2 将外层任务取消传递给 detached 搜索
- [x] 2.3 在文件系统遍历热点循环中响应取消

## 3. Validation

- [ ] 3.1 `swift test`
- [ ] 3.2 `swift build`
- [ ] 3.3 `python3 scripts/static_checks.py`
- [ ] 3.4 macOS 人工长驻验证：复制大文本、快速搜索后观察内存趋于稳定
