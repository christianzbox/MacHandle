import Darwin
import Foundation
import SQLite3

/// Owned by one actor; synchronous transactions never suspend. Sendable only for actor initialization/deinit.
final class SQLiteConnection: @unchecked Sendable {
    private var handle: OpaquePointer?
    private var descriptor: Int32 = -1
    private var lockDescriptor: Int32 = -1
    private var lockInode: ino_t = 0
    private let file: URL
    private var inode: ino_t = 0
    private var device: dev_t = 0
    private var failed = false
    var beforeCommit: (() throws -> Void)?

    init(directory: URL, mode: PersistenceOpenMode) throws {
        guard directory.isFileURL,
            directory.path == directory.standardizedFileURL.resolvingSymlinksInPath().path
        else {
            throw PersistenceFailure.unsafeLocation
        }

        var directoryInfo = stat()
        if lstat(directory.path, &directoryInfo) != 0 {
            guard mode == .createNew, errno == ENOENT,
                mkdir(directory.path, 0o700) == 0
            else { throw PersistenceFailure.missingStore }
        }
        guard lstat(directory.path, &directoryInfo) == 0,
            directoryInfo.st_mode & S_IFMT == S_IFDIR, directoryInfo.st_uid == geteuid(),
            directoryInfo.st_mode & 0o077 == 0
        else { throw PersistenceFailure.unsafeLocation }
        guard let resolved = realpath(directory.path, nil) else {
            throw PersistenceFailure.unsafeLocation
        }
        let canonicalDirectory = String(cString: resolved)
        free(resolved)
        file = URL(fileURLWithPath: canonicalDirectory, isDirectory: true).appendingPathComponent(
            "state.sqlite")
        try Self.checkSidecars(file)
        if mode == .createNew {
            var priorLock = stat()
            if lstat(
                file.deletingLastPathComponent().appendingPathComponent("writer.lock").path,
                &priorLock) == 0
            {
                throw PersistenceFailure.alreadyExists
            }
            guard errno == ENOENT else { throw PersistenceFailure.unsafeLocation }
        }
        let flags = O_RDWR | O_NOFOLLOW | O_CLOEXEC | (mode == .createNew ? O_CREAT | O_EXCL : 0)
        descriptor = Darwin.open(file.path, flags, 0o600)
        guard descriptor >= 0 else {
            if errno == EEXIST { throw PersistenceFailure.alreadyExists }
            if errno == ENOENT { throw PersistenceFailure.missingStore }
            throw PersistenceFailure.unsafeLocation
        }
        do {
            var info = stat()
            guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
                info.st_uid == geteuid(), info.st_mode & 0o077 == 0, info.st_nlink == 1,
                info.st_size <= 134_217_728
            else { throw PersistenceFailure.unsafeLocation }
            inode = info.st_ino
            device = info.st_dev
            lockDescriptor = Darwin.open(
                file.deletingLastPathComponent().appendingPathComponent("writer.lock").path,
                O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
            var lockInfo = stat()
            guard lockDescriptor >= 0, fstat(lockDescriptor, &lockInfo) == 0,
                lockInfo.st_mode & S_IFMT == S_IFREG, lockInfo.st_uid == geteuid(),
                lockInfo.st_mode & 0o077 == 0, lockInfo.st_nlink == 1
            else { throw PersistenceFailure.unsafeLocation }
            lockInode = lockInfo.st_ino
            guard flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 else {
                throw PersistenceFailure.busy
            }
            guard mode == .createNew || info.st_size > 0 else { throw PersistenceFailure.corrupt }
            let result = sqlite3_open_v2(
                file.path, &handle,
                SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW, nil)
            guard result == SQLITE_OK else { throw PersistenceFailure.unavailable }
            sqlite3_busy_timeout(handle, 1000)
            sqlite3_limit(handle, SQLITE_LIMIT_LENGTH, 1_048_576)
            sqlite3_limit(handle, SQLITE_LIMIT_SQL_LENGTH, 65_536)
            try checkFile()
            try execute("PRAGMA foreign_keys=ON")
            try execute("PRAGMA trusted_schema=OFF")
            try execute("PRAGMA synchronous=FULL")
            try execute("PRAGMA fullfsync=ON")
            try execute("PRAGMA secure_delete=ON")
            guard try query("PRAGMA journal_mode") == [["delete"]],
                try query("PRAGMA foreign_keys") == [["1"]],
                try query("PRAGMA synchronous") == [["2"]],
                try query("PRAGMA fullfsync") == [["1"]],
                try query("PRAGMA trusted_schema") == [["0"]]
            else { throw PersistenceFailure.incompatibleSchema }
        } catch {
            close()
            throw error
        }
    }
    deinit { close() }
    func close() {
        if let handle {
            sqlite3_close_v2(handle)
            self.handle = nil
        }
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
        if lockDescriptor >= 0 {
            flock(lockDescriptor, LOCK_UN)
            Darwin.close(lockDescriptor)
            lockDescriptor = -1
        }
    }
    func checkFile() throws {
        guard handle != nil else { throw PersistenceFailure.closed }
        guard !failed else { throw PersistenceFailure.unavailable }
        var directoryInfo = stat()
        guard lstat(file.deletingLastPathComponent().path, &directoryInfo) == 0,
            directoryInfo.st_mode & S_IFMT == S_IFDIR, directoryInfo.st_uid == geteuid(),
            directoryInfo.st_mode & 0o077 == 0
        else {
            failed = true
            throw PersistenceFailure.unsafeLocation
        }
        var info = stat()
        guard lstat(file.path, &info) == 0 else {
            failed = true
            throw PersistenceFailure.missingStore
        }
        guard info.st_ino == inode, info.st_dev == device, info.st_mode & S_IFMT == S_IFREG,
            info.st_uid == geteuid(), info.st_nlink == 1, info.st_mode & 0o077 == 0,
            info.st_size <= 134_217_728
        else {
            failed = true
            throw PersistenceFailure.unsafeLocation
        }
        var lockInfo = stat()
        guard
            lstat(
                file.deletingLastPathComponent().appendingPathComponent("writer.lock").path,
                &lockInfo) == 0,
            lockInfo.st_ino == lockInode, lockInfo.st_dev == device, lockInfo.st_nlink == 1,
            lockInfo.st_mode & S_IFMT == S_IFREG, lockInfo.st_uid == geteuid(),
            lockInfo.st_mode & 0o077 == 0
        else {
            failed = true
            throw PersistenceFailure.unsafeLocation
        }
        do { try Self.checkSidecars(file) } catch {
            failed = true
            throw error
        }
    }
    private static func checkSidecars(_ file: URL) throws {
        for suffix in ["-journal", "-wal", "-shm"] {
            var info = stat()
            if lstat(file.path + suffix, &info) == 0 {
                guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == geteuid(),
                    info.st_mode & 0o077 == 0, info.st_nlink == 1
                else { throw PersistenceFailure.unsafeLocation }
            } else if errno != ENOENT {
                throw PersistenceFailure.unsafeLocation
            }
        }
    }
    func execute(_ sql: String, _ values: [String?] = []) throws {
        _ = try query(sql, values)
    }
    func query(_ sql: String, _ values: [String?] = []) throws -> [[String?]] {
        try checkFile()
        var statement: OpaquePointer?
        try check(sqlite3_prepare_v2(handle, sql, -1, &statement, nil))
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_parameter_count(statement) == Int32(values.count) else {
            throw PersistenceFailure.invalidInput
        }
        for (offset, value) in values.enumerated() {
            if let value {
                guard !value.utf8.contains(0) else { throw PersistenceFailure.invalidInput }
                let result = value.withCString {
                    sqlite3_bind_text(
                        statement, Int32(offset + 1), $0, -1,
                        unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
                try check(result)
            } else {
                try check(sqlite3_bind_null(statement, Int32(offset + 1)))
            }
        }
        var rows: [[String?]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return rows }
            guard result == SQLITE_ROW else {
                try check(result)
                throw PersistenceFailure.corrupt
            }
            guard rows.count < 10_000 else { throw PersistenceFailure.limitExceeded }
            rows.append(
                try (0..<sqlite3_column_count(statement)).map { index in
                    if sqlite3_column_type(statement, index) == SQLITE_NULL { return nil }
                    guard let text = sqlite3_column_text(statement, index),
                        let value = String(
                            bytes: UnsafeBufferPointer(
                                start: text, count: Int(sqlite3_column_bytes(statement, index))),
                            encoding: .utf8)
                    else { throw PersistenceFailure.corrupt }
                    return value
                })
        }
    }
    func transaction<T>(_ action: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let value = try action()
            try beforeCommit?()
            try execute("COMMIT")
            return value
        } catch {
            if sqlite3_exec(handle, "ROLLBACK", nil, nil, nil) != SQLITE_OK { failed = true }
            throw error
        }
    }
    private func check(_ code: Int32) throws {
        switch code & 0xff {
        case SQLITE_OK: return
        case SQLITE_BUSY, SQLITE_LOCKED: throw PersistenceFailure.busy
        case SQLITE_CONSTRAINT: throw PersistenceFailure.constraint
        case SQLITE_CORRUPT, SQLITE_NOTADB:
            failed = true
            throw PersistenceFailure.corrupt
        default:
            failed = true
            throw PersistenceFailure.unavailable
        }
    }
}
