# MacHandle
A privacy-first macOS app for connecting, managing, and syncing calendars, reminders, notes, and contacts across services. You control what's shared, accessed, or modified. Also supports AI agents.


> **Development status:** PR-01 foundation only. The description above is the product
> vision. No Apple service, Google sync, MCP, or AI integration is implemented.
> Notes support is experimental and subject to a future feasibility decision.

## Build and validate

For either Mac, follow [second-Mac setup and branch handoff](docs/development/setup.md).
Open `MacHandle.xcodeproj` in the baseline Xcode and select the shared `MacHandle` scheme.
For a credential-free command-line build and synthetic tests:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Full Xcode **27.1 (27A9275)**, bundled Swift **6.4**, and macOS SDK **27.0** are
required for the shared work/home/CI baseline in `Config/Toolchain.env`.
`DEVELOPER_DIR` can select its installed location per process. The provisional deployment target is macOS 14;
oldest-OS runtime compatibility will be assessed in PR-02. Unsigned validation
builds are not distribution artifacts. See [testing](docs/development/testing.md).

## Project documentation

- [Documentation index](docs/README.md) and [master implementation plan](plans/MacHandleMasterImplementationPlan.md)
- [Full product specification](docs/product/master-spec.md) and [31-PR roadmap](docs/implementation/pr-roadmap.md)
- [Implementation evidence](docs/implementation/progress.md) and [active PR / next action](docs/implementation/pr-coordination.md)
- [Implemented architecture](docs/architecture/overview.md)
- [Contributor instructions](CONTRIBUTING.md) and [agent instructions](AGENTS.md)
- [Security policy](SECURITY.md) and [privacy](PRIVACY.md)
- [Release policy](docs/releases.md)

The original repository and [Apache-2.0 license](LICENSE) are retained. Development
uses one focused PR at a time. The maintainer reviews and merges each PR before
the next milestone begins.
