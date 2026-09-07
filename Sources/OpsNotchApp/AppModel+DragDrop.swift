#if os(macOS)
import Foundation
import OpsNotchCore

extension AppModel {
    /// File Promise 的源文件由其他 App 在 drop 时临时生成，不能以 reference 模式长期指向 staging。
    /// 因此无论用户普通文件的 addMode 如何，Promise 文件都复制进 ShelfStore 管理目录后再清理 staging。
    @discardableResult
    func addPromisedPaths(_ urls: [URL]) -> Int {
        var added = 0
        for url in urls {
            do {
                apply(try store.addPath(url, mode: .copy))
                added += 1
            } catch {
                showToast(error.localizedDescription)
            }
        }
        return added
    }
}
#endif
