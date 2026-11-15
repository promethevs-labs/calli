import Foundation

/// A deliberately small frontmatter editor. Unedited YAML is retained verbatim.
/// Unsupported YAML values remain readable as raw source, but cannot be overwritten.
struct EntryFrontmatter {
    enum Key: String, CaseIterable {
        case calliStatus = "calli_status"
        case notionPageID = "notion_page_id"
        case substackDraftID = "substack_draft_id"
        case categories, tags, notes

        var isList: Bool { self == .categories || self == .tags }
    }

    enum Value: Equatable {
        case string(String)
        case strings([String])
    }

    enum Failure: Error, Equatable {
        case unclosedHeader
        case duplicateKey(Key)
        case unsupportedValue(Key)
        case wrongValueType(Key)
    }

    private struct Field {
        let key: Key
        let range: Range<Int>
        let value: Value?
    }

    private enum Edit { case set(Value), remove }
    private let newline: String
    private let opening: String?
    private let closing: String?
    private let header: [String]
    private let fields: [Field]
    private var edits: [Key: Edit] = [:]
    var body: String

    init(_ source: String) throws {
        newline = source.contains("\r\n") ? "\r\n" : "\n"
        let lines = Self.lines(source)
        guard let first = lines.first, Self.content(first) == "---" else {
            opening = nil
            closing = nil
            header = []
            fields = []
            body = source
            return
        }
        guard let end = lines.dropFirst().firstIndex(where: { Self.content($0) == "---" }) else {
            throw Failure.unclosedHeader
        }
        opening = first
        closing = lines[end]
        header = Array(lines[1..<end])
        body = lines.dropFirst(end + 1).joined()

        // A field owns only its value lines, never the comments or blank lines after it.
        var parsed: [Field] = []
        for index in header.indices {
            let line = Self.content(header[index])
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"),
                  let colon = line.firstIndex(of: ":") else { continue }
            let rawKey = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            guard let key = Key(rawValue: rawKey) ?? Self.scalar(rawKey).flatMap({ Key(rawValue: $0) }) else { continue }
            if parsed.contains(where: { $0.key == key }) { throw Failure.duplicateKey(key) }
            var endIndex = index + 1
            var cursor = endIndex
            while cursor < header.count {
                let next = Self.content(header[cursor])
                if next.isEmpty || next.hasPrefix("#") { cursor += 1; continue }
                guard next.hasPrefix(" ") || next.hasPrefix("\t") || next == "-" || next.hasPrefix("- ") else { break }
                endIndex = cursor + 1
                cursor += 1
            }
            let raw = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            let continuation = header[(index + 1)..<endIndex].map(Self.content)
            parsed.append(Field(key: key, range: index..<endIndex,
                                value: Self.parse(raw, continuation: continuation, key: key)))
        }
        fields = parsed
    }

    func value(for key: Key) -> Value? {
        if let edit = edits[key] {
            switch edit { case .set(let value): return value; case .remove: return nil }
        }
        return fields.first(where: { $0.key == key })?.value
    }

    /// Passing nil removes a supported field. Unsupported existing fields fail closed.
    mutating func set(_ value: Value?, for key: Key) throws {
        if let field = fields.first(where: { $0.key == key }), field.value == nil {
            throw Failure.unsupportedValue(key)
        }
        if let value {
            switch value {
            case .string where key.isList, .strings where !key.isList:
                throw Failure.wrongValueType(key)
            default: break
            }
        }
        if value == fields.first(where: { $0.key == key })?.value {
            edits.removeValue(forKey: key)
        } else {
            edits[key] = value.map(Edit.set) ?? .remove
        }
    }

