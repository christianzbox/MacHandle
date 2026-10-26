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
domain = next(target for target in package["targets"] if target["name"] == "CoreDomain")
if domain["dependencies"]:
    raise SystemExit("CoreDomain must not depend on infrastructure targets or packages")
policy = next(target for target in package["targets"] if target["name"] == "PermissionEngine")
if policy["dependencies"] != [{"byName": ["CoreDomain", None]}]:
    raise SystemExit("PermissionEngine must depend only on CoreDomain")
application = next(target for target in package["targets"] if target["name"] == "MacHandleApplication")
if application["dependencies"] != [{"byName": ["CoreDomain", None]}, {"byName": ["PermissionEngine", None]}]:
    raise SystemExit("Application must depend on contracts/policy, never the EventKit provider")
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
echo "Domain/policy boundaries passed: dependency/import guards, positive control, eight expected rejections."
