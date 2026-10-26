# Privacy

MacHandle can request full Calendar permission only after you enable Calendar
discovery. macOS includes read/write authority in that grant. After selecting calendars,
a separate Read action retrieves bounded local availability, event titles, or event
details (title, location, notes), according to your chosen mode. Availability is the
default and hides details and identifiers. MacHandle does not change calendars,
access Reminders/Contacts/Notes, connect external services, transmit content or collect
analytics. Launch and navigation never request permission or load calendar metadata.

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
