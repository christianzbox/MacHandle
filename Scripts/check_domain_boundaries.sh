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
if mcp["dependencies"] or helper["dependencies"] != [{"byName": ["MCPServer", None]}]:
    raise SystemExit("Synthetic MCP must not depend on providers, credentials, policy or UI")
for path in list(Path("Sources/MCPServer").rglob("*.swift")) + list(Path("Sources/MacHandleMCP").rglob("*.swift")):
    imports = re.findall(r"^import (\w+)", path.read_text(), re.M)
    if any(module not in {"Foundation", "Dispatch", "Darwin", "MCPServer"} for module in imports):
        raise SystemExit("MCP must remain a separate synthetic transport/adapter")
domain = next(target for target in package["targets"] if target["name"] == "CoreDomain")
if domain["dependencies"]:
    raise SystemExit("CoreDomain must not depend on infrastructure targets or packages")
policy = next(target for target in package["targets"] if target["name"] == "PermissionEngine")
if policy["dependencies"] != [{"byName": ["CoreDomain", None]}]:
    raise SystemExit("PermissionEngine must depend only on CoreDomain")
application = next(target for target in package["targets"] if target["name"] == "MacHandleApplication")
if application["dependencies"] != [{"byName": ["CoreDomain", None]}, {"byName": ["PermissionEngine", None]}]:
    raise SystemExit("Application must depend on contracts/policy, never the EventKit provider")
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
        raise SystemExit("EventKit must remain inside AppleCalendarProvider")
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
echo "Domain/policy/auth/persistence/planning/execution/background/onboarding/MCP boundaries passed: dependency/import guards, positive control, twenty expected rejections."
