#if os(macOS)
import SwiftUI
import OpsNotchCore

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OpsSpacing.large) {
                VStack(alignment: .leading, spacing: OpsSpacing.xSmall) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(OpsTypography.secondary)
                            .foregroundStyle(.secondary)
                    }
                }

                content
            }
            .frame(maxWidth: 680, alignment: .topLeading)
            .padding(OpsSpacing.xLarge)
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OpsSpacing.medium) {
            if let title {
                Text(title)
                    .font(OpsTypography.heading)
            }
            content
        }
        .padding(OpsSpacing.large)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: OpsRadius.card, style: .continuous))
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let detail: String?
    let content: Content

    init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        HStack(alignment: detail == nil ? .center : .top, spacing: OpsSpacing.large) {
            VStack(alignment: .leading, spacing: OpsSpacing.micro) {
                Text(title)
                    .font(OpsTypography.body)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(OpsTypography.metadata)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: OpsSpacing.large)
            content
        }
    }
}
#endif
