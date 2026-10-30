#!/bin/bash
# Invoked after swift build by validate.sh, with its already-verified toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
from pathlib import Path
import json
import re
import subprocess

package = json.loads(subprocess.check_output(["xcrun", "swift", "package", "dump-package"]))
mcp = next(target for target in package["targets"] if target["name"] == "MCPServer")
helper = next(target for target in package["targets"] if target["name"] == "MacHandleMCP")
adapter = next(target for target in package["targets"] if target["name"] == "MCPCalendarAdapter")
if mcp["dependencies"] or helper["dependencies"] != [{"byName": [n, None]} for n in ["MCPServer", "MCPCalendarAdapter", "MCPRemindersAdapter", "MCPContactsAdapter"]]:
    raise SystemExit("MCP transport must stay independent; helper receives only the synthetic adapter")
if adapter["dependencies"] != [{"byName": [n, None]} for n in ["MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections"]]:
    raise SystemExit("MCP read adapter must depend only on protocol, domain, policy and connection contracts")
for target, allowed in {
    "NativeSampleWrites": {"Foundation", "Observation", "CoreDomain", "PermissionEngine", "MCPConnections", "MCPServer", "MCPRemindersAdapter", "NativeMCPBridge", "LocalBridgeTransport", "ActionApprovals", "ReminderMutations", "SyncPersistence"},
    "MacHandlePrivateWrites": {"AppKit", "SwiftUI", "NativeSampleWrites"},
    "MCPServer": {"Foundation", "Dispatch", "Darwin"},
    "LocalBridgeTransport": {"Foundation", "Security", "CryptoKit"},
    "ReminderMCPContract": {"MCPServer"},
    "MacHandleLocalMCP": {"Darwin", "Foundation", "LocalBridgeTransport", "MCPServer", "ReminderMCPContract"},
    "MacHandlePrivateReminders": {"AppKit", "SwiftUI", "MacHandleApplication", "AppleCalendarProvider"},
    "MacHandlePrivateSample": {"AppKit", "SwiftUI", "MacHandleApplication"},
    "BridgeProbe": {"Foundation", "Darwin", "LocalBridgeTransport"},
    "SampleBroker": {"Foundation", "Darwin", "LocalBridgeTransport", "NativeMCPBridge"},
    "NativeMCPBridge": {"Foundation", "CoreDomain", "PermissionEngine", "MCPConnections", "MCPServer", "MCPRemindersAdapter", "LocalBridgeTransport"},
    "MacHandleMCP": {"Darwin", "MCPServer", "MCPCalendarAdapter", "MCPRemindersAdapter", "MCPContactsAdapter"},
    "MCPRemindersAdapter": {"Foundation", "MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections", "ActionApprovals", "ReminderMCPContract"},
    "MCPContactsAdapter": {"Foundation", "MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections", "ActionApprovals"},
    "AppleContactsProvider": {"Foundation", "Contacts", "CoreDomain"},
    "MCPConnections": {"Foundation", "Darwin", "CoreDomain", "PermissionEngine"},
    "ContactMutations": {"Foundation", "CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence", "Contacts", "CryptoKit"},
    "ReminderMutations": {"Foundation", "CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence", "EventKit"},
    "CalendarMutations": {"Foundation", "CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence", "EventKit"},
    "ActionApprovals": {"Foundation", "CoreDomain", "PermissionEngine"},
}.items():
    for path in Path("Sources", target).rglob("*.swift"):
        imports = re.findall(r"^import (\w+)", path.read_text(), re.M)
        if any(module not in allowed for module in imports):
            raise SystemExit("MCP transport must remain isolated from its synthetic composition")
for path in Path("Sources/MCPCalendarAdapter").rglob("*.swift"):
    imports = re.findall(r"^import (\w+)", path.read_text(), re.M)
    if any(module not in {"Foundation", "CoreDomain", "PermissionEngine", "MCPServer", "MCPConnections"} for module in imports):
        raise SystemExit("MCP adapter must not import live providers, credentials, persistence or UI")
    if path.name != "SyntheticCalendarTools.swift" and "PolicyAuthority" in path.read_text():
        raise SystemExit("Only the fixed synthetic fixture may compose policy administration")
