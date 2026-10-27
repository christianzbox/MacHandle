import GoogleAuthorization
import SwiftUI

struct GoogleSignInView: View {
    @Bindable var model: GoogleConnectionModel
    @State private var confirmingRevocation = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text(
                    "Google sign-in is optional. It does not enable Apple Calendar access, synchronization or MCP."
                )
                if !model.isConfigured {
                    Label(
                        "Google sign-in is not configured in this build", systemImage: "info.circle"
                    )
                    Text(
                        "Authentication code is available for development, but the app identity and Google client still need setup and verification. You do not need to create a Google Cloud project to use the future published app."
                    )
                    .foregroundStyle(.secondary)
                } else {
                    Text(status).fontWeight(.medium)
                    Text(
                        "Sign-in uses your browser and requests access to calendars created by this app. Credentials stay in this Mac’s Keychain. No Calendar content is transferred by this version."
                    )
                    .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Connect Google") { Task { await model.connect() } }
                        .disabled(!model.isConfigured || model.isBusy || model.state == .connected)
                    if model.state == .authorizing {
                        Button("Cancel Sign-in") { Task { await model.cancel() } }
                    }
                    if model.state == .connected {
                        Button("Check Authorization") { Task { await model.checkAuthorization() } }
                            .disabled(model.isBusy)
                    }
                    if model.isBusy { ProgressView().controlSize(.small) }
                }
                if model.isConfigured {
                    Button("Disconnect This Mac") { Task { await model.disconnect() } }
                        .disabled(model.state == .disconnecting)
                    Text(
                        "Stops local access and removes this app’s saved credentials. It does not delete Google calendars or revoke other installations."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Button("Revoke Google Grant…") { confirmingRevocation = true }
                        .disabled(model.isBusy)
                    Text(
                        "Revocation can affect other installations using the same Google project. It may take time to propagate and does not delete remote data."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Google authentication", systemImage: "key")
        }
        .confirmationDialog("Revoke the Google grant?", isPresented: $confirmingRevocation) {
            Button("Revoke Grant and Disconnect", role: .destructive) {
                Task { await model.disconnect(revokeGoogleGrant: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This can revoke access for other installations using this Google project. Local access stops immediately. Google calendars and events will remain."
            )
        }
    }
    private var status: String {
        switch model.state {
        case .disconnected: "Disconnected on this Mac"
        case .authorizing: "Waiting for sign-in or saved authorization"
        case .connected: "Authorized · Synchronization not configured"
        case .refreshing: "Checking authorization"
        case .disconnecting: "Removing local authorization"
        case .requiresSignIn: "Authorization expired or was revoked. Connect again."
        case .failed(let failure):
            switch failure {
            case .keychainUnavailable:
                "Keychain unavailable. Access is stopped; unlock this Mac and retry. Removal may still be needed."
            case .corruptCredential:
                "Saved authorization is invalid. Disconnect this Mac before signing in again."
            case .revocationFailed:
                "Disconnected locally. Google grant revocation was not confirmed; review access in your Google Account."
            case .cancelled: "Sign-in cancelled."
            case .timedOut: "Sign-in timed out. Connect again when ready."
            case .refused: "Google access was declined."
            case .scopeMismatch:
                "Google returned an unexpected permission scope. Access remains stopped."
            default:
                "Authorization could not be completed. Access remains stopped; retry when ready."
            }
        }
    }
}
