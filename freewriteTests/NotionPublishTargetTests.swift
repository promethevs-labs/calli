import Foundation
import Testing

struct NotionPublishTargetTests {
    @Test func tokenAccountMatchesInstalledCredential() {
        #expect(NotionConfiguration.tokenAccount == "notion-token")
    }

    private let fakeToken = "test-credential-placeholder"
    private let document = PublishDocument(title: "A title", markdown: "# Heading\n\nBody\n", localEntryID: "local-entry")

    @Test func createUsesDataSourceMarkdownAndSafeProperties() async throws {
        let client = MockClient([.page("new-page")])
        let target = target(client)
        var doc = document
        doc.calliStatus = "published"
        doc.publishedDate = "2026-11-15"
        doc.categories = ["AI & LLMs", "unknown", "ai & llms", "Software Development", "AI & LLMs"]
        doc.tags = ["Swift", "Writing", "Swift"]
        doc.notes = "A note\nAnother line"
        let result = try await target.pushDraft(doc)
        #expect(result.remoteId == "new-page")
        #expect(result.url == URL(string: "https://www.notion.so/new-page"))
        let request = try #require(client.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.notion.com/v1/pages")
        #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2026-03-11")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + fakeToken)
        let body = try object(request)
        #expect((body["parent"] as? [String: String])?["data_source_id"] == NotionConfiguration.dataSourceID)
        #expect(body["markdown"] as? String == doc.markdown)
        #expect(body["markdown_version"] as? String == "v2")
        #expect(body["children"] == nil)
        let properties = try #require(body["properties"] as? [String: Any])
        #expect(status(properties) == "writing")
        #expect(text(properties, "Title", "title") == doc.title)
        #expect(text(properties, "Writing Notes", "rich_text") == doc.notes)
        #expect(selections(properties, "Categories") == ["AI & LLMs", "Software Development"])
        #expect(selections(properties, "Tags") == ["Swift", "Writing"])
        #expect(properties["Published Date"] == nil)
        #expect(properties["ID"] == nil)
        #expect(properties["Reminder"] == nil)
        #expect(!String(decoding: request.httpBody!, as: UTF8.self).contains(fakeToken))
    }

    @Test func updateUsesTwoPatchesAndOmitsUnspecifiedStatus() async throws {
        let client = MockClient([.page("saved-page"), .json([:])])
        let result = try await target(client).updateDraft(document, remoteId: "saved-page")
        #expect(result.remoteId == "saved-page")
        #expect(client.requests.count == 2)
        #expect(client.requests.map(\.httpMethod) == ["PATCH", "PATCH"])
        #expect(client.requests.map { $0.url!.path } == ["/v1/pages/saved-page", "/v1/pages/saved-page/markdown"])
        for request in client.requests {
            #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2026-03-11")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + fakeToken)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        }
        let properties = try #require(object(client.requests[0])["properties"] as? [String: Any])
        #expect(properties.keys.sorted() == ["Title"])
        let body = try object(client.requests[1])
        #expect((body["replace_content"] as? [String: String])?["new_str"] == document.markdown)
        #expect(body["markdown_version"] as? String == "v2")
        #expect(body["type"] as? String == "replace_content")
    }

    @Test func updateAcceptsOnlyExplicitAllowedStatusesAndDatesOnlyWhenPublished() async throws {
        for value in ["concept", "writing", "paused", "published"] {
            let client = MockClient([.page("saved-page"), .json([:])])
            var doc = document
            doc.calliStatus = value
            doc.publishedDate = "2026-11-15"
            _ = try await target(client).updateDraft(doc, remoteId: "saved-page")
            let properties = try #require(object(client.requests[0])["properties"] as? [String: Any])
            #expect(status(properties) == value)
            #expect((properties["Published Date"] != nil) == (value == "published"))
        }
        for value in ["kiv", "not worth", "give up", "draft", "Writing", ""] {
            let client = MockClient([])
            var doc = document
            doc.calliStatus = value
            await #expect(throws: NotionPublishError.invalidStatus) {
                try await target(client).updateDraft(doc, remoteId: "saved-page")
            }
            #expect(client.requests.isEmpty)
        }
    }

