# Privacy

MacHandle can request full Calendar permission only after you enable Calendar
discovery. macOS includes read/write authority in that grant. After selecting calendars,
a separate Read action retrieves bounded local availability, event titles, or event
details (title, location, notes), according to your chosen mode. Availability is the
default and hides details and identifiers. MacHandle does not change calendars,
access Reminders/Contacts/Notes, connect external services, transmit content or collect
analytics. Launch and navigation never request permission or load calendar metadata.

Google OAuth/Keychain code is merged, but the app has no configured
Google service and its Connect control is disabled. It does not open an OAuth browser,
listen for callbacks, send Google requests or access Keychain. Activation requires
maintainer setup and signed verification. The implemented credential adapter uses a
private, non-synchronized data-protection Keychain item; local disconnect and remote
grant revocation are separate actions. See [activation requirements](docs/development/google-auth-setup.md).

Work package 09 adds internal destination/event API primitives with synthetic tests.
They are not exposed to the app, connected to source data or running against Google.
Calendar privacy cannot be proven by a title, ownership marker or event visibility;
source transfer remains blocked. See [destination boundaries](docs/architecture/decisions/0014-google-destination-client.md).

The planned product will make each integration optional, show selected resources
and allowed operations, and explain what is shared with each destination. These
external-connection controls remain roadmap requirements. Calendar selection does not
authorize sharing. Names, selections, read results and preview history stay in memory. Changing access,
selection, read fields or dates clears displayed results; Clear Results does so explicitly.
Disabling discovery clears names/selections/results, and quit resets local opt-in. The OS grant is
managed separately in System Settings. Preview choices cannot grant actual access. Notes remains
subject to a separate feasibility and security decision.

Never upload real personal information, credentials, exports, or diagnostic logs
to this public repository. Use synthetic examples for issues and contributions.
See [the privacy model](docs/architecture/privacy-model.md) for planned consent and minimization.
This document must be updated alongside changes to actual data handling.
