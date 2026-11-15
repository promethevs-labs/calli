import Foundation

/// A standalone, plain-text fallback. This does not interpret markdown or send requests.
/// Joining text.content values in order reproduces the input exactly.
enum NotionBlockChunker {
    static let maximumPayloadBytes = 500_000

    static func textChunks(_ text: String) -> [String] {
        var result: [String] = []
        var chunk = String.UnicodeScalarView()
        var units = 0
        for scalar in text.unicodeScalars {
            let length = scalar.value > 0xFFFF ? 2 : 1
            if units + length > 2_000 {
                result.append(String(chunk))
                chunk = String.UnicodeScalarView()
                units = 0
            }
            chunk.append(scalar)
            units += length
        }
        if !chunk.isEmpty { result.append(String(chunk)) }
        return result
    }

    static func richText(_ text: String) -> [[String: Any]] {
        textChunks(text).map { ["type": "text", "text": ["content": $0]] }
    }

    /// Each encoded object can be used as an append-children request body.
    /// A future caller must track partial progress; this helper never retries or replays.
    static func appendPayloads(for text: String) throws -> [Data] {
        var payloads: [Data] = []
        var children: [[String: Any]] = []
        for fragment in textChunks(text) {
            let block: [String: Any] = [
                "object": "block", "type": "paragraph",
                "paragraph": ["rich_text": richText(fragment)]
            ]
            let candidate = children + [block]
            let encoded = try JSONSerialization.data(withJSONObject: ["children": candidate])
            if candidate.count > 100 || encoded.count > maximumPayloadBytes {
                payloads.append(try JSONSerialization.data(withJSONObject: ["children": children]))
                children = [block]
            } else {
                children = candidate
            }
        }
        if !children.isEmpty {
            payloads.append(try JSONSerialization.data(withJSONObject: ["children": children]))
        }
        return payloads
    }
}
