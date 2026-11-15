import Foundation

/// Resolves paths only; callers retain responsibility for creating directories.
/// Foundation supplies the sandbox-aware Documents URL in the running app.
enum StorageLocation {
    static func entriesDirectory(
        documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    ) -> URL {
        documentsDirectory.appendingPathComponent("Freewrite")
    }
}
