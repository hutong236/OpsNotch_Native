import SwiftUI
import OpsNotchCore

struct WorkspaceSettingsView: View {
    @State private var profiles: [WorkspaceProfile] = WorkspaceProfile.defaults

    var body: some View {
        Form {
            Section("Workspace") {
                ForEach($profiles) { $profile in
                    HStack {
                        Text(profile.icon)
                        TextField("名称", text: $profile.name)
                        Stepper(
                            "Space: \(profile.steps)",
                            value: $profile.steps,
                            in: 1...10
                        )
                        Toggle("启用", isOn: $profile.enabled)
                    }
                }
            }
        }
        .frame(width: 520, height: 320)
        .navigationTitle("Workspace 设置")
    }
}

#Preview {
    WorkspaceSettingsView()
}
