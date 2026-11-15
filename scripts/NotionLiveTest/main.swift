import Foundation

/// No redirects, retries, reads, deletes, or replacement creates.
private final class SmokeClient: NSObject, NotionHTTPClient, URLSessionTaskDelegate {
    private var step = 0
    var pageID: String?
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let expected: String
        let label: String
        switch step {
        case 0:
            expected = "https://api.notion.com/v1/pages"
            label = "create"
        case 1, 2:
            guard let pageID else { throw NotionPublishError.invalidResponse }
            expected = "https://api.notion.com/v1/pages/" + pageID + (step == 2 ? "/markdown" : "")
            label = step == 1 ? "update-properties" : "update-markdown"
        default:
            throw NotionPublishError.invalidResponse
        }
        guard request.url?.absoluteString == expected,
              request.httpMethod == (step == 0 ? "POST" : "PATCH") else {
            throw NotionPublishError.invalidResponse
        }
        step += 1 // Consume the operation even when its outcome is uncertain.
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw NotionPublishError.invalidResponse
            }
            print("\(label) HTTP \(response.statusCode)")
            return (data, response)
        } catch {
            print("\(label) HTTP unavailable")
            throw NotionPublishError.transport
        }
    }
}

@main
private enum NotionLiveTest {
    static func main() async {
        guard ProcessInfo.processInfo.environment["CALLI_LIVE_TEST"] == "1",
              let token = ProcessInfo.processInfo.environment["CALLI_NOTION_TOKEN"],
              !token.isEmpty else {
            print("create HTTP not attempted")
            exit(1)
        }
        let client = SmokeClient()
        let target = NotionPublishTarget(client: client, tokenProvider: { token })
        let body = "Created by Calli live smoke test. Safe to delete."
        do {
            let created = try await target.pushDraft(PublishDocument(
                title: "Calli test", markdown: body, localEntryID: "live-smoke-test"))
            // Only a canonical UUID can authorize the following requests.
            guard UUID(uuidString: created.remoteId) != nil else {
                throw NotionPublishError.invalidResponse
            }
            client.pageID = created.remoteId
            print("page_id \(created.remoteId)")
            // Derive the URL from the validated ID rather than printing server text.
            print("url https://www.notion.so/\(created.remoteId.replacingOccurrences(of: "-", with: ""))")
            let updated = try await target.updateDraft(PublishDocument(
                title: "Calli test", markdown: body + "\nUpdated once by Calli.",
                localEntryID: "live-smoke-test"), remoteId: created.remoteId)
            guard updated.remoteId == created.remoteId else {
                throw NotionPublishError.invalidResponse
            }
        } catch {
            // Never print errors, response bodies, requests, or credentials.
            exit(1)
        }
    }
}
