# Notes feasibility evidence and isolated acceptance

Work package 26. Decision: [ADR-0031](../architecture/decisions/0031-notes-feasibility.md).
This is a documentation/public-terminology review, not a working Notes connector or a sandboxed
proof of concept. No personal note, account inventory, attachment or private database was read.
No Notes/Shortcuts operation or Automation prompt was initiated. Repository tests use synthetic data.

## Static evidence snapshot

Inspected on 2026-10-29: macOS 27.2 (26B123), Notes 4.13 (3195.42.3).
This host is not evidence for the deployment floor of macOS 14 or another Mac.

| Public file | SHA-256 |
| --- | --- |
| `/System/Applications/Notes.app/Contents/Resources/Notes.sdef` | `2485c3e87dbfa0baf09fcfa6d2f6b2c16e4eccc1371db01a2ab8c3d35ef4e65d` |
| `/System/Library/ScriptingDefinitions/CocoaStandard.sdef` | `11935d4a6ebabc75a45e79d7d3830c47701474b0f34d92937fa32c6eb6a22fcd` |

Only the shipped scripting terminology and public bundle version metadata were inspected. No
implementation classes or hidden attachment storage are used. The local suite imports Standard
terminology: `make`, `delete`, `duplicate`, `move`, `count`, `exists` and `save` are present there.
It would be incorrect to infer CRUD absence from Notes' two local commands alone. Inherited generic
commands likewise do not prove that every Notes object supports their effects.

The local suite's named access group is `com.apple.Notes.openlocation`; eight inherited generic
commands carry `*` access-group annotations. Signed enforcement and resource access remain untested.
The dictionary identifies attachment metadata and a `save` response; its hidden file contents
declaration suggests attachment creation but is not a stable export/import/fidelity promise.

Read-only reproduction, from any checkout (no Apple events, app launch, user inventory or network):

```sh
python3 - <<'PY'
from pathlib import Path
import hashlib
import plistlib
import xml.etree.ElementTree as ET

bundle = Path('/System/Applications/Notes.app/Contents')
info = plistlib.loads((bundle / 'Info.plist').read_bytes())
print('Notes', info['CFBundleShortVersionString'], info['CFBundleVersion'])
for path in (
    bundle / 'Resources/Notes.sdef',
    Path('/System/Library/ScriptingDefinitions/CocoaStandard.sdef'),
):
    data = path.read_bytes()
    root = ET.fromstring(data)  # Does not expand XInclude or execute scripting commands.
    print(path.name, hashlib.sha256(data).hexdigest())
    print('commands:', [node.get('name') for node in root.findall('.//command')])
    print('groups:', [node.get('identifier') for node in root.findall('.//access-group')])
PY
```

A missing or changed dictionary is a new unresolved observation, not a reason to inspect a user
container. Keep evidence to versions, hashes, capability names and outcomes; do not commit the
dictionary, Apple source, private content or raw provider logs.

## Capability matrix

“Declared” means public terminology observed, not runtime-supported by MacHandle. **No live Notes
capability is verified.** All unresolved rows are deferred from activation; engineering owns the
proof, with maintainer-provided isolated setup. Triggers refer to the protocol below.

