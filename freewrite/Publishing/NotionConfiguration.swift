import Foundation

struct NotionConfiguration {
    static let apiVersion = "2026-03-11"
    static let databaseID = "30830b139a6480dbad67f1c9244194d4"
    static let dataSourceID = "30830b13-9a64-80c6-8bb0-000b67499f3d"
    static let tokenAccount = "notion-token"
    static let allowedStatuses: Set<String> = ["concept", "writing", "paused", "published"]
    static let allowedCategories: Set<String> = [
        "AI & LLMs", "Software Development", "Personal Growth", "Startup Ideas",
        "Health & Fitness", "Personal Life", "Tech Reviews", "Learning & Education",
        "Life Skills", "Student Life", "Philosophy", "Random Thoughts", "Social Critic"
    ]
}
