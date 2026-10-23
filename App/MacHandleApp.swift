import MacHandleFoundation
import SwiftUI

@main
struct MacHandleApp: App {
    var body: some Scene {
        WindowGroup(BuildInfo.productName) {
            VStack(spacing: 16) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(BuildInfo.productName)
                    .font(.largeTitle)
                Text(BuildInfo.developmentNotice)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(minWidth: 420, minHeight: 240)
        }
    }
}
