import Foundation
import Testing

struct freewriteTests {
    @Test func noFrontmatterRoundTripsExactly() throws {
        for text in ["", "hello", "\n\nMy writing\n", "--- is prose\r\n", "text\n---\n"] {
            let entry = try EntryFrontmatter(text)
            #expect(entry.body == text)
            #expect(entry.serialized() == text)
        }
    }

    @Test func parsesStringsAndListsWithoutReformatting() throws {
        let source = "---\ncalli_status: draft\nnotion_page_id: 'page''s id'\nsubstack_draft_id: \"123\"\ncategories: [essays, 'personal, notes']\ntags:\n  - writing\n  - \"daily\"\nnotes: |-\n  First line\n  Second line\n---\n\nBody\n"
        var entry = try EntryFrontmatter(source)
        #expect(entry.value(for: .calliStatus) == .string("draft"))
        #expect(entry.value(for: .notionPageID) == .string("page's id"))
        #expect(entry.value(for: .substackDraftID) == .string("123"))
        #expect(entry.value(for: .categories) == .strings(["essays", "personal, notes"]))
        #expect(entry.value(for: .tags) == .strings(["writing", "daily"]))
        #expect(entry.value(for: .notes) == .string("First line\nSecond line"))
        try entry.set(.string("draft"), for: .calliStatus)
        #expect(entry.serialized() == source)
    }

    @Test func editsPreserveUnknownNestedYAMLAndComments() throws {
        let unknown = "# Keep this comment\ncustom:\n  nested:\n    - thing: 'retain quotes'\n  enabled: true\n\n"
        var entry = try EntryFrontmatter("---\n" + unknown + "calli_status: draft\n# Footer\n---\nOld body")
        try entry.set(.string("published"), for: .calliStatus)
        try entry.set(.strings(["one", "two, three"]), for: .tags)
        entry.body = "New body\n"
        #expect(entry.serialized() == "---\n" + unknown + "calli_status: \"published\"\n# Footer\ntags: [\"one\", \"two, three\"]\n---\nNew body\n")
        let reloaded = try EntryFrontmatter(entry.serialized())
        #expect(reloaded.value(for: .tags) == .strings(["one", "two, three"]))
        #expect(reloaded.body == "New body\n")
    }

    @Test func recognizesQuotedAndSpacedKnownKeys() throws {
        var entry = try EntryFrontmatter("---\n'calli_status' : draft\ntags : [one]\n---\nBody")
        #expect(entry.value(for: .calliStatus) == .string("draft"))
        try entry.set(.strings(["two"]), for: .tags)
        #expect(entry.serialized() == "---\n'calli_status' : draft\ntags: [\"two\"]\n---\nBody")
    }

    @Test func createsAndRemovesMetadataSafely() throws {
        var entry = try EntryFrontmatter("\n\nExisting body")
        try entry.set(.string("a \"quote\"\nand another line"), for: .notes)
        let reloaded = try EntryFrontmatter(entry.serialized())
        #expect(reloaded.value(for: .notes) == .string("a \"quote\"\nand another line"))
        #expect(reloaded.body == "\n\nExisting body")
        var existing = try EntryFrontmatter("---\ntags:\n  - first\n  - second\ncustom: keep\n---\nBody")
        try existing.set(nil, for: .tags)
        #expect(existing.serialized() == "---\ncustom: keep\n---\nBody")
    }

    @Test func CRLFRoundTripAndEdits() throws {
        let source = "---\r\ncalli_status: draft\r\nunknown: yes\r\n---\r\nBody\r\n"
        var entry = try EntryFrontmatter(source)
        #expect(entry.serialized() == source)
        try entry.set(.string("ready"), for: .calliStatus)
        #expect(entry.serialized() == source.replacingOccurrences(of: "draft", with: "\"ready\""))
        #expect(try EntryFrontmatter("---\n---").serialized() == "---\n---")
    }

    @Test func malformedAndUnsupportedEditsFailClosed() throws {
        #expect(throws: EntryFrontmatter.Failure.unclosedHeader) {
            try EntryFrontmatter("---\ncalli_status: draft\n")
        }
        #expect(throws: EntryFrontmatter.Failure.duplicateKey(.tags)) {
            try EntryFrontmatter("---\ntags: []\ntags: []\n---\n")
        }
        for field in ["notes: {nested: true}", "notes: \"unterminated", "notes: &anchor value", "notes: text # comment"] {
            let source = "---\n" + field + "\n---\nBody"
            var entry = try EntryFrontmatter(source)
            #expect(entry.serialized() == source)
            #expect(throws: EntryFrontmatter.Failure.unsupportedValue(.notes)) {
                try entry.set(.string("replacement"), for: .notes)
            }
            #expect(entry.serialized() == source)
        }
        var unindentedList = try EntryFrontmatter("---\ntags:\n- first\n- second\n---\n")
        #expect(throws: EntryFrontmatter.Failure.unsupportedValue(.tags)) {
            try unindentedList.set(.strings(["replacement"]), for: .tags)
        }
        var spacedList = try EntryFrontmatter("---\ntags:\n  - first\n\n  - second\n---\n")
        #expect(throws: EntryFrontmatter.Failure.unsupportedValue(.tags)) {
            try spacedList.set(.strings(["replacement"]), for: .tags)
        }
        var spacedNotes = try EntryFrontmatter("---\nnotes: |-\n  first\n\n  second\n---\n")
        #expect(throws: EntryFrontmatter.Failure.unsupportedValue(.notes)) {
            try spacedNotes.set(.string("replacement"), for: .notes)
        }
        var entry = try EntryFrontmatter("Body")
        #expect(throws: EntryFrontmatter.Failure.wrongValueType(.tags)) {
            try entry.set(.string("wrong"), for: .tags)
        }
    }

    @Test func storageLocationUsesExplicitDocumentsDirectory() {
        let documents = URL(fileURLWithPath: "/tmp/calli-test-documents", isDirectory: true)
        #expect(StorageLocation.entriesDirectory(documentsDirectory: documents) == documents.appendingPathComponent("Freewrite"))
    }

    @Test func storageLocationDefaultsToFoundationDocumentsDirectory() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #expect(StorageLocation.entriesDirectory() == documents.appendingPathComponent("Freewrite"))
    }
}
