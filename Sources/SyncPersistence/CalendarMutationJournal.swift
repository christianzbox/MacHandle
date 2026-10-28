import Foundation

package enum CalendarMutationState: String, Sendable {
    case pending, applied, notApplied, unknown
}
package struct CalendarMutationRecord: Equatable, Sendable {
    package let operation: UUID
    package let state: CalendarMutationState
}

/// Separate private directory/store from synchronization. Contains UUIDs and fixed states only.
/// Pending on reopen is uncertain, never permission to replay. No reset or pruning API exists.
package actor CalendarMutationJournal {
    private let database: SQLiteConnection
    private let installation: UUID
    private static let applicationID = "1296255562"
    private static let identitySQL =
        "CREATE TABLE identity (installation TEXT NOT NULL PRIMARY KEY) STRICT"
    private static let actionsSQL = """
        CREATE TABLE actions (operation TEXT NOT NULL PRIMARY KEY,
        state TEXT NOT NULL CHECK(state IN ('pending','applied','notApplied','unknown'))) STRICT
        """

    package init(directory: URL, installation: UUID, mode: PersistenceOpenMode) throws {
        let database = try SQLiteConnection(directory: directory, mode: mode)
        do {
            if mode == .createNew {
                try database.transaction {
                    try database.execute("PRAGMA application_id=\(Self.applicationID)")
                    try database.execute("PRAGMA user_version=1")
                    try database.execute(Self.identitySQL)
                    try database.execute(
                        "INSERT INTO identity VALUES (?)", [installation.uuidString])
                    try database.execute(Self.actionsSQL)
                }
            }
            try Self.validate(database, installation: installation)
        } catch {
            database.close()
            throw error
        }
        self.database = database
        self.installation = installation
    }
    private static func validate(_ database: SQLiteConnection, installation: UUID) throws {
        guard try database.query("PRAGMA application_id") == [[applicationID]],
            try database.query("PRAGMA user_version") == [["1"]],
            try database.query("PRAGMA quick_check") == [["ok"]],
            try database.query(
                "SELECT name,sql FROM sqlite_schema WHERE sql IS NOT NULL ORDER BY name")
                == [["actions", actionsSQL], ["identity", identitySQL]],
            try database.query("SELECT installation FROM identity") == [[installation.uuidString]]
        else { throw PersistenceFailure.identityMismatch }
    }
    package func records() throws -> [CalendarMutationRecord] {
        try Self.validate(database, installation: installation)
        return try database.query("SELECT operation,state FROM actions ORDER BY operation").map {
            row in
            guard let raw = row[0], let id = UUID(uuidString: raw), id.uuidString == raw,
                let value = row[1], let state = CalendarMutationState(rawValue: value)
            else { throw PersistenceFailure.corrupt }
            return CalendarMutationRecord(operation: id, state: state)
        }
    }
    package func requireReady() throws {
        guard try !records().contains(where: { $0.state == .pending || $0.state == .unknown })
        else {
            throw PersistenceFailure.stateConflict
        }
    }
    package func begin(_ operation: UUID) throws {
        try database.transaction {
            let current = try records()
            guard current.count < 4096 else { throw PersistenceFailure.limitExceeded }
            guard
                !current.contains(where: {
                    $0.operation == operation || $0.state == .pending || $0.state == .unknown
                })
            else { throw PersistenceFailure.stateConflict }
            try database.execute(
                "INSERT INTO actions VALUES (?, 'pending')", [operation.uuidString])
        }
    }
    package func finish(_ operation: UUID, state: CalendarMutationState) throws {
        guard state != .pending else { throw PersistenceFailure.invalidInput }
        try database.transaction {
            guard try records().first(where: { $0.operation == operation })?.state == .pending
            else {
                throw PersistenceFailure.stateConflict
            }
            try database.execute(
                "UPDATE actions SET state=? WHERE operation=?",
                [state.rawValue, operation.uuidString])
        }
    }
    package func close() { database.close() }
}