reminders = next(target for target in package["targets"] if target["name"] == "MCPRemindersAdapter")
if reminders["dependencies"] != [{"byName": [n, None]} for n in ["MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections", "ActionApprovals", "ReminderMCPContract"]]:
    raise SystemExit("Reminders MCP reads must remain isolated from live providers and writers")
for path in Path("Sources/MCPRemindersAdapter").rglob("*.swift"):
    if path.name != "SyntheticReminderTools.swift" and ("PolicyAuthority" in path.read_text() or "ConnectionController(" in path.read_text()):
        raise SystemExit("Only the fixed Reminders fixture may configure trusted grants")
contacts = next(target for target in package["targets"] if target["name"] == "MCPContactsAdapter")
if contacts["dependencies"] != [{"byName": [n, None]} for n in ["MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections", "ActionApprovals"]]:
    raise SystemExit("Contacts MCP reads must remain isolated from live providers and writers")
for path in Path("Sources/MCPContactsAdapter").rglob("*.swift"):
    if path.name != "SyntheticContactTools.swift" and ("PolicyAuthority" in path.read_text() or "ConnectionController(" in path.read_text()):
        raise SystemExit("Only the fixed Contacts fixture may configure trusted grants")
contact_mutations = next(target for target in package["targets"] if target["name"] == "ContactMutations")
if contact_mutations["dependencies"] != [{"byName": [n, None]} for n in ["CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence"]]:
    raise SystemExit("Contacts writes must stay behind independent approval and journal contracts")
contact_provider = next(target for target in package["targets"] if target["name"] == "AppleContactsProvider")
if contact_provider["dependencies"] != [{"byName": ["CoreDomain", None]}]:
    raise SystemExit("Contacts provider must depend only on domain contracts")
connections = next(target for target in package["targets"] if target["name"] == "MCPConnections")
if connections["dependencies"] != [{"byName": [n, None]} for n in ["CoreDomain", "PermissionEngine"]]:
    raise SystemExit("Connection administration must stay independent of transport, providers and UI")
domain = next(target for target in package["targets"] if target["name"] == "CoreDomain")
if domain["dependencies"]:
    raise SystemExit("CoreDomain must not depend on infrastructure targets or packages")
policy = next(target for target in package["targets"] if target["name"] == "PermissionEngine")
if policy["dependencies"] != [{"byName": ["CoreDomain", None]}]:
    raise SystemExit("PermissionEngine must depend only on CoreDomain")
approvals = next(target for target in package["targets"] if target["name"] == "ActionApprovals")
if approvals["dependencies"] != [{"byName": [n, None]} for n in ["CoreDomain", "PermissionEngine"]]:
    raise SystemExit("Approval engine must remain independent of live providers and transport")
mutations = next(target for target in package["targets"] if target["name"] == "CalendarMutations")
if mutations["dependencies"] != [{"byName": [n, None]} for n in ["CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence"]]:
    raise SystemExit("Calendar mutations must stay behind approval and persistence boundaries")
reminder_mutations = next(target for target in package["targets"] if target["name"] == "ReminderMutations")
if reminder_mutations["dependencies"] != [{"byName": [n, None]} for n in ["CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence"]]:
    raise SystemExit("Reminder mutations must remain behind independent approval and journal boundaries")
application = next(target for target in package["targets"] if target["name"] == "MacHandleApplication")
if application["dependencies"] != [{"byName": [n, None]} for n in ["CoreDomain", "PermissionEngine", "ActionApprovals", "NativeMCPBridge"]]:
    raise SystemExit("Application must depend on contracts/policy, never the EventKit provider")
bridge = next(target for target in package["targets"] if target["name"] == "NativeMCPBridge")
if bridge["dependencies"] != [{"byName": [n, None]} for n in ["CoreDomain", "PermissionEngine", "MCPConnections", "MCPServer", "MCPRemindersAdapter", "LocalBridgeTransport"]]:
    raise SystemExit("Native bridge must have no live provider, credential, mutation or storage dependency")