| Capability | Current evidence / verdict | Required proof or exclusion |
| --- | --- | --- |
| Account/folder discovery | IDs, names, containers and collections declared; runtime unresolved | G1–G3: bounded discovery, no body fetch, selected account/folder containment, duplicate names and denied/partial results |
| Note title/plain-text read | `name`, read-only `plaintext` and writable HTML `body` declared; runtime unresolved | G2–G4: selected fields, parent continuity, size limits, no hidden-field search leakage |
| Search | Collection/property surface is only a candidate; no completeness guarantee established | G3–G4: authorized-field matching, bounded results and explicit incomplete/offline outcomes; no global content index |
| Identity and moves | Read-only IDs described as unique; persistence across moves/accounts/devices/restores unproven | G3: exact local continuity, delete/recreate and account replacement; ambiguous identity invalidates selection |
| Locked/shared notes | Read-only password-protected/shared flags declared | G2–G4: prove safe exclusion before content access, inherited shared-folder effects and no unlock prompt; otherwise defer the whole affected read path |
| Rich content/checklists/tables | HTML/plain-text surface declared; round-trip preservation unproven | G4/G5: retain structure, formatting, checklist state and embedded objects; no flatten-and-replace fallback |
| Attachments/scans/drawings | Attachment metadata, hidden file-content terminology and save response present | G4/G5: no implicit downloads, file/path execution or remote URL fetch; export/import/fidelity and review scope unproven; excluded initially |
| Create | Inherited `make` and object properties declared | G5: exact selected destination, supported body subset, durable intent and uncertain-create reconciliation without duplicate retry |
| Update | Writable HTML body/name declared | G5: exact target, lossless allowed subset and concurrency proof; no expected-version operation identified in examined terminology |
| Delete/move | Inherited Standard commands declared | G5: exact affected objects, shared/attachment effects, heightened approval and unknown recovery; collection-wide operations excluded |
| App Sandbox/Automation | Official mechanisms and terminology exist; actual entitlement/consent behavior unresolved | G1/G2: signed sandboxed proof and separate OS/native/connection consent; no exceptions or permission prompts added now |
| Shortcuts/user scripts | Public execution interfaces documented in ADR; no installed actions or user scripts inspected | Separate security review before any alternative prototype; mutable scripts and broader authority cannot inherit connector trust |
| App Store/direct distribution | No signed/notarized/reviewed Notes build | G6: chosen route's real acceptance; neither documentation, notarization nor local tests predict App Review approval |
| Private database/framework access | Prohibited by product architecture | No implementation/revisit through a bypass; only a separately reviewed supported public interface can change the decision |

## Isolated runtime gate

**Deferred, not run.** Owner: engineering, with maintainer setup/authorization. Trigger: an explicitly
authorized throwaway macOS user or machine with no personal Apple account/data, approved test signing
identity, and an agreed synthetic-only experiment. Cloud-specific tests additionally need a dedicated
test Apple account; local “On My Mac” fixtures cannot prove iCloud behavior. Creating accounts,
changing sync settings or resetting permissions in the current personal profile is outside this gate.
See [account/setup guidance](google-auth-setup.md) for existing project setup; do not send secrets in chat.

1. **G1 — Signed harness.** In a separate future review PR, build a minimal sandboxed native harness
   using fixed public operations. Record source SHA, signing mode, OS/Notes versions and exact
   entitlements. Keep normal MacHandle Notes composition closed. Verify baseline launch sends no
   events; choose the narrowest supported target authorization and review any exception explicitly.
2. **G2 — Consent and denial.** A local opt-in explains Notes Automation before the first event.
   Exercise allow, deny, revoke, relaunch, cancellation and late response. Verify no background prompt,
   no unlocked content on lock exclusion, and no content delivery after policy/permission changes.
   Any reset occurs only in the disposable environment, never the personal profile.
3. **G3 — Selection/identity.** Create synthetic allowed/excluded folders, duplicate titles and IDs
   observed solely in the disposable environment. Test parent moves, deletion/recreation, replacement,
   partial enumeration, offline/stale state and a second test device only when authorized. Export
   no real IDs. Prove exclusion before content retrieval and invalidate uncertain bindings.
4. **G4 — Read fidelity/privacy.** Exercise plain text, Unicode, multiline titles, HTML-like text,
   malicious instruction strings, links, locked/shared notes, checklists/tables and attachments.
   Compare selected fields only; test hidden-field search, output bounds and sanitized errors.
   Unsupported content remains explicitly excluded. Passing read tests grants no write authority.
5. **G5 — Separately authorized mutations.** Only disposable fixtures and exact local confirmations.
   Compare before/after native rendering and structured content, including excluded fields and
   attachments. Inject simultaneous native edits, moves, revoke-before-dispatch, timeout, crash and
   lost acknowledgement. Require durable uncertainty containment and no retry duplicates; document
   any remaining compare-then-write race. Defer each operation whose semantics cannot be enforced.
6. **G6 — Compatibility/distribution.** Repeat applicable cases on the deployment floor/current OS
   and both intended Macs. Separately establish the selected signed distribution route, notarization
   and any App Store review requirements. Record content-free results in a reviewed ADR amendment.

Only a reviewed amendment with per-capability evidence can open a narrow integration scope. A passing
read-only subset can precede writes; failure of a write gate need not eliminate a proven read subset.
The experiment is not part of normal CI, and no test runner may silently create real Notes fixtures.