    func serialized() -> String {
        guard opening != nil || !edits.isEmpty else { return body }
        var output = opening ?? "---" + newline
        var index = 0
        while index < header.count {
            if let field = fields.first(where: { $0.range.lowerBound == index }), let edit = edits[field.key] {
                if case .set(let value) = edit { output += Self.render(value, key: field.key) + newline }
                index = field.range.upperBound
            } else {
                output += header[index]
                index += 1
            }
        }
        for key in Key.allCases where !fields.contains(where: { $0.key == key }) {
            if case .set(let value) = edits[key] { output += Self.render(value, key: key) + newline }
        }
        let end = closing ?? "---" + newline
        output += end
        // A closing delimiter at EOF needs a line ending before a newly supplied body.
        if !body.isEmpty && !end.hasSuffix("\n") && !end.hasSuffix("\r\n") { output += newline }
        return output + body
    }

    private static func lines(_ source: String) -> [String] {
        guard !source.isEmpty else { return [] }
        let parts = source.components(separatedBy: "\n")
        return parts.enumerated().compactMap { index, part in
            if index < parts.count - 1 { return part + "\n" }
            return part.isEmpty ? nil : part
        }
    }

    private static func content(_ line: String) -> String {
        if line.hasSuffix("\r\n") { return String(decoding: line.utf8.dropLast(2), as: UTF8.self) }
        if line.hasSuffix("\n") { return String(line.dropLast()) }
        return line
    }

    private static func parse(_ raw: String, continuation: [String], key: Key) -> Value? {
        if key.isList {
            if raw.isEmpty {
                var values: [String] = []
                for line in continuation {
                    guard line.hasPrefix("  - "), let value = scalar(String(line.dropFirst(4))) else { return nil }
                    values.append(value)
                }
                return .strings(values)
            }
            guard continuation.isEmpty, raw.hasPrefix("["), raw.hasSuffix("]"),
                  let parts = listParts(String(raw.dropFirst().dropLast())) else { return nil }
            var values: [String] = []
            for part in parts {
                guard let value = scalar(part) else { return nil }
                values.append(value)
            }
            return .strings(values)
        }
        if key == .notes && (raw == "|" || raw == "|-") {
            guard !continuation.isEmpty, continuation.allSatisfy({ $0.hasPrefix("  ") }) else { return nil }
            return .string(continuation.map { String($0.dropFirst(2)) }.joined(separator: "\n") + (raw == "|" ? "\n" : ""))
        }
        guard continuation.isEmpty, let value = scalar(raw) else { return nil }
        return .string(value)
    }

    private static func scalar(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("\"") {
            return try? JSONDecoder().decode(String.self, from: Data(text.utf8))
        }
        if text.hasPrefix("'") {
            guard text.hasSuffix("'"), text.count >= 2 else { return nil }
            let inner = String(text.dropFirst().dropLast())
            guard !inner.replacingOccurrences(of: "''", with: "").contains("'") else { return nil }
            return inner.replacingOccurrences(of: "''", with: "'")
        }
        guard !"[]{}&*!|>@`%#-?:".contains(text.first!), !text.contains(": "),
              !text.contains(" #"), !text.contains("\t"), !text.contains("\r") else { return nil }
        return text
    }

    private static func listParts(_ text: String) -> [String]? {
        if text.trimmingCharacters(in: .whitespaces).isEmpty { return [] }
        var quote: Character?
        var escaped = false
        var parts: [String] = []
        var current = ""
        for character in text {
            if escaped { escaped = false; current.append(character); continue }
            if character == "\\" && quote == "\"" { escaped = true; current.append(character); continue }
            if let active = quote {
                if character == active { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "," {
                parts.append(current); current = ""; continue
            }
            current.append(character)
        }
        guard quote == nil, !escaped else { return nil }
        parts.append(current)
        return parts
    }

    private static func render(_ value: Value, key: Key) -> String {
        func quoted(_ string: String) -> String {
            // JSON strings are a YAML-compatible subset, including escaped newlines.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            return String(data: try! encoder.encode(string), encoding: .utf8)!
        }
        switch value {
        case .string(let string): return key.rawValue + ": " + quoted(string)
        case .strings(let strings): return key.rawValue + ": [" + strings.map(quoted).joined(separator: ", ") + "]"
        }
    }
}