for name, dependencies in {
    "NativeSampleWrites": ["CoreDomain", "PermissionEngine", "MCPConnections", "MCPServer", "MCPRemindersAdapter", "NativeMCPBridge", "LocalBridgeTransport", "ActionApprovals", "ReminderMutations", "SyncPersistence"],
    "MacHandlePrivateWrites": ["NativeSampleWrites"],
    "LocalBridgeTransport": [],
    "ReminderMCPContract": ["MCPServer"],
    "MacHandleLocalMCP": ["LocalBridgeTransport", "MCPServer", "ReminderMCPContract"],
    "MacHandlePrivateSample": ["MacHandleApplication"],
    "MacHandlePrivateReminders": ["MacHandleApplication", "AppleCalendarProvider"],
    "BridgeProbe": ["LocalBridgeTransport"],
    "SampleBroker": ["NativeMCPBridge", "LocalBridgeTransport"],
}.items():
    target = next(target for target in package["targets"] if target["name"] == name)
    if target["dependencies"] != [{"byName": [n, None]} for n in dependencies]:
        raise SystemExit("External helper must not own providers, credentials, policy or approval administration")
auth = next(target for target in package["targets"] if target["name"] == "GoogleAuthorization")
if auth["dependencies"]:
    raise SystemExit("GoogleAuthorization must stay independent of Calendar, policy, and MCP")
persistence = next(target for target in package["targets"] if target["name"] == "SyncPersistence")
if persistence["dependencies"]:
    raise SystemExit("SyncPersistence must stay independent of providers, UI, and domain authority")
for path in Path("Sources/SyncPersistence").rglob("*.swift"):
    imports = re.findall(r"^import (\w+)", path.read_text(), re.M)
    if any(module not in {"Foundation", "Darwin", "SQLite3"} for module in imports):
        raise SystemExit("Persistence must remain isolated from providers and UI")
executor = next(target for target in package["targets"] if target["name"] == "SyncExecution")
if executor["dependencies"] != [{"byName": [name, None]} for name in ["CoreDomain", "SyncPlanning", "SyncPersistence", "GoogleAuthorization"]]:
    raise SystemExit("SyncExecution dependencies must remain explicit and contain no Apple provider")
for path in Path("Sources/SyncExecution").rglob("*.swift"):
    imports = re.findall(r"^import (\w+)", path.read_text(), re.M)
    if any(module not in {"Foundation", "CoreDomain", "SyncPlanning", "SyncPersistence", "GoogleAuthorization"} for module in imports):
        raise SystemExit("Executor must not import Apple providers or UI")
planner = next(target for target in package["targets"] if target["name"] == "SyncPlanning")
if planner["dependencies"] != [{"byName": ["CoreDomain", None]}]:
    raise SystemExit("SyncPlanning must depend only on CoreDomain")
for path in Path("Sources/SyncPlanning").rglob("*.swift"):
    imports = re.findall(r"^import (\w+)", path.read_text(), re.M)
    if any(module not in {"Foundation", "CoreDomain", "CryptoKit"} for module in imports):
        raise SystemExit("Planner must remain independent of providers, persistence and UI")
provider = next(target for target in package["targets"] if target["name"] == "AppleCalendarProvider")
if provider["dependencies"] != [{"byName": ["CoreDomain", None]}]:
    raise SystemExit("AppleCalendarProvider must depend only on CoreDomain")
for path in list(Path("Sources/MacHandleApplication").rglob("*.swift")) + list(Path("App").rglob("*.swift")):
    if re.search(r"^\s*import\s+EventKit\b", path.read_text(), re.M):
        raise SystemExit("EventKit must remain inside isolated provider targets")
sources = list(Path("Sources/CoreDomain").rglob("*.swift")) + list(Path("Sources/PermissionEngine").rglob("*.swift"))
for path in sources:
    imports = re.findall(
        r"^[ \t]*(?:@\w+[ \t]+)*(?:(?:public|internal|package|private|fileprivate)[ \t]+)?import[ \t]+"
        r"(?:(?:typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?([\w.]+)",
        path.read_text(), re.M,
    )
    allowed = {"Foundation"} if "CoreDomain" in path.parts else {"Foundation", "CoreDomain"}
    if any(module not in allowed for module in imports):
        raise SystemExit("Domain/policy imports must remain independent of infrastructure")
PY

