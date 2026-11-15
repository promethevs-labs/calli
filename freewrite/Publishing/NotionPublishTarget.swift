import Foundation

/// Contains only safe categories/status codes, never server messages or underlying errors.
enum NotionPublishError: Error, Equatable, LocalizedError {
    case notConfigured, credentialUnavailable, invalidStatus, invalidRemoteID
    case payloadTooLarge, invalidResponse, authentication, forbidden, notFound
    case rateLimited, transport, httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Configure a Notion token before publishing."
        case .credentialUnavailable: return "The Notion credential could not be read."
        case .invalidStatus: return "The draft has an unsupported publishing status."
        case .invalidRemoteID: return "The saved Notion page identifier is invalid."
        case .payloadTooLarge: return "This entry exceeds the Notion request limits."
        case .invalidResponse: return "Notion returned an invalid response."
        case .authentication: return "Notion rejected the credential."
        case .forbidden: return "Notion denied access to this page or data source."
        case .notFound: return "The Notion page or data source was not found."
        case .rateLimited: return "Notion is rate limiting requests. Try again later."
        case .transport: return "The Notion request could not be completed."
        case .httpStatus(let code): return "Notion returned HTTP \(code)."
        }
    }
}

struct NotionPublishTarget: PublishTarget {
    let name = "Notion"
    private let client: any NotionHTTPClient
    private let tokenProvider: () throws -> String?

    init(client: any NotionHTTPClient, tokenProvider: @escaping () throws -> String? = {
        guard let data = try KeychainStore().get(account: NotionConfiguration.tokenAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }) {
        self.client = client
        self.tokenProvider = tokenProvider
    }

    func pushDraft(_ doc: PublishDocument) async throws -> PublishResult {
        let payload = try createPayload(doc)
        return try await create(payload: payload, token: token())
    }

    func updateDraft(_ doc: PublishDocument, remoteId: String) async throws -> PublishResult {
        guard Self.isValidID(remoteId) else { throw NotionPublishError.invalidRemoteID }
        // Validate both bodies before making the first mutation.
        let propertyPayload = try encode(["properties": properties(doc, creating: false)])
        let markdownPayload = try encode([
            "type": "replace_content", "replace_content": ["new_str": doc.markdown], "markdown_version": "v2"
        ])
        let credential = try token()
        do {
            let pageData = try await send("PATCH", path: "pages/\(remoteId)", body: propertyPayload, token: credential)
            let result = try pageResult(pageData)
            _ = try await send("PATCH", path: "pages/\(remoteId)/markdown", body: markdownPayload, token: credential)
            return result
        } catch NotionPublishError.notFound {
            // Exactly one replacement create. The coordinator must persist the returned ID.
            return try await create(payload: createPayload(doc), token: credential)
        }
    }

    private func createPayload(_ doc: PublishDocument) throws -> Data {
        try encode([
            "parent": ["type": "data_source_id", "data_source_id": NotionConfiguration.dataSourceID],
            "properties": properties(doc, creating: true),
            "markdown": doc.markdown, "markdown_version": "v2"
        ])
    }

    private func create(payload: Data, token: String) async throws -> PublishResult {
        try await pageResult(send("POST", path: "pages", body: payload, token: token))
    }

    private func properties(_ doc: PublishDocument, creating: Bool) throws -> [String: Any] {
        if let status = doc.calliStatus, !NotionConfiguration.allowedStatuses.contains(status) {
            throw NotionPublishError.invalidStatus
        }
        var result: [String: Any] = ["Title": ["title": try propertyText(doc.title)]]
        let effectiveStatus = creating ? "writing" : doc.calliStatus
        if let status = effectiveStatus { result["Status"] = ["status": ["name": status]] }
        if let categories = doc.categories {
            result["Categories"] = ["multi_select": try selections(categories.filter { NotionConfiguration.allowedCategories.contains($0) })]
        }
        if let tags = doc.tags { result["Tags"] = ["multi_select": try selections(tags)] }
        if let notes = doc.notes { result["Writing Notes"] = ["rich_text": try propertyText(notes)] }
        if effectiveStatus == "published", let date = doc.publishedDate {
            result["Published Date"] = ["date": ["start": date]]
        }
        return result
    }

    private func propertyText(_ text: String) throws -> [[String: Any]] {
        let fragments = NotionBlockChunker.richText(text)
        guard fragments.count <= 100 else { throw NotionPublishError.payloadTooLarge }
        return fragments
    }

    private func selections(_ names: [String]) throws -> [[String: String]] {
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        guard unique.count <= 100 else { throw NotionPublishError.payloadTooLarge }
        return unique.map { ["name": $0] }
    }

    private func token() throws -> String {
        let value: String?
        do { value = try tokenProvider() }
        catch { throw NotionPublishError.credentialUnavailable }
        guard let value, !value.isEmpty,
              value.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }) else {
            throw NotionPublishError.notConfigured
        }
        return value
    }

    private func encode(_ object: [String: Any]) throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard data.count <= NotionBlockChunker.maximumPayloadBytes else { throw NotionPublishError.payloadTooLarge }
        return data
    }

    private func send(_ method: String, path: String, body: Data, token: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.notion.com/v1/" + path)!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(NotionConfiguration.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await client.send(request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw NotionPublishError.transport }
        guard (200..<300).contains(response.statusCode) else {
            // Decode only the error code, never retain or expose the message/body.
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if response.statusCode == 404 || object?["code"] as? String == "object_not_found" {
                throw NotionPublishError.notFound
            }
            switch response.statusCode {
            case 401: throw NotionPublishError.authentication
            case 403: throw NotionPublishError.forbidden
            case 429: throw NotionPublishError.rateLimited
            default: throw NotionPublishError.httpStatus(response.statusCode)
            }
        }
        return data
    }

    private func pageResult(_ data: Data) throws -> PublishResult {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let id = object["id"] as? String, Self.isValidID(id) else {
            throw NotionPublishError.invalidResponse
        }
        let url = (object["url"] as? String).flatMap(URL.init(string:))
        return PublishResult(remoteId: id, url: url?.scheme == "https" ? url : nil)
    }

    private static func isValidID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
        }
    }
}
