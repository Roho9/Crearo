import Foundation

// Small, module-internal numeric helpers shared by the engines.
// Kept in one place to avoid duplicate-symbol clashes.

/// Clamp a value into 0...1.
@inlinable
func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }

/// Clamp a value into an arbitrary closed range.
@inlinable
func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, x)) }

/// Normalize a non-negative count into 0...1 with a soft cap (diminishing returns).
/// e.g. normalizeCount(3, soft: 6) ≈ 0.5; normalizeCount(12, soft: 6) → 1.0.
@inlinable
func normalizeCount(_ n: Int, soft: Int) -> Double {
    guard soft > 0 else { return n > 0 ? 1 : 0 }
    return min(1.0, Double(max(0, n)) / Double(soft))
}

/// Cosine similarity between two equal-length vectors. Returns 0 for degenerate input.
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var dot: Double = 0, na: Double = 0, nb: Double = 0
    for i in 0..<a.count {
        let x = Double(a[i]), y = Double(b[i])
        dot += x * y; na += x * x; nb += y * y
    }
    guard na > 0, nb > 0 else { return 0 }
    return dot / (na.squareRoot() * nb.squareRoot())
}
