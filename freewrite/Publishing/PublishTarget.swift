import Foundation

struct PublishDocument {
    let title: String
    let markdown: String
    let localEntryID: String
    var calliStatus: String? = nil
    var categories: [String]? = nil
    var tags: [String]? = nil
    var notes: String? = nil
    var publishedDate: String? = nil
}

struct PublishResult: Equatable {
    let remoteId: String
    let url: URL?
}

protocol PublishTarget {
    var name: String { get }
    func pushDraft(_ doc: PublishDocument) async throws -> PublishResult
    func updateDraft(_ doc: PublishDocument, remoteId: String) async throws -> PublishResult
}
