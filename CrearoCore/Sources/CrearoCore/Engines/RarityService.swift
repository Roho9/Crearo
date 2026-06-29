import Foundation

// Originality-as-rarity: how far a response sits from the dense center of all responses to the
// SAME prompt (Torrance's statistical rarity, via embeddings). In production this is a Supabase
// pgvector / HNSW k-NN query (see docs/CREATIVITY_SCORING.md §4 and supabase/schema.sql);
// here we define the contract + an in-memory implementation for tests, previews, and cold-start.

public struct RarityResult: Codable, Equatable, Sendable {
    public let percentile: Double      // 0...1 (1 = most original / rarest)
    public let meanSimilarity: Double  // mean cosine similarity to nearest neighbors
    public init(percentile: Double, meanSimilarity: Double) {
        self.percentile = percentile
        self.meanSimilarity = meanSimilarity
    }

    /// Neutral cold-start value used before a prompt has a population.
    public static let coldStart = RarityResult(percentile: 0.5, meanSimilarity: 0)
}

public protocol RarityService: Sendable {
    /// Compute population rarity for an embedding against everyone else's responses to `promptID`.
    func rarity(promptID: String, embedding: [Float]) async throws -> RarityResult
}

/// In-memory rarity over a local corpus. Used by tests/previews and as an offline fallback.
public final class InMemoryRarityService: RarityService, @unchecked Sendable {
    private var corpus: [String: [[Float]]] = [:]
    private let k: Int
    private let lock = NSLock()

    public init(k: Int = 20) { self.k = k }

    /// Seed the corpus (simulating other players' gate-passing responses to a prompt).
    public func add(promptID: String, embedding: [Float]) {
        lock.lock(); defer { lock.unlock() }
        corpus[promptID, default: []].append(embedding)
    }

    public func rarity(promptID: String, embedding: [Float]) async throws -> RarityResult {
        lock.lock()
        let others = corpus[promptID] ?? []
        lock.unlock()

        guard !others.isEmpty else { return .coldStart }

        // Cosine similarity to all; take the top-k nearest (highest similarity).
        let sims = others.map { cosineSimilarity($0, embedding) }.sorted(by: >)
        let topK = Array(sims.prefix(k))
        guard !topK.isEmpty else { return .coldStart }
        let mean = topK.reduce(0, +) / Double(topK.count)

        // Low similarity to neighbors ⇒ sparse neighborhood ⇒ rare ⇒ high percentile.
        let percentile = clamp01(1 - mean)
        return RarityResult(percentile: percentile, meanSimilarity: mean)
    }
}
