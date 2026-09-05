import SwiftUI
import OpsNotchCore

struct WorkspaceQuickPanel: View {
    let profiles: [WorkspaceProfile]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🚀 Workspace")
                .font(.headline)

            ForEach(profiles.filter { $0.enabled }) { profile in
                Button {
                    WorkspaceService.shared.execute(steps: profile.steps)
                } label: {
                    HStack {
                        Text(profile.icon)
                        Text(profile.name)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}
