import Foundation
import CrearoCore

// Orchestrates the CrearoCore engines into high-level game operations (forge, daily quest, decay).
// Kept synchronous & value-in/value-out so it's easy to reason about and test; AppState performs
// the async I/O (AI + persistence) around it.

struct ForgeOutcome {
    let creation: Creation
    let affordable: Bool
    let act: ScoredActResult
}

struct ScoredActResult {
    let score: CreativityScore
    let prophecy: String?
    let companionLine: String
    let newBadges: [Badge]
    let recognizedClass: EmergentClass?
    let earned: [ResourceAmount]
}

struct GameEngine {
    let scoring = CreativityScoringEngine()
    let balance = BalanceEngine()
    let prophecy = ProphecyComposer()
    let companionDir = CompanionDirector()
    let classEmergence = ClassEmergence()
    let badges = BadgeGranter()
    let decay = DecayService()

    // MARK: Forge a permanent creation from an interpreted idea (GDD §23, §33–34)

    func forge(into ws: inout WorldState, ideaText: String, modality: Modality, region: RegionID,
               interpreted: InterpretedIdea, rarity: RarityResult?) -> ForgeOutcome {
        let input = makeScoringInput(text: ideaText, modality: modality,
                                     promptID: "forge.\(region.rawValue)", rarity: rarity)
        let score = scoring.score(input)
        let affinity = classEmergence.recognizedClass(from: ws.profile)

        // Assemble → cost → clamp (creative stats come from the score, see Creation.assemble).
        let preliminary = Creation.assemble(idea: interpreted, score: score, cost: [], region: region,
                                            classAffinity: affinity)
        let cost = balance.cost(for: preliminary, score: score, level: ws.character.level)
        var creation = balance.clamp(
            Creation.assemble(idea: interpreted, score: score, cost: cost, region: region, classAffinity: affinity),
            level: ws.character.level
        )

        let affordable = ws.wallet.canAfford(cost)
        if affordable { try? ws.wallet.spend(cost) } else { creation.decay.glowLoss = 0.3 } // unaffordable = a fainter making

        let act = applyAct(into: &ws, score: score, input: input)
        ws.companion.remember(creation.name)
        ws.creations.append(creation)
        return ForgeOutcome(creation: creation, affordable: affordable, act: act)
    }

    // MARK: Respond to a daily creative quest / dialogue prompt (no item; earns resources, GDD §31)

    func respondToQuest(into ws: inout WorldState, text: String, modality: Modality,
                        promptID: String, focus: DimensionScores = .uniform, rarity: RarityResult?) -> ScoredActResult {
        let input = makeScoringInput(text: text, modality: modality, promptID: promptID, rarity: rarity)
        return applyAct(into: &ws, score: scoring.score(input), input: input, focus: focus)
    }

    // MARK: Shared post-scoring side effects (profile, companion, badges, classes, regions, prophecy)

    private func applyAct(into ws: inout WorldState, score: CreativityScore, input: ScoringInput,
                          focus: DimensionScores = .uniform) -> ScoredActResult {
        let previous = ws.profile

        let earned = scoring.resourceReward(for: score, focus: focus)
        ws.wallet.earn(earned)
        ws.profile = scoring.updatedProfile(ws.profile, with: score, input: input)
        ws.companion.tone = companionDir.updatedTone(ws.companion.tone, after: score)

        let newBadges = badges.newBadges(score: score, profile: ws.profile, existing: ws.badges)
        ws.badges.append(contentsOf: newBadges)

        ws.character.classAffinities = classEmergence.affinities(from: ws.profile)
        let unlocked = RegionGates.unlockedRegions(for: ws.profile)
        ws.unlockedRegions = RegionID.allCases.filter { unlocked.contains($0) }
        ws.home.lastMeaningfulActivity = Date()
        ws.home.corruptionLevel = 0
        ws.companion.brightness = min(1, ws.companion.brightness + 0.15) // making brightens the world

        let recognized = classEmergence.recognizedClass(from: ws.profile)
        let prophecyText = prophecy.prophecy(from: previous, to: ws.profile)

        let event: CompanionEvent = ws.profile.repetitionRatio > 0.5
            ? .repetitionNudge
            : (score.dimensions.average >= 0.6 ? .genuineNovelty : .emotionalLonging)
        let line = companionDir.line(for: event, companion: ws.companion,
                                     lastCreation: ws.companion.rememberedCreations.last)

        return ScoredActResult(score: score, prophecy: prophecyText, companionLine: line,
                               newBadges: newBadges, recognizedClass: recognized, earned: earned)
    }

    // MARK: Heuristic signal extraction (OFFLINE FALLBACK)
    // In production these signals come from on-device Core ML/Vision + the score-originality Edge
    // Function (embeddings/rarity). This on-device heuristic lets the app run without a backend.
    // It can't judge true semantic novelty (that needs the model), but it DOES refuse to reward
    // empty, generic, or gibberish answers: those collapse the relevance gate so the hidden score
    // lands near zero, instead of every non-empty string scoring middling. See CREATIVITY_SCORING §3,5.

