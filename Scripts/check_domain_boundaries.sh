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
for path in Path("Sources/CoreDomain").rglob("*.swift"):
    imports = re.findall(
        r"^[ \t]*(?:@\w+[ \t]+)*(?:(?:public|internal|package|private|fileprivate)[ \t]+)?import[ \t]+"
        r"(?:(?:typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?([\w.]+)",
        path.read_text(), re.M,
    )
    if any(module != "Foundation" for module in imports):
        raise SystemExit("CoreDomain imports must remain Foundation-only")
PY

domain_check_dir=$(mktemp -d "${TMPDIR:-/tmp}/machandle-domain.XXXXXX")
trap 'rm -rf "$domain_check_dir"' EXIT
domain_product_dir="$(xcrun swift build --show-bin-path)"
domain_target="$(uname -m)-apple-macosx14.0"

cat > "$domain_check_dir/positive.swift" <<'SWIFT'
import CoreDomain
func read(_ source: any CalendarReading, _ request: CalendarReadRequest) async {
    _ = await source.readOccurrences(request)
}
func write(_ destination: any CalendarWriting, _ proposal: ProposedChange<CalendarMutation>) async {
    _ = await destination.apply(proposal)
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
echo "Domain boundaries passed: dependency/import guard, positive control, three expected rejections."