domain_check_dir=$(mktemp -d "${TMPDIR:-/tmp}/machandle-domain.XXXXXX")
trap 'rm -rf "$domain_check_dir"' EXIT
domain_product_dir="$(xcrun swift build --show-bin-path)"
domain_target="$(uname -m)-apple-macosx14.0"

cat > "$domain_check_dir/positive.swift" <<'SWIFT'
import CoreDomain
import PermissionEngine
import SyncPlanning
func plan(_ input: ReconciliationInput) -> ReconciliationPlan { ReconciliationPlanner.plan(input) }
func read(_ source: any CalendarReading, _ request: CalendarReadRequest) async {
    _ = await source.readOccurrences(request)
}
func write(_ destination: any CalendarWriting, _ proposal: ProposedChange<CalendarMutation>) async {
    _ = await destination.apply(proposal)
}
func check(_ session: PolicySession, _ request: PolicyRequest) async {
    _ = await session.evaluate(request)
}
SWIFT
xcrun swiftc -swift-version 6 -warnings-as-errors -target "$domain_target" \
    -I "$domain_product_dir" -I "$domain_product_dir/Modules" -typecheck "$domain_check_dir/positive.swift"

cat > "$domain_check_dir/reader-write.swift" <<'SWIFT'
import CoreDomain
func invalid(_ source: any CalendarReading, _ proposal: ProposedChange<CalendarMutation>) async {
    _ = await source.apply(proposal)
}
SWIFT
cat > "$domain_check_dir/identity.swift" <<'SWIFT'
import CoreDomain
func invalid(_ id: ConnectionID) -> EventID { id }
SWIFT
cat > "$domain_check_dir/unified-write.swift" <<'SWIFT'
import CoreDomain
func invalid(_ contact: ContactReference) -> ContactMutation {
    .delete(contact, precondition: .unknown)
}
SWIFT

