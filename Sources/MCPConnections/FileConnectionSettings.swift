import Darwin
import Foundation

/// Small non-secret permission document. Dedicated private directory, exclusive writer and atomic replacement.
/// No default path; app/container composition and signed runtime remain gated.
package final class FileConnectionSettings: ConnectionSettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private let directory: URL
    private var directoryFD: Int32 = -1
    private var lockFD: Int32 = -1
    private var directoryInode: ino_t = 0
    private var lockInode: ino_t = 0
    private var device: dev_t = 0
    private let filename = "connections.json"
    package init(directory: URL, create: Bool) throws {
        self.directory = directory
        guard directory.isFileURL,
            directory.path == directory.standardizedFileURL.resolvingSymlinksInPath().path
        else { throw ConnectionFailure.storage }
        var info = stat()
        if lstat(directory.path, &info) != 0 {
            guard create, errno == ENOENT, mkdir(directory.path, 0o700) == 0 else {
                throw ConnectionFailure.storage
            }
        }
        directoryFD = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directoryFD >= 0 else { throw ConnectionFailure.storage }
        do {
            guard fstat(directoryFD, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
                info.st_uid == geteuid(), info.st_mode & 0o077 == 0
            else { throw ConnectionFailure.storage }
            directoryInode = info.st_ino
            device = info.st_dev
            lockFD = openat(
                directoryFD, "writer.lock",
                O_RDWR | O_NOFOLLOW | O_CLOEXEC | (create ? O_CREAT | O_EXCL : 0), 0o600)
            guard lockFD >= 0 else { throw ConnectionFailure.storage }
            let lockInfo = try regular(lockFD)
            lockInode = lockInfo.st_ino
            guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw ConnectionFailure.busy }
            if create {
                guard fstatat(directoryFD, filename, &info, AT_SYMLINK_NOFOLLOW) != 0,
                    errno == ENOENT
                else { throw ConnectionFailure.storage }
                try write(try SettingsEnvelope.encode([]), initial: true)
            }
            _ = try read()
        } catch {
            close()
            throw ConnectionFailure.storage
        }
    }
    deinit { close() }
    private func close() {
        if lockFD >= 0 {
            flock(lockFD, LOCK_UN)
            Darwin.close(lockFD)
            lockFD = -1
        }
        if directoryFD >= 0 {
            Darwin.close(directoryFD)
            directoryFD = -1
        }
    }
    private func regular(_ fd: Int32) throws -> stat {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
            info.st_uid == geteuid(), info.st_nlink == 1, info.st_mode & 0o077 == 0,
            info.st_size <= 262_144
        else { throw ConnectionFailure.storage }
        return info
    }
    private func checkDirectory() throws {
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
            info.st_ino == directoryInode, info.st_dev == device,
            info.st_uid == geteuid(), info.st_mode & 0o077 == 0,
            fstatat(directoryFD, "writer.lock", &info, AT_SYMLINK_NOFOLLOW) == 0,
            info.st_ino == lockInode, info.st_dev == device, info.st_nlink == 1,
            info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o077 == 0, info.st_uid == geteuid()
        else { throw ConnectionFailure.storage }
    }
    private func read() throws -> [SavedConnection] {
        try checkDirectory()
        let fd = openat(directoryFD, filename, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw ConnectionFailure.storage }
        defer { Darwin.close(fd) }
        let info = try regular(fd)
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw ConnectionFailure.storage }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
            guard data.count <= 262_144 else { throw ConnectionFailure.storage }
        }
        var current = stat()
        guard fstatat(directoryFD, filename, &current, AT_SYMLINK_NOFOLLOW) == 0,
            current.st_ino == info.st_ino, current.st_dev == info.st_dev
        else { throw ConnectionFailure.storage }
        try checkDirectory()
        return try SettingsEnvelope.decode(data)
    }
    private func write(_ data: Data, initial: Bool = false) throws {
        try checkDirectory()
        if !initial { _ = try read() }  // Do not overwrite corrupt/missing/unsafe state silently.
        let temporary = ".pending-" + UUID().uuidString
        let fd = openat(
            directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ConnectionFailure.storage }
        defer {
            Darwin.close(fd)
            unlinkat(directoryFD, temporary, 0)
        }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(
                    fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw ConnectionFailure.storage }
                offset += count
            }
        }
        guard fsync(fd) == 0 else { throw ConnectionFailure.storage }
        try checkDirectory()
        guard renameat(directoryFD, temporary, directoryFD, filename) == 0, fsync(directoryFD) == 0
        else { throw ConnectionFailure.storage }
        _ = try read()
    }
    package func load() throws -> [SavedConnection] {
        try lock.withLock { do { return try read() } catch { throw ConnectionFailure.storage } }
    }
    package func save(_ connections: [SavedConnection]) throws {
        try lock.withLock {
            do { try write(try SettingsEnvelope.encode(connections)) } catch {
                throw ConnectionFailure.storage
            }
        }
    }
}
