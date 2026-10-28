# MCP foundation development checks

Work package 17 supplies an unsigned standalone **synthetic** helper, not an installed
personal-data integration. It needs no developer account, API key, Google connection,
Calendar permission or MCP client configuration. Do not place credentials in arguments,
environment variables or client JSON. [ADR-0022](../architecture/decisions/0022-mcp-server-foundation.md)
records the profile, bounds and still-open signed broker gate.

## Local protocol checks

After selecting the pinned toolchain per [setup](setup.md), from the repository root:

```sh
swift build
python3 Scripts/test_mcp_stdio.py --executable "$(swift build --show-bin-path)/machandle-mcp"
```

`Scripts/validate.sh` includes these nine real subprocess checks in addition to Swift
unit tests and the existing Python suite. Tests launch only the fixed synthetic mode;
stdout carries newline-delimited JSON, and no user app/client settings are changed.
The helper expects pipes or local stream sockets, not a terminal or redirected regular
file. No default live mode exists. Invalid arguments produce a fixed usage message on
stderr and exit 64. Complete malformed JSON gets a protocol error; fatal transport/frame
failures exit nonzero. EOF and signals stop pending work without replay.

Work package 18 adds four synthetic Calendar read tools through the isolated adapter; see
[read checks](mcp-calendar-reads.md). Original foundation tools: `mock_status` (fixed readiness), `mock_add` (two bounded integers),
`mock_wait` (0–1000 ms cancellable delay), `mock_fail` (fixed execution error). No live Calendar,
permission, sync administration, filesystem or credential tools are registered.

## Supplemental official SDK interoperability

This check is separate from CI and installs no runtime/repository dependencies. Node 22.14.0
was used locally with the exact packages below. Run in a disposable directory, with lifecycle
scripts disabled; use ordinary npm registry integrity checks. Preserve the resulting lockfile
outside Git if repeating the identical dependency resolution on another machine.

```sh
mcp_test_root=$(mktemp -d)
cp Scripts/Interop/mcp_sdk_smoke.mjs "$mcp_test_root/smoke.mjs"
npm install --prefix "$mcp_test_root" --ignore-scripts --no-audit --no-fund \
  @modelcontextprotocol/client@2.4.0 @modelcontextprotocol/sdk@1.26.0
node "$mcp_test_root/smoke.mjs" "$(swift build --show-bin-path)/machandle-mcp"
```

The script asserts discovered tools and output schemas through official SDK validation,
structured result values, all four synthetic Calendar reads, privacy and tool errors, then closes each child. It exercises legacy,
pinned-modern and automatic detection. It does not install the helper into Codex/Claude,
authenticate an IPC peer or establish a production client-support promise. Review SDK
versions/schema changes deliberately before updating this matrix.

## Before personal-data integration

The maintainer's account/setup steps remain in [developer setup](google-auth-setup.md).
A stable approved signing identity and successful sandbox/peer-authentication harness are
needed before the app broker is connected. Package 19 must bind each authorized connection
to its channel; client labels, protocol metadata, parent PID and stdio presence are not
identity. Package 18's planned read adapters must remain synthetic/external-disabled until
those gates pass. Google sync continues independently with its own unresolved live gates.
