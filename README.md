# MacHandle
A privacy-first macOS app for connecting, managing, and syncing calendars, reminders, notes, and contacts across services. You control what's shared, accessed, or modified. Also supports AI agents.


> **Development status:** native foundation, design decisions and core domain models
> and permission policy engine are merged, including the native application interface.
> Work packages 07–09 Calendar reads, Google OAuth/Keychain and internal destination
> operations are merged. Work package 10 adds versioned SQLite persistence for review;
> the app does not open a database or activate synchronization.
> Live Google sign-in and source transfer remain disabled pending setup, signed checks
> and destination privacy acceptance. Live EventKit/TCC behavior remains unverified.
> No Apple writes, working Google sync, MCP or AI integration is implemented. The description above is the product vision.
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
`DEVELOPER_DIR` can select its installed location per process. The implementation target is macOS 14;
oldest-OS runtime compatibility remains a provider/release verification gate. Unsigned validation
builds are not distribution artifacts. See [testing](docs/development/testing.md).

## Project documentation

- [Documentation index](docs/README.md) and [master implementation plan](plans/MacHandleMasterImplementationPlan.md)
- [Full product specification](docs/product/master-spec.md) and [31-PR roadmap](docs/implementation/pr-roadmap.md)
- [Work-package / GitHub PR mapping](docs/implementation/pr-roadmap.md#work-packages-and-github-prs)
- [Implementation evidence](docs/implementation/progress.md) and [active PR / next action](docs/implementation/pr-coordination.md)
- [Implemented architecture](docs/architecture/overview.md)
- [Contributor instructions](CONTRIBUTING.md) and [agent instructions](AGENTS.md)
- [Security policy](SECURITY.md) and [privacy](PRIVACY.md)
- [Developer accounts, keys, permissions and activation](docs/development/google-auth-setup.md)
- [Release policy](docs/releases.md)

The original repository and [Apache-2.0 license](LICENSE) are retained. Development
uses one focused PR at a time. The maintainer reviews and merges each PR before
the next milestone begins.
