import Darwin
import Foundation

/// Publishes an encoded file in the same directory without overwriting earlier results.
/// Uses a fast exclusive rename when supported, or an exclusive copy on ExFAT.
enum OutputFile {
    static func publish(temporary: URL, output: URL) throws -> URL {
        var candidate = output
        var suffix = 1
        while true {
            let result = temporary.withUnsafeFileSystemRepresentation { source in
                candidate.withUnsafeFileSystemRepresentation { destination in
                    renamex_np(source!, destination!, UInt32(RENAME_EXCL))
                }
            }
            if result == 0 { return candidate }
            var code = errno
            if code == ENOTSUP || code == EXDEV {
                do {
                    try copyExclusively(temporary: temporary, output: candidate)
                    return candidate
                } catch {
                    let failure = error as NSError
                    guard failure.domain == NSPOSIXErrorDomain else { throw error }
                    code = Int32(failure.code)
                }
            }
            // Only a name collision warrants another attempt. Permissions, missing
            // sources and filesystem errors must be reported rather than retried.
            guard code == EEXIST else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [
                    NSFilePathErrorKey: candidate.path
                ])
            }
            candidate = output.deletingLastPathComponent().appendingPathComponent(
                "\(output.deletingPathExtension().lastPathComponent) (\(suffix)).\(output.pathExtension)"
            )
            suffix += 1
        }
    }

    /// O_EXCL claims the name atomically, including on filesystems without hard
    /// links or exclusive rename. A failed copy removes only the file we created.
    static func copyExclusively(temporary: URL, output: URL) throws {
        func failure(_ code: Int32, at url: URL) -> NSError {
            NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: url.path])
        }
        let source = temporary.withUnsafeFileSystemRepresentation { open($0!, O_RDONLY) }
        guard source >= 0 else { throw failure(errno, at: temporary) }
        defer { close(source) }
        var info = stat()
        guard fstat(source, &info) == 0 else { throw failure(errno, at: temporary) }
        guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw failure(EINVAL, at: temporary)
        }
        let destination = output.withUnsafeFileSystemRepresentation { open($0!, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o666)) }
        guard destination >= 0 else { throw failure(errno, at: output) }
        var completed = false
        defer {
            if !completed { _ = output.withUnsafeFileSystemRepresentation { unlink($0!) } }
        }
        let result = fcopyfile(source, destination, nil, copyfile_flags_t(COPYFILE_DATA))
        let copyError = errno
        let closeResult = close(destination)
        let closeError = errno
        guard result == 0 else { throw failure(copyError, at: output) }
        guard closeResult == 0 else { throw failure(closeError, at: output) }
        try FileManager.default.removeItem(at: temporary)
        completed = true
    }
}
