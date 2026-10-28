import Foundation

enum PersistenceSchema {
    static let applicationID = "1296581708"
    static let currentVersion = 3
    static let first = [
        "CREATE TABLE identity (singleton INTEGER PRIMARY KEY CHECK(singleton=1), store_id TEXT NOT NULL, installation_id TEXT NOT NULL, client_id TEXT NOT NULL, account_key TEXT NOT NULL) STRICT",
        "CREATE TABLE resources (id TEXT PRIMARY KEY NOT NULL, source_key TEXT UNIQUE NOT NULL, destination_id TEXT UNIQUE, marker TEXT UNIQUE NOT NULL) STRICT",
        "CREATE TABLE events (id TEXT PRIMARY KEY NOT NULL, resource_id TEXT NOT NULL REFERENCES resources(id), source_key TEXT NOT NULL, remote_id TEXT NOT NULL, fingerprint TEXT, etag TEXT, deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1)), UNIQUE(resource_id,source_key), UNIQUE(resource_id,remote_id), UNIQUE(id,resource_id)) STRICT",
    ]
    static let second = [
        "CREATE TABLE sync_state (singleton INTEGER PRIMARY KEY CHECK(singleton=1), status TEXT NOT NULL CHECK(status IN ('paused','recoveryRequired'))) STRICT",
        "CREATE TABLE operations (id TEXT PRIMARY KEY NOT NULL, resource_id TEXT NOT NULL REFERENCES resources(id), event_id TEXT, kind TEXT NOT NULL CHECK(kind IN ('createDestination','insertEvent','updateEvent','deleteEvent')), state TEXT NOT NULL CHECK(state IN ('prepared','unknown','completed')), expected_etag TEXT, fingerprint TEXT, FOREIGN KEY(event_id,resource_id) REFERENCES events(id,resource_id), CHECK((kind='createDestination' AND event_id IS NULL AND fingerprint IS NULL AND expected_etag IS NULL) OR (kind='insertEvent' AND event_id IS NOT NULL AND fingerprint IS NOT NULL AND expected_etag IS NULL) OR (kind='updateEvent' AND event_id IS NOT NULL AND fingerprint IS NOT NULL AND expected_etag IS NOT NULL) OR (kind='deleteEvent' AND event_id IS NOT NULL AND fingerprint IS NULL AND expected_etag IS NOT NULL))) STRICT",
        "CREATE UNIQUE INDEX pending_event ON operations(event_id) WHERE state!='completed'",
        "CREATE UNIQUE INDEX destination_creation ON operations(resource_id) WHERE kind='createDestination'",
        "CREATE TABLE checkpoint (singleton INTEGER PRIMARY KEY CHECK(singleton=1), revision INTEGER NOT NULL CHECK(revision>=0), completed_run TEXT) STRICT",
    ]
    static let third = [
        "CREATE TABLE sync_preferences (singleton INTEGER PRIMARY KEY CHECK(singleton=1), sources TEXT NOT NULL, field_mask INTEGER NOT NULL CHECK(field_mask BETWEEN 0 AND 7)) STRICT"
    ]
    static func initialize(
        _ db: SQLiteConnection, binding: PersistenceBinding, mode: PersistenceOpenMode
    ) throws {
        guard try db.query("PRAGMA integrity_check") == [["ok"]] else {
            throw PersistenceFailure.corrupt
        }
        let versions = try db.query("PRAGMA user_version")
        guard versions.count == 1, let raw = versions[0][0], let version = Int(raw) else {
            throw PersistenceFailure.corrupt
        }
        if mode == .createNew {
            guard version == 0, try db.query("SELECT name FROM sqlite_master").isEmpty else {
                throw PersistenceFailure.corrupt
            }
            try db.transaction {
                for sql in first { try db.execute(sql) }
                try db.execute(
                    "INSERT INTO identity VALUES(1,?,?,?,?)",
                    [
                        binding.storeID.uuidString, binding.installationID.uuidString,
                        binding.clientID, binding.accountKey.value,
                    ])
                try db.execute("PRAGMA application_id=\(applicationID)")
                try db.execute("PRAGMA user_version=1")
            }
        } else {
            guard (1...currentVersion).contains(version) else {
                throw PersistenceFailure.incompatibleSchema
            }
            guard try db.query("PRAGMA application_id") == [[applicationID]] else {
                throw PersistenceFailure.incompatibleSchema
            }
            try validateManifest(db, version: version)
            try validateIdentity(db, binding: binding)
        }
        if mode == .createNew || version == 1 {
            try db.transaction {
                for sql in second { try db.execute(sql) }
                try db.execute("INSERT INTO checkpoint VALUES(1,0,NULL)")
                try db.execute("INSERT INTO sync_state VALUES(1,'paused')")
                try db.execute("PRAGMA user_version=2")
            }
        }
        if mode == .createNew || version < 3 {
            try db.transaction {
                for sql in third { try db.execute(sql) }
                try db.execute("PRAGMA user_version=3")
            }
        }
        try validateManifest(db, version: currentVersion)
        try validateIdentity(db, binding: binding)
        guard try db.query("PRAGMA foreign_key_check").isEmpty else {
            throw PersistenceFailure.corrupt
        }
    }
    static func validateIdentity(_ db: SQLiteConnection, binding: PersistenceBinding) throws {
        guard
            try db.query(
                "SELECT store_id,installation_id,client_id,account_key FROM identity WHERE singleton=1"
            ) == [
                [
                    binding.storeID.uuidString, binding.installationID.uuidString, binding.clientID,
                    binding.accountKey.value,
                ]
            ]
        else { throw PersistenceFailure.identityMismatch }
    }
    private static func validateManifest(_ db: SQLiteConnection, version: Int) throws {
        let sql = try db.query(
            "SELECT sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name")
        func normalized(_ value: String) -> String {
            value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }
        let actual = sql.compactMap { $0.first ?? nil }.map(normalized).sorted()
        let expected = (first + (version >= 2 ? second : []) + (version >= 3 ? third : [])).map(
            normalized
        ).sorted()
        guard actual == expected else {
            throw PersistenceFailure.corrupt
        }
    }
}
