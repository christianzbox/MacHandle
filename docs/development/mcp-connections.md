# MCP connection development checks

Work package 19 implements trusted connection contracts behind the synthetic MCP fixture.
No developer account, key, OS permission or installed client setting is needed for these
checks. The existing [account setup guide](google-auth-setup.md) remains the checklist for
future personal Apple/Google development; this package introduces no additional account.
See [ADR-0024](../architecture/decisions/0024-mcp-connection-identity.md) for the signed gate.

## Run synthetic checks

Select the pinned toolchain per [setup](setup.md), then run:

```sh
swift test --filter 'MCPConnectionsTests|MCPCalendarAdapterTests|MCPServerTests'
swift build
python3 Scripts/test_mcp_stdio.py --executable "$(swift build --show-bin-path)/machandle-mcp"
```

The standard three repository gates include those tests, compiler boundary probes, builds,
analysis and indexed/history scans. The [official SDK procedure](mcp-foundation.md#supplemental-official-sdk-interoperability)
continues to cover SDK 1.26.0 legacy and client 2.4.0 modern/auto with all eight synthetic
tools. SDK versions and MCP profiles are unchanged. There are no pairing, grant, connection
selection or revocation tools exposed over MCP.

Controller tests use deterministic suspended providers/verifiers to reject stale approvals
and late output after revocation. Private-file tests use temporary synthetic directories,
real filesystem permissions/locks/atomic replacement, corrupt versions and injected save
failures. No real permissions database or user preferences are opened. The fixture uses only
explicit in-memory settings and a clearly synthetic peer verifier.

## Future trusted composition

Configure selected resource/operation/field candidates locally; newly saved records have no
active session. Verify the exact shipped channel, request pairing, show the immutable review
in trusted local UI, and approve only that review. Only the resulting lease may compose the
read adapter. On EOF/transport failure call close with the original pending handle; on app
shutdown call shutdown. Observe current OS permission changes and continue independent
per-request OS checks. Do not derive authority from client labels, claimed process names,
protocol metadata, a supplied UUID or possession of an opaque read handle.

Restart restores candidates, never access. Disable closes the active launch; revoke also
persists a revoked marker. Read cancellation is cooperative, but late output is withheld and
uncooperative work retains capacity. No already delivered content can be recalled. On a
settings failure the controller remains closed; diagnose and explicitly repair private
state before restarting, rather than silently resetting permissions.

This is an integration contract, not an available user pairing screen. Native review and
signed mutual peer verification remain owned follow-ups before personal-data activation.
Do not install the synthetic helper as a live integration or pass credentials in arguments,
environment variables or MCP configuration files. No release or enrollment is performed here.
