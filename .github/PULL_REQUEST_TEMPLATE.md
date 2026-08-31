## 变更目标

<!-- 说明问题、用户场景和本 PR 的范围。 -->

## 实现摘要

<!-- 描述关键实现和重要取舍。 -->

## 验证

- [ ] swift test
- [ ] swift build
- [ ] python3 scripts/static_checks.py
- [ ] 已完成相关 VERIFY_ON_MAC.md 实机项目，或说明不适用

测试环境：

- macOS：
- 芯片：
- 显示器：
- 拖放来源应用：

## 风险检查

- [ ] 未破坏 OpsNotchApp → OpsNotchCore 的单向依赖
- [ ] 所有条目动作仍经过 SafeActionValidator
- [ ] 未引入 Shell、任意命令执行或未声明网络行为
- [ ] 未破坏旧 shelf.json 兼容性，或已提供迁移与测试
- [ ] 新增界面文案已同时提供中英文
- [ ] 用户可见变化已更新文档或变更记录

## 关联

Closes #