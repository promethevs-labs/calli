import Foundation
import Testing

private final class RecordingPublishTarget: PublishTarget {
    let name = "Mock"
    var documents: [PublishDocument] = []
    var updatedIDs: [String] = []
    var onPush: (() throws -> Void)?
    func pushDraft(_ doc: PublishDocument) async throws -> PublishResult {
        documents.append(doc)
        try onPush?()
        return PublishResult(remoteId: "created-page", url: nil)
    }
    func updateDraft(_ doc: PublishDocument, remoteId: String) async throws -> PublishResult {
        documents.append(doc)
        updatedIDs.append(remoteId)
        return PublishResult(remoteId: remoteId, url: nil)
    }
}

struct NotionSyncServiceTests {
    private func fixture(_ source: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("[6910BBDE-75FC-415C-ABB9-C76644B037B2]-[2026-02-20-08-01-04].md")
        try source.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func syncPreservesBodyAndUnknownKeysThenUpdates() async throws {
        let body = "\r\nAn intro\r\n# My title\r\n\r\nTrailing spaces  \r\n"
        let header = "---\r\ncustom:\r\n  nested: [keep, me]\r\n# comment\r\ncalli_status: paused\r\ncategories: [Philosophy]\r\ntags: [one]\r\nnotes: note\r\npublished_date: 2026-11-15\r\n"
        let url = try fixture(header + "---\r\n" + body)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let target = RecordingPublishTarget()
        let service = NotionSyncService(target: target)
        _ = try await service.sync(entryURL: url)
        let saved = try String(contentsOf: url, encoding: .utf8)
        #expect(saved.hasPrefix(header))
        #expect(try EntryFrontmatter(saved).body == body)
        #expect(try EntryFrontmatter(saved).value(for: .notionPageID) == .string("created-page"))
        let doc = try #require(target.documents.first)
        #expect(doc.title == "My title")
        #expect(doc.markdown == body)
        #expect(doc.localEntryID == "6910BBDE-75FC-415C-ABB9-C76644B037B2")
        #expect(doc.calliStatus == "paused")
        #expect(doc.categories == ["Philosophy"])
        #expect(doc.tags == ["one"])
        #expect(doc.notes == "note")
        #expect(doc.publishedDate == "2026-11-15")
        _ = try await service.sync(entryURL: url)
        #expect(target.updatedIDs == ["created-page"])
    }

    @Test func plainBodyAndConcurrentEditsSurviveWriteback() async throws {
        let url = try fixture("\nOriginal\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let target = RecordingPublishTarget()
        target.onPush = { try "\nEdited during publish\n".write(to: url, atomically: true, encoding: .utf8) }
        _ = try await NotionSyncService(target: target).sync(entryURL: url)
        #expect(try EntryFrontmatter(String(contentsOf: url, encoding: .utf8)).body == "\nEdited during publish\n")
        #expect(target.documents.first?.markdown == "\nOriginal\n")
    }

    @Test func persistenceFailureRetriesDiskBeforeNetwork() async throws {
        let url = try fixture("Body\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let target = RecordingPublishTarget()
        var writes = 0
        let service = NotionSyncService(target: target, write: { text, file in
            writes += 1
            if writes == 1 { throw CocoaError(.fileWriteNoPermission) }
            try text.write(to: file, atomically: true, encoding: .utf8)
        })
        await #expect(throws: NotionSyncService.Failure.persistenceFailed(remoteId: "created-page")) {
            try await service.sync(entryURL: url)
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == "Body\n")
        _ = try await service.sync(entryURL: url)
        #expect(target.documents.count == 1)
        #expect(try EntryFrontmatter(String(contentsOf: url, encoding: .utf8)).value(for: .notionPageID) == .string("created-page"))
        _ = try await service.sync(entryURL: url)
        #expect(target.updatedIDs == ["created-page"])
    }

    @Test func refusesVideosIncludingSymlinkBeforeCallingTarget() async throws {
        let url = try fixture("Body")
        let dir = url.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }
        let videoDir = dir.appendingPathComponent("Videos/recording")
        try FileManager.default.createDirectory(at: videoDir, withIntermediateDirectories: true)
        let transcript = videoDir.appendingPathComponent("transcript.md")
        try "Transcript".write(to: transcript, atomically: true, encoding: .utf8)
        let alias = dir.appendingPathComponent("alias.md")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: transcript)
        let target = RecordingPublishTarget()
        let service = NotionSyncService(target: target)
        for candidate in [transcript, alias, dir.appendingPathComponent("videos/missing.md")] {
            await #expect(throws: NotionSyncService.Failure.transcriptRefused) {
                try await service.sync(entryURL: candidate)
            }
        }
        #expect(target.documents.isEmpty)
    }

    @Test func unsupportedMetadataFailsBeforeRemoteMutation() async throws {
        let url = try fixture("---\nnotion_page_id: {nested: invalid}\n---\nBody")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let target = RecordingPublishTarget()
        await #expect(throws: EntryFrontmatter.Failure.unsupportedValue(.notionPageID)) {
            try await NotionSyncService(target: target).sync(entryURL: url)
        }
        #expect(target.documents.isEmpty)
    }

    @Test func extractsHeadingOrFirstNonemptyLine() {
        #expect(NotionSyncService.title(from: "\n\nFirst line\nMore") == "First line")
        #expect(NotionSyncService.title(from: "intro\n## Heading\n") == "Heading")
        #expect(NotionSyncService.title(from: "intro\n```swift\n# ignored\n```\n### Real") == "Real")
        #expect(NotionSyncService.title(from: "\n ") == "Untitled")
        #expect(NotionSyncService.title(from: "intro\n\nHeading\n===\n") == "Heading")
        #expect(NotionSyncService.title(from: "## Heading ##") == "Heading")
    }
}