    @Test func updateRecreatesOnceWhenEitherEndpointIsMissing() async throws {
        for missingMarkdown in [false, true] {
            for response in [MockClient.Reply.json([:], status: 404), .json(["code": "object_not_found"], status: 400)] {
                let replies: [MockClient.Reply] = (missingMarkdown ? [.page("old-page")] : []) + [response, .page("replacement-page")]
                let client = MockClient(replies)
                var doc = document
                doc.calliStatus = "published"
                let result = try await target(client).updateDraft(doc, remoteId: "old-page")
                #expect(result.remoteId == "replacement-page")
                #expect(client.requests.count == (missingMarkdown ? 3 : 2))
                #expect(client.requests.last?.httpMethod == "POST")
                let properties = try #require(object(client.requests.last!)["properties"] as? [String: Any])
                #expect(status(properties) == "writing")
            }
        }
        let client = MockClient([.json([:], status: 404), .json([:], status: 404)])
        await #expect(throws: NotionPublishError.notFound) {
            try await target(client).updateDraft(document, remoteId: "old-page")
        }
        #expect(client.requests.count == 2)
    }

    @Test func failuresNeverRetryOrExposeServerOrTransportMessages() async throws {
        for (code, expected) in [(401, NotionPublishError.authentication), (403, .forbidden), (429, .rateLimited), (500, .httpStatus(500))] {
            let client = MockClient([.json(["message": fakeToken, "code": fakeToken], status: code)])
            await #expect(throws: expected) { try await target(client).pushDraft(document) }
            #expect(client.requests.count == 1)
            #expect(!String(describing: expected).contains(fakeToken))
            #expect(!expected.localizedDescription.contains(fakeToken))
        }
        let client = MockClient([.failure(NSError(domain: fakeToken, code: 1, userInfo: [NSLocalizedDescriptionKey: fakeToken]))])
        await #expect(throws: NotionPublishError.transport) { try await target(client).pushDraft(document) }
        #expect(client.requests.count == 1)
        let invalid = MockClient([.raw(Data("malformed response".utf8), status: 200)])
        await #expect(throws: NotionPublishError.invalidResponse) { try await target(invalid).pushDraft(document) }
        #expect(invalid.requests.count == 1)
    }

    @Test func recreatedPageIDIsPersistedAndNextSyncUpdatesIt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("fixture.md")
        let body = "\n# Fixture heading\n\nExact body  \n"
        let unknown = "custom:\n  nested: [keep, me]\n# retained comment\n"
        try ("---\n" + unknown + "notion_page_id: old-page\n---\n" + body)
            .write(to: file, atomically: true, encoding: .utf8)
        let client = MockClient([
            .json(["code": "object_not_found"], status: 404), .page("replacement-page"),
            .page("replacement-page"), .json([:])
        ])
        let service = NotionSyncService(target: target(client))
        let first = try await service.sync(entryURL: file)
        #expect(first.remoteId == "replacement-page")
        let saved = try String(contentsOf: file, encoding: .utf8)
        let entry = try EntryFrontmatter(saved)
        #expect(entry.value(for: .notionPageID) == .string("replacement-page"))
        #expect(entry.body == body)
        #expect(saved.contains(unknown))
        _ = try await service.sync(entryURL: file)
        #expect(client.requests.map(\.httpMethod) == ["PATCH", "POST", "PATCH", "PATCH"])
        #expect(client.requests[2].url?.path == "/v1/pages/replacement-page")
        #expect(client.requests[3].url?.path == "/v1/pages/replacement-page/markdown")
        #expect(try object(client.requests[1])["markdown"] as? String == body)
        #expect(try String(contentsOf: file, encoding: .utf8) == saved)
    }

    @Test func missingCredentialsAndInvalidIDsDoNotSend() async throws {
        let client = MockClient([])
        let missing = NotionPublishTarget(client: client, tokenProvider: { nil })
        await #expect(throws: NotionPublishError.notConfigured) { try await missing.pushDraft(document) }
        let failed = NotionPublishTarget(client: client, tokenProvider: { throw NSError(domain: "private-credential", code: 1) })
        await #expect(throws: NotionPublishError.credentialUnavailable) { try await failed.pushDraft(document) }
        for id in ["", "../elsewhere", "page?token=private", "with spaces"] {
            await #expect(throws: NotionPublishError.invalidRemoteID) { try await target(client).updateDraft(document, remoteId: id) }
        }
        #expect(client.requests.isEmpty)
    }

    @Test func richTextAndRequestLimitsAreCheckedBeforeMutation() async throws {
        let client = MockClient([])
        var oversized = document
        oversized.notes = String(repeating: "x", count: 200_001)
        await #expect(throws: NotionPublishError.payloadTooLarge) { try await target(client).pushDraft(oversized) }
        let largeBody = PublishDocument(title: "Title", markdown: String(repeating: "x", count: 500_001), localEntryID: "local")
        await #expect(throws: NotionPublishError.payloadTooLarge) { try await target(client).updateDraft(largeBody, remoteId: "page") }
        #expect(client.requests.isEmpty)
        let successful = MockClient([.page("page")])
        var longNotes = document
        longNotes.notes = String(repeating: "💡", count: 2_001)
        _ = try await target(successful).pushDraft(longNotes)
        let properties = try #require(object(successful.requests[0])["properties"] as? [String: Any])
        #expect(text(properties, "Writing Notes", "rich_text") == longNotes.notes)
    }

    @Test func fallbackChunksPreserveTextAndRespectEncodedLimits() throws {
        let source = String(repeating: "# heading\n\n💡e\u{301}\u{0001}\"\\\r\n", count: 20_001)
        let chunks = NotionBlockChunker.textChunks(source)
        #expect(chunks.joined() == source)
        #expect(chunks.allSatisfy { $0.utf16.count <= 2_000 })
        let payloads = try NotionBlockChunker.appendPayloads(for: source)
        #expect(payloads.count > 1)
        var restored = ""
        for payload in payloads {
            #expect(payload.count <= 500_000)
            let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            let children = try #require(object["children"] as? [[String: Any]])
            #expect(!children.isEmpty && children.count <= 100)
            for child in children {
                let paragraph = try #require(child["paragraph"] as? [String: Any])
                let fragments = try #require(paragraph["rich_text"] as? [[String: Any]])
                #expect(fragments.count <= 100)
                for fragment in fragments {
                    let content = try #require((fragment["text"] as? [String: String])?["content"])
                    #expect(content.utf16.count <= 2_000)
                    restored += content
                }
            }
        }
        #expect(restored == source)
        #expect(try NotionBlockChunker.appendPayloads(for: "").isEmpty)
    }

    private func target(_ client: MockClient) -> NotionPublishTarget {
        NotionPublishTarget(client: client, tokenProvider: { fakeToken })
    }

    private func object(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func status(_ properties: [String: Any]) -> String? {
        ((properties["Status"] as? [String: Any])?["status"] as? [String: String])?["name"]
    }

    private func text(_ properties: [String: Any], _ key: String, _ type: String) -> String? {
        guard let fragments = (properties[key] as? [String: Any])?[type] as? [[String: Any]] else { return nil }
        return fragments.compactMap { ($0["text"] as? [String: String])?["content"] }.joined()
    }

    private func selections(_ properties: [String: Any], _ key: String) -> [String]? {
        ((properties[key] as? [String: Any])?["multi_select"] as? [[String: String]])?.compactMap { $0["name"] }
    }
}

private final class MockClient: NotionHTTPClient {
    enum Reply {
        case raw(Data, status: Int)
        case failure(Error)

        static func json(_ object: [String: Any], status: Int = 200) -> Reply {
            .raw(try! JSONSerialization.data(withJSONObject: object), status: status)
        }

        static func page(_ id: String) -> Reply {
            .json(["id": id, "url": "https://www.notion.so/" + id])
        }
    }

    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) { self.replies = replies }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw NotionPublishError.invalidResponse }
        switch replies.removeFirst() {
        case .failure(let error): throw error
        case .raw(let data, let status):
            return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }
}