expect_rejection() {
    local fixture="$1" diagnostic="$2"
    if xcrun swiftc -swift-version 6 -target "$domain_target" \
        -I "$domain_product_dir" -I "$domain_product_dir/Modules" \
        -typecheck "$domain_check_dir/$fixture.swift" > "$domain_check_dir/diagnostic" 2>&1; then
        echo "Domain boundary failed: invalid $fixture compiled" >&2
        exit 1
    fi
    if ! grep -Fq "$diagnostic" "$domain_check_dir/diagnostic"; then
        echo "Domain boundary failed: unexpected $fixture diagnostic" >&2
        exit 1
    fi
}
expect_rejection reader-write "has no member 'apply'"
expect_rejection identity "cannot convert"
expect_rejection unified-write "cannot convert"
cat > "$domain_check_dir/policy-admin.swift" <<'SWIFT'
import CoreDomain
import PermissionEngine
func invalid(_ session: PolicySession, _ connection: Connection) async {
    await session.setConnection(connection)
}
SWIFT
cat > "$domain_check_dir/policy-authority.swift" <<'SWIFT'
import PermissionEngine
func invalid(_ session: PolicySession) { _ = session.authority }
SWIFT
cat > "$domain_check_dir/policy-permit.swift" <<'SWIFT'
import PermissionEngine
func invalid() { _ = PolicyPermit() }
SWIFT
cat > "$domain_check_dir/availability-detail.swift" <<'SWIFT'
import PermissionEngine
func invalid(_ availability: PermittedAvailability) { _ = availability.coverage }
SWIFT
expect_rejection policy-admin "has no member 'setConnection'"
expect_rejection policy-authority "inaccessible due to 'internal' protection level"
expect_rejection policy-permit "inaccessible due to 'internal' protection level"
expect_rejection availability-detail "has no member 'coverage'"
cat > "$domain_check_dir/reader-permission.swift" <<'SWIFT'
import CoreDomain
func invalid(_ source: any CalendarReading) async { _ = await source.requestAccess() }
SWIFT
expect_rejection reader-permission "has no member 'requestAccess'"
cat > "$domain_check_dir/oauth-credentials.swift" <<'SWIFT'
import GoogleAuthorization
func invalid(_ auth: GoogleAuthentication) { _ = auth.credentials }
SWIFT
expect_rejection oauth-credentials "inaccessible due to 'private' protection level"
cat > "$domain_check_dir/destination-client.swift" <<'SWIFT'
import GoogleAuthorization
func invalid(_ auth: GoogleAuthentication) { _ = GoogleDestinationClient(transport: auth) }
SWIFT
cat > "$domain_check_dir/calendar-bearer.swift" <<'SWIFT'
import GoogleAuthorization
func invalid(_ auth: GoogleAuthentication) async { _ = try await auth.calendarLease() }
SWIFT
expect_rejection destination-client "cannot find 'GoogleDestinationClient' in scope"
expect_rejection calendar-bearer "inaccessible due to 'internal' protection level"
cat > "$domain_check_dir/persistence-sql.swift" <<'SWIFT'
import SyncPersistence
func invalid(_ store: SQLiteSyncStore) { _ = store.database }
SWIFT
expect_rejection persistence-sql "inaccessible due to 'private' protection level"
cat > "$domain_check_dir/planner-authority.swift" <<'SWIFT'
import CoreDomain
import SyncPlanning
func invalid(_ writer: any CalendarWriting, _ proposal: ReconciliationProposal) async {
    _ = await writer.apply(proposal)
}
SWIFT
expect_rejection planner-authority "cannot convert value"
cat > "$domain_check_dir/executor-activation.swift" <<'SWIFT'
import SyncExecution
let executor = SynchronizationExecutor.self
SWIFT
cat > "$domain_check_dir/durable-provider.swift" <<'SWIFT'
import GoogleAuthorization
let provider = GoogleDurableDestination.self
SWIFT
expect_rejection executor-activation "cannot find 'SynchronizationExecutor' in scope"
expect_rejection durable-provider "cannot find 'GoogleDurableDestination' in scope"
cat > "$domain_check_dir/recovery-activation.swift" <<'SWIFT'
import SyncExecution
let recovery = SynchronizationRecovery.self
SWIFT
expect_rejection recovery-activation "cannot find 'SynchronizationRecovery' in scope"
cat > "$domain_check_dir/background-activation.swift" <<'SWIFT'
import SyncExecution
let scheduler = BackgroundSynchronization.self
SWIFT
expect_rejection background-activation "cannot find 'BackgroundSynchronization' in scope"
cat > "$domain_check_dir/onboarding-activation.swift" <<'SWIFT'
import SyncExecution
let workflow = GoogleSyncWorkflow.self
SWIFT
expect_rejection onboarding-activation "cannot find 'GoogleSyncWorkflow' in scope"
cat > "$domain_check_dir/mcp-session.swift" <<'SWIFT'
import MCPServer
let session = MCPProtocolSession.self
SWIFT
cat > "$domain_check_dir/mcp-registry.swift" <<'SWIFT'
import MCPServer
let tool = MCPTool.self
SWIFT
expect_rejection mcp-session "cannot find 'MCPProtocolSession' in scope"
expect_rejection mcp-registry "cannot find 'MCPTool' in scope"
cat > "$domain_check_dir/mcp-read-adapter.swift" <<'SWIFT'
import MCPCalendarAdapter
let adapter = CalendarReadAdapter.self
SWIFT
cat > "$domain_check_dir/mcp-synthetic-factory.swift" <<'SWIFT'
import MCPCalendarAdapter
let factory = SyntheticCalendarTools.self
SWIFT
expect_rejection mcp-read-adapter "cannot find 'CalendarReadAdapter' in scope"
expect_rejection mcp-synthetic-factory "cannot find 'SyntheticCalendarTools' in scope"
cat > "$domain_check_dir/mcp-connection-admin.swift" <<'SWIFT'
import MCPConnections
let forbidden = ConnectionController.self
SWIFT
expect_rejection mcp-connection-admin "cannot find 'ConnectionController' in scope"
cat > "$domain_check_dir/mcp-pairing-review.swift" <<'SWIFT'
import MCPConnections
let forbidden = PairingReview.self
SWIFT
expect_rejection mcp-pairing-review "cannot find 'PairingReview' in scope"
cat > "$domain_check_dir/mcp-connection-channel.swift" <<'SWIFT'
import MCPConnections
let forbidden = ConnectionChannel.self
SWIFT
expect_rejection mcp-connection-channel "cannot find 'ConnectionChannel' in scope"
cat > "$domain_check_dir/mcp-connection-lease.swift" <<'SWIFT'
import MCPConnections
let forbidden = ConnectionReadLease.self
SWIFT
expect_rejection mcp-connection-lease "cannot find 'ConnectionReadLease' in scope"
cat > "$domain_check_dir/approval-engine.swift" <<'SWIFT'
import ActionApprovals
let forbidden = CalendarApprovalEngine.self
SWIFT
expect_rejection approval-engine "cannot find 'CalendarApprovalEngine' in scope"
cat > "$domain_check_dir/approval-confirmation.swift" <<'SWIFT'
import ActionApprovals
let forbidden = ActionConfirmation.self
SWIFT
expect_rejection approval-confirmation "cannot find 'ActionConfirmation' in scope"
cat > "$domain_check_dir/approval-dispatch.swift" <<'SWIFT'
import ActionApprovals
let forbidden = AuthorizedCalendarAction.self
SWIFT
expect_rejection approval-dispatch "cannot find 'AuthorizedCalendarAction' in scope"
cat > "$domain_check_dir/approval-fixture.swift" <<'SWIFT'
import ActionApprovals
let forbidden = SyntheticActionFixture.self
SWIFT
expect_rejection approval-fixture "cannot find 'SyntheticActionFixture' in scope"
cat > "$domain_check_dir/calendar-writer.swift" <<'SWIFT'
import CalendarMutations
let forbidden = JournaledCalendarProvider.self
SWIFT
expect_rejection calendar-writer "cannot find 'JournaledCalendarProvider' in scope"
cat > "$domain_check_dir/calendar-backend.swift" <<'SWIFT'
import CalendarMutations
let forbidden = EventKitMutationBackend.self
SWIFT
expect_rejection calendar-backend "cannot find 'EventKitMutationBackend' in scope"
cat > "$domain_check_dir/calendar-journal.swift" <<'SWIFT'
import SyncPersistence
let forbidden = CalendarMutationJournal.self
SWIFT
expect_rejection calendar-journal "cannot find 'CalendarMutationJournal' in scope"
cat > "$domain_check_dir/reminder-adapter.swift" <<'SWIFT'
import MCPRemindersAdapter
let forbidden = ReminderReadAdapter.self
SWIFT
expect_rejection reminder-adapter "cannot find 'ReminderReadAdapter' in scope"
cat > "$domain_check_dir/reminder-fixture.swift" <<'SWIFT'
import MCPRemindersAdapter
let forbidden = SyntheticReminderTools.self
SWIFT
expect_rejection reminder-fixture "cannot find 'SyntheticReminderTools' in scope"

