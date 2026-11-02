import Observation
import ServiceManagement

@Observable
final class LoginItemSettings {
    private(set) var status = SMAppService.mainApp.status
    private(set) var isUpdating = false
    private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var requiresApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        errorMessage = nil
        isUpdating = true
        Task {
            defer { refresh(); isUpdating = false }
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status != .enabled && service.status != .requiresApproval {
                        try service.register()
                    }
                } else if service.status == .enabled || service.status == .requiresApproval {
                    try await service.unregister()
                }
            } catch {
                errorMessage = L10n.format("Could not update the login item: %@", error.localizedDescription)
            }
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
