import Foundation

/// Keep one service instance for a publishing session. No automatic network retries.
actor NotionSyncService {
    enum Failure: Error, Equatable {
        case transcriptRefused
        case notMarkdown
        case alreadySyncing
        case persistenceFailed(remoteId: String)
    }

    private let target: any PublishTarget
    private let write: (String, URL) throws -> Void
    private var active: Set<URL> = []
    // If disk write fails after create, retry persistence before sending anything else.
    private var pending: [URL: PublishResult] = [:]

    init(target: any PublishTarget,
         write: @escaping (String, URL) throws -> Void = { source, url in
             try source.write(to: url, atomically: true, encoding: .utf8)
         }) {
        self.target = target
        self.write = write
    }

    func sync(entryURL: URL) async throws -> PublishResult {
        let url = entryURL.standardizedFileURL.resolvingSymlinksInPath()
        // Check both the submitted and resolved path, including case-insensitive volumes.
        guard ![entryURL, url].contains(where: { candidate in
            candidate.pathComponents.contains { $0.lowercased() == "videos" }
        }) else { throw Failure.transcriptRefused }
        guard url.isFileURL, url.pathExtension.lowercased() == "md" else { throw Failure.notMarkdown }
        guard active.insert(url).inserted else { throw Failure.alreadySyncing }
        defer { active.remove(url) }

        if let result = pending[url] {
            try persist(result, at: url)
            return result
        }
        var entry = try EntryFrontmatter(String(contentsOf: url, encoding: .utf8))
        // Validate unsupported known YAML before making any remote mutation.
        for key in EntryFrontmatter.Key.allCases {
            try entry.set(entry.value(for: key), for: key)
        }
        let doc = PublishDocument(
            title: Self.title(from: entry.body), markdown: entry.body,
            localEntryID: Self.entryID(from: url),
            calliStatus: entry.string(.calliStatus), categories: entry.strings(.categories),
            tags: entry.strings(.tags), notes: entry.string(.notes),
            publishedDate: entry.string(.publishedDate))
        let result: PublishResult
        if let id = entry.string(.notionPageID), !id.isEmpty {
            result = try await target.updateDraft(doc, remoteId: id)
        } else {
            result = try await target.pushDraft(doc)
        }
        pending[url] = result
        try persist(result, at: url)
        return result
    }

    private func persist(_ result: PublishResult, at url: URL) throws {
        do {
            // Re-read after the await, preserving any edits made while publishing.
            var current = try EntryFrontmatter(String(contentsOf: url, encoding: .utf8))
            try current.set(.string(result.remoteId), for: .notionPageID)
            try write(current.serialized(), url)
            pending.removeValue(forKey: url)
        } catch {
            throw Failure.persistenceFailed(remoteId: result.remoteId)
        }
    }

    static func title(from markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var fence: Character?
        var firstLine: String?
        var previousLine: String?
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if firstLine == nil && !line.isEmpty { firstLine = line }
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                if fence == line.first { fence = nil }
                else if fence == nil { fence = line.first }
                previousLine = nil
                continue
            }
            guard fence == nil else { continue }
            if let previousLine, !previousLine.isEmpty,
               !line.isEmpty, (line.allSatisfy({ $0 == "=" }) || line.allSatisfy({ $0 == "-" })) {
                return previousLine
            }
            previousLine = line
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), line.dropFirst(hashes).first?.isWhitespace == true {
                var heading = line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
                if let closing = heading.range(of: #"\s+#+$"#, options: .regularExpression) {
                    heading.removeSubrange(closing)
                }
                if !heading.isEmpty { return heading }
            }
        }
        return firstLine ?? "Untitled"
    }

    private static func entryID(from url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        if stem.hasPrefix("["), let end = stem.firstIndex(of: "]"),
           let uuid = UUID(uuidString: String(stem[stem.index(after: stem.startIndex)..<end])) {
            return uuid.uuidString
        }
        return stem
    }
}

private extension EntryFrontmatter {
    func string(_ key: Key) -> String? {
        guard case .string(let value) = value(for: key) else { return nil }
        return value
    }
    func strings(_ key: Key) -> [String]? {
        guard case .strings(let value) = value(for: key) else { return nil }
        return value
    }
}