cat > "$domain_check_dir/reminder-approval.swift" <<'SWIFT'
import ActionApprovals
let forbidden = ReminderApprovalEngine.self
SWIFT
expect_rejection reminder-approval "cannot find 'ReminderApprovalEngine' in scope"
cat > "$domain_check_dir/reminder-confirmation.swift" <<'SWIFT'
import ActionApprovals
let forbidden = ReminderConfirmation.self
SWIFT
expect_rejection reminder-confirmation "cannot find 'ReminderConfirmation' in scope"
cat > "$domain_check_dir/reminder-writer.swift" <<'SWIFT'
import ReminderMutations
let forbidden = JournaledReminderProvider.self
SWIFT
expect_rejection reminder-writer "cannot find 'JournaledReminderProvider' in scope"
cat > "$domain_check_dir/reminder-backend.swift" <<'SWIFT'
import ReminderMutations
let forbidden = EventKitReminderMutationBackend.self
SWIFT
expect_rejection reminder-backend "cannot find 'EventKitReminderMutationBackend' in scope"
cat > "$domain_check_dir/reminder-mutation-adapter.swift" <<'SWIFT'
import MCPRemindersAdapter
let forbidden = ReminderMutationAdapter.self
SWIFT
expect_rejection reminder-mutation-adapter "cannot find 'ReminderMutationAdapter' in scope"
cat > "$domain_check_dir/contact-adapter.swift" <<'SWIFT'
import MCPContactsAdapter
let forbidden = ContactReadAdapter.self
SWIFT
expect_rejection contact-adapter "cannot find 'ContactReadAdapter' in scope"
cat > "$domain_check_dir/contact-fixture.swift" <<'SWIFT'
import MCPContactsAdapter
let forbidden = SyntheticContactTools.self
SWIFT
expect_rejection contact-fixture "cannot find 'SyntheticContactTools' in scope"
cat > "$domain_check_dir/contact-backend.swift" <<'SWIFT'
import AppleContactsProvider
let forbidden = NativeContactsBackend.self
SWIFT
expect_rejection contact-backend "cannot find 'NativeContactsBackend' in scope"
cat > "$domain_check_dir/contact-reader-write.swift" <<'SWIFT'
import CoreDomain
func invalid(_ source: any ContactReading, _ proposal: ProposedChange<ContactMutation>) async {
    _ = await source.apply(proposal)
}
SWIFT
expect_rejection contact-reader-write "has no member 'apply'"
cat > "$domain_check_dir/contact-approval.swift" <<'SWIFT'
import ActionApprovals
let forbidden = ContactApprovalEngine.self
SWIFT
expect_rejection contact-approval "cannot find 'ContactApprovalEngine' in scope"
cat > "$domain_check_dir/contact-confirmation.swift" <<'SWIFT'
import ActionApprovals
let forbidden = ContactConfirmation.self
SWIFT
expect_rejection contact-confirmation "cannot find 'ContactConfirmation' in scope"
cat > "$domain_check_dir/contact-action-fixture.swift" <<'SWIFT'
import ActionApprovals
let forbidden = SyntheticContactActionFixture.self
SWIFT
expect_rejection contact-action-fixture "cannot find 'SyntheticContactActionFixture' in scope"
cat > "$domain_check_dir/contact-writer.swift" <<'SWIFT'
import ContactMutations
let forbidden = JournaledContactProvider.self
SWIFT
expect_rejection contact-writer "cannot find 'JournaledContactProvider' in scope"
cat > "$domain_check_dir/contact-mutation-backend.swift" <<'SWIFT'
import ContactMutations
let forbidden = ContactsMutationBackend.self
SWIFT
expect_rejection contact-mutation-backend "cannot find 'ContactsMutationBackend' in scope"
cat > "$domain_check_dir/contact-mutation-adapter.swift" <<'SWIFT'
import MCPContactsAdapter
let forbidden = ContactMutationAdapter.self
SWIFT
expect_rejection contact-mutation-adapter "cannot find 'ContactMutationAdapter' in scope"
cat > "$domain_check_dir/contact-journal.swift" <<'SWIFT'
import SyncPersistence
let forbidden = ContactMutationJournal.self
SWIFT
expect_rejection contact-journal "cannot find 'ContactMutationJournal' in scope"
cat > "$domain_check_dir/native-write-composition.swift" <<'SWIFT'
import NativeSampleWrites
let forbidden = SampleWriteComposition.self
SWIFT
expect_rejection native-write-composition "cannot find 'SampleWriteComposition' in scope"
cat > "$domain_check_dir/native-broker.swift" <<'SWIFT'
import NativeMCPBridge
let broker = NativeReadBroker.self
SWIFT
cat > "$domain_check_dir/native-fixture.swift" <<'SWIFT'
import NativeMCPBridge
let session = SampleBridgeSession.self
SWIFT
expect_rejection native-broker "cannot find 'NativeReadBroker' in scope"
expect_rejection native-fixture "cannot find 'SampleBridgeSession' in scope"
cat > "$domain_check_dir/external-peer-policy.swift" <<'SWIFT'
import LocalBridgeTransport
let forbidden = PeerRequirement.self
SWIFT
cat > "$domain_check_dir/external-broker-fixture.swift" <<'SWIFT'
import NativeMCPBridge
let forbidden = ExternalSampleBroker.self
SWIFT
expect_rejection external-peer-policy "cannot find 'PeerRequirement' in scope"
expect_rejection external-broker-fixture "cannot find 'ExternalSampleBroker' in scope"
echo "Domain/policy/auth/persistence/planning/execution/background/onboarding/MCP boundaries passed: dependency/import guards, positive control, fifty-six expected rejections."
