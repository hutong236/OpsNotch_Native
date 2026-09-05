## 1. 三处警告修复

- [x] 1.1 `Sources/OpsNotchApp/FloatingPreviewController.swift` `ImagePreviewView.scrollWheel`:把 `guard event.momentumPhase == .none` 改为 `guard event.momentumPhase.isEmpty`,保留惯性不缩放注释;`swift build` 该文件不再报 non-optional 比较警告
- [x] 1.2 `Sources/OpsNotchApp/QuickLookService.swift`:类声明改为 `final class QuickLookService: NSObject, @preconcurrency QLPreviewPanelDataSource`;`swift build` 不再报 conformance-isolation 警告,且 `QLPreviewPanel` 精确调用点保持完好
- [x] 1.3 `Sources/OpsNotchApp/SpotlightRevealService.swift`:通知回调改为从 `note.object as? NSMetadataQuery` 取回查询对象,移除对 `query` 的捕获(保留 `weak self`、`queue: .main`、`MainActor.assumeIsolated` 结构);`swift build` 不再报 Sendable 捕获警告

## 2. 回归验证

- [x] 2.1 `swift build` 全量零警告、零 error(三处警告全部消失)
- [x] 2.2 `swift test` Core 单测全部通过(本次不触碰 Core,应无回归)
- [x] 2.3 `python3 scripts/static_checks.py` 通过

## 3. 人工实测(打包 .app,按 VERIFY_ON_MAC;完成后由用户归档时确认)

- [x] 3.1 `./script/build_and_run.sh` 打包启动,对图片条目打开悬浮放大预览,滚轮滚动可缩放(修复前完全无响应),缩放范围 1x–16x
- [x] 3.2 滚轮松手后的惯性滚动阶段图片保持松手时大小,不持续缩放;捏合手势缩放与拖动平移不受影响
- [x] 3.3 QuickLook(eye 按钮)与 Spotlight 定位应用功能行为与修复前一致
