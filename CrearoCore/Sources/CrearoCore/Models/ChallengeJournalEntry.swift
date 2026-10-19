import Foundation

/// A saved invention belongs to one cleared chapter. Scores remain local, with their grading
/// mode recorded so a shared practice estimate cannot be mistaken for a verified ranking.
public struct ChallengeJournalEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let level: Int
    public let contentID: String
    public let title: String
    public let answer: String
    public let score: Int
    public let isPracticeEstimate: Bool
    public let storyBeat: String
    public let createdAt: Date

    public init(id: UUID = UUID(), level: Int, contentID: String, title: String,
                answer: String, score: Int, isPracticeEstimate: Bool,
                storyBeat: String, createdAt: Date = Date()) {
        self.id = id
        self.level = level
        self.contentID = contentID
        self.title = title
        self.answer = answer
        self.score = min(100, max(0, score))
        self.isPracticeEstimate = isPracticeEstimate
        self.storyBeat = storyBeat
        self.createdAt = createdAt
    }
}
