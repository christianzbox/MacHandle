# MacHandle
A privacy-first macOS app for connecting, managing, and syncing calendars, reminders, notes, and contacts across services. You control what's shared, accessed, or modified. Also supports AI agents.


> **Development status:** PR-01 foundation only. The description above is the product
> vision. No Apple service, Google sync, MCP, or AI integration is implemented.
> Notes support is experimental and subject to a future feasibility decision.

## Build and validate

Open `MacHandle.xcodeproj` in Xcode and select the shared `MacHandle` scheme.
For a credential-free command-line build and synthetic tests:

```sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Full Xcode is required. CI uses Xcode 26.6; `DEVELOPER_DIR` can select a different
installed Xcode per process. The provisional deployment target is macOS 14;
oldest-OS runtime compatibility will be assessed in PR-02. Unsigned validation
builds are not distribution artifacts. See [testing](Docs/TESTING.md).

## Project documentation

- [Current state and next step](Docs/CURRENT_STATE.md)
- [Master specification](Docs/MASTER_SPEC.md) and [31-PR roadmap](Docs/PR_PLAN.md)
- [Implemented architecture](Docs/ARCHITECTURE.md)
- [Contributor instructions](CONTRIBUTING.md) and [agent instructions](AGENTS.md)
- [Security policy](SECURITY.md) and [privacy](PRIVACY.md)
- [Release policy](Docs/RELEASES.md)

The original repository and [Apache-2.0 license](LICENSE) are retained. Development
uses one focused PR at a time. The maintainer reviews and merges each PR before
the next milestone begins.
