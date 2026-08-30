#if os(macOS)
import Foundation
import Combine
import ServiceManagement

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var enabled: Bool = SMAppService.mainApp.status == .enabled
    @Published var lastError: String?

    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            enabled = SMAppService.mainApp.status == .enabled
            lastError = nil
        } catch {
            enabled = SMAppService.mainApp.status == .enabled
            lastError = error.localizedDescription
        }
    }
}
#endif
