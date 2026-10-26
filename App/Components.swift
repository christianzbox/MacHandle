import MacHandleApplication
import SwiftUI

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.largeTitle.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PreviewNotice: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text("Interface preview").fontWeight(.semibold)
                Text(
                    "Explore with sample data. No accounts are connected or permissions requested."
                )
                .font(.callout).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "info.circle").foregroundStyle(.tint).accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatusBadge: View {
    let state: PreviewState
    private var symbol: String {
        switch state {
        case .disabled: "pause.circle"
        case .unconfigured: "circle.dashed"
        case .denied: "lock.circle"
        case .unavailable: "exclamationmark.circle"
        case .revoked: "xmark.shield"
        case .enabled: "checkmark.circle"
        }
    }
    var body: some View {
        Label(state.title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(state == .enabled ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyPanel: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title).font(.title3.weight(.semibold))
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(32).frame(maxWidth: .infinity)
    }
}
