# Native bridge sample rehearsal

This follow-up implements [ADR-0036](../architecture/decisions/0036-native-bridge-sample-pairing.md).
The bridge uses real anonymous XPC request/reply within the app/test process, a native pairing
review and the existing Reminders policy adapter. **It is sample-only, not an external MCP connection.**
No signed peer, helper discovery, live provider, account or ChatGPT compatibility is established.

## Native sample flow

Open Connections and find **Native bridge rehearsal**. Nothing starts automatically.

1. Start Sample Launch. Read the selected-list and title/completion scope. This sample does not
   request Apple permissions; its displayed helper label is not external process identity proof.
2. Reject to close it, or Allow Sample Read Connection within the 60-second review lifetime.
   Approval of an old, foreign or expired review cannot pair the launch.
3. Read Sample Reminders. Expect `Synthetic grocery reminder` from `Synthetic selected list`.
   The provider's hidden note, hidden list, real Reminders and other Apple services remain inaccessible.
4. Disconnect or Revoke Sample Connection. Results and review clear. Reading is disabled; a fresh
   sample launch requires another review. Leaving Connections also closes the sample session.

The fixed fixture uses memory settings and synthetic OS/peer observations. It never imports EventKit,
Contacts, a Keychain adapter or a live provider. The existing native provider UI remains independently
opt-in; do not enable it for this rehearsal. No entitlement changes, credentials, files or listener
registration are required. The standalone stdio helper is unchanged and does not connect to this UI.

## Automated acceptance

Run the three repository gates with the pinned toolchain. Focused development command:

```sh
xcrun swift test --filter 'NativeMCPBridgeTests|nativeBridgePreview' -Xswiftc -warnings-as-errors
```

The focused tests cover actual XPC read round trips, deny-before-review, hidden-field/list projection,
wire attempts to approve or mutate, malformed/version/extra/duplicate/oversized input, foreign/replayed/
expired review, default-denied peer, revoke during a suspended read, timeout and cancellation with
late results, and native model result clearing/fresh-review behavior. No OS permission APIs run.
Compiler probes keep broker/factory types unavailable outside the trusted package. Ordinary CI needs
no account, signing key, service registration, permission or external endpoint.

This evidence does not establish a separately launched process, signed sandbox behavior, interactive
UI layout, minimum-OS behavior, provider reads or a real client. Do not describe it as live integration.
Foundation may allocate an incoming Data argument before our byte bound; future authenticated external
transport needs its own ingress/resource review. Retained [activation work](../implementation/activation-backlog.md)
includes identity, signed discovery/peer rejection and provider acceptance before personal data can flow.