    /// Filler/stopwords that carry no creative specificity on their own.
    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "to", "of", "in", "on", "is", "it", "for",
        "with", "that", "this", "i", "you", "my", "me", "so", "as", "at", "be", "by"
    ]
    /// Low-effort generic answers we explicitly refuse to reward.
    private static let genericTokens: Set<String> = [
        "thing", "things", "something", "anything", "stuff", "idk", "dunno", "whatever",
        "nothing", "good", "nice", "cool", "ok", "okay", "fine", "test", "testing", "blah", "asdf", "yes", "no"
    ]

    func makeScoringInput(text: String, modality: Modality, promptID: String, rarity: RarityResult?) -> ScoringInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let words = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let wordCount = words.count
        let clauses = max(1, trimmed.split(whereSeparator: { ",.;:".contains($0) }).count)

        func has(_ needles: [String]) -> Bool { needles.contains { lower.contains($0) } }

        // "Meaningful" words = content words (not stopwords, length > 2). Distinct count of these
        // is our offline proxy for how specific / substantive the answer is.
        let meaningful = words.filter { $0.count > 2 && !Self.stopwords.contains($0) }
        let distinctMeaningful = Set(meaningful).count
        // A word with no vowels (and >3 chars) is almost certainly keyboard-mash.
        let looksGibberish = !words.isEmpty && words.allSatisfy { w in
            w.count > 3 && !w.contains(where: { "aeiouy".contains($0) })
        }
        // How much of the answer is just filler / generic tokens.
        let genericCount = words.filter { Self.genericTokens.contains($0) }.count
        let genericRatio = words.isEmpty ? 1.0 : Double(genericCount) / Double(words.count)
        let isLowEffort = distinctMeaningful < 2 || genericRatio >= 0.5

        // specificity 0...1 — needs ~6 distinct content words to saturate.
        let specificity = min(1.0, Double(distinctMeaningful) / 6.0)

        // Relevance/validity/coherence DRIVE the gate. Empty, gibberish, or generic answers
        // push relevance below ScoringConfig.relevanceFloor (0.25), collapsing the whole score.
        let relevance: Double
        if trimmed.isEmpty || looksGibberish { relevance = 0.05 }
        else if isLowEffort { relevance = 0.15 }
        else { relevance = min(1.0, 0.3 + specificity * 0.7) }

        let functionalValidity = (trimmed.isEmpty || looksGibberish) ? 0.1 : min(1.0, 0.35 + specificity * 0.65)
        let coherence = trimmed.isEmpty ? 0.1 : (looksGibberish ? 0.2 : (wordCount >= 2 ? 0.85 : 0.5))

        let detail = min(1.0, Double(meaningful.count) / 30.0)
        let semantic = min(1.0, Double(distinctMeaningful) / 12.0)
        let categories = min(4, max(1, distinctMeaningful / 3))
        let emotional = has(["love", "fear", "grief", "hope", "ache", "memory", "lonely", "warm", "miss", "tender"]) ? 0.7 : 0.2
        let symbol = has(["like", " as ", "becomes", "mirror", "shadow", "door", "tide", "echo", "thread"]) ? 0.6 : 0.2
        let risk = isLowEffort ? 0.1 : (trimmed.count > 60 ? 0.6 : (trimmed.count > 25 ? 0.4 : 0.25))
        let effort = isLowEffort ? 0.1 : min(1.0, Double(meaningful.count) / 20.0 + 0.2)

        return ScoringInput(
            promptID: promptID, modality: modality,
            relevance: relevance, functionalValidity: functionalValidity, coherence: coherence,
            semanticDistance: semantic, rarityPercentile: rarity?.percentile,
            ideaCount: clauses, distinctCategoryCount: categories, detail: detail,
            emotionalCharge: emotional, symbolism: symbol, riskSignal: risk,
            reframingDetected: false, constraintSatisfied: !isLowEffort && !trimmed.isEmpty, effort: effort
        )
    }

    /// A tiny deterministic "embedding" so the in-memory rarity service has something to compare
    /// offline (NOT a real embedding — production uses a sentence/image model + pgvector).
    static func pseudoEmbedding(_ text: String, dimensions: Int = 16) -> [Float] {
        var vec = [Float](repeating: 0, count: dimensions)
        for word in text.lowercased().split(separator: " ") {
            let h = abs(word.hashValue)
            vec[h % dimensions] += 1
        }
        let norm = sqrt(vec.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? vec.map { $0 / norm } : vec
    }

    /// Used if the AI service is unavailable, so forging never hard-fails.
    static func fallbackInterpreted(text: String) -> InterpretedIdea {
        InterpretedIdea(
            itemType: .tool,
            traditional: TraditionalStats(damage: 8, durability: 20, weight: 2),
            effect: UniqueEffect(kind: .light, magnitude: 0.3, durationSec: 4, cooldownSec: 2, range: 2),
            artDescriptor: "a hand-made thing, dark-fantasy, faintly glowing",
            suggestedName: StubName.from(text)
        )
    }

    private enum StubName {
        static func from(_ text: String) -> String {
            let words = text.split(separator: " ").prefix(3)
            guard !words.isEmpty else { return "Nameless Making" }
            return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        }
    }
}
