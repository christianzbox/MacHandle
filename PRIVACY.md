# Privacy

MacHandle can request full Calendar permission only after you enable Calendar
discovery. macOS includes read/write authority in that grant; this version only lists
local account/calendar names for selection. It does not read events, change calendars,
access Reminders/Contacts/Notes, connect external services, transmit content or collect
analytics. Launch and navigation never request permission or load calendar metadata.

The planned product will make each integration optional, show selected resources
and allowed operations, and explain what is shared with each destination. These
external-connection controls remain roadmap requirements. Calendar selection does not
authorize sharing. Names, selections and preview history stay in memory; disabling
discovery clears its names/selections, and quit resets local opt-in. The OS grant is
managed separately in System Settings. Preview choices cannot grant actual access. Notes remains
subject to a separate feasibility and security decision.

Never upload real personal information, credentials, exports, or diagnostic logs
to this public repository. Use synthetic examples for issues and contributions.
See [the privacy model](docs/architecture/privacy-model.md) for planned consent and minimization.
This document must be updated alongside changes to actual data handling.
