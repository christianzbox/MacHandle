# Pair sample sessions on the first tool call

Branch: `codex/sample-pair-on-first-call`. Sample-only maintenance follow-up to
[slot 6](private-reminders-slot-6.md) and [ADR-0042](../../architecture/decisions/0042-private-desktop-sample-client.md).
GitHub PR #43 was verified merged at `f102ae29c6d1ae9bce64812e6089e3758c3b513c` before branching.

On the home Mac, a Codex draft and the chat receiving the sample prompt started separate
helpers for the same registration. The draft initialized first and retained the native
connection. The user-facing chat failed MCP initialization even after native approval.

Serve the sample's static tool catalog before opening its signed connection. The first valid
tool call creates one connection per helper and starts native review. A helper can neither
borrow another helper's approval nor reconnect after its connection closes. Keep eager
connection checks for both other private relay profiles. Keep signed identity, single-client
admission, native approval, revocation, and journal rules unchanged.

The signed sample harness now initializes and enumerates tools in two helpers, pairs the
caller, and checks that the discovery helper cannot use its approval. Full CI gates remain
required. The maintainer's actual Codex read and approval check is separate from the harness.
Use a separately verified sibling installation for the new build, keeping the earlier signed
package and journal available under the [handoff](../../development/private-testing-handoff.md).
