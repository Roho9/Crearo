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
    // Function (embeddings/rarity). This keyword/length heuristic just lets the app run without a
    // backend so the loop is demonstrable. See docs/CREATIVITY_SCORING.md §3.

    func makeScoringInput(text: String, modality: Modality, promptID: String, rarity: RarityResult?) -> ScoringInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let words = trimmed.split(whereSeparator: { $0 == " " || $0 == "\n" })
        let wordCount = words.count
        let distinctWords = Set(lower.split(separator: " ")).count
        let clauses = max(1, trimmed.split(whereSeparator: { ",.;:".contains($0) }).count)

        func has(_ needles: [String]) -> Bool { needles.contains { lower.contains($0) } }

        let relevance = trimmed.isEmpty ? 0.1 : min(1.0, 0.55 + Double(min(wordCount, 8)) * 0.05)
        let coherence = trimmed.isEmpty ? 0.2 : 0.9
        let detail = min(1.0, Double(wordCount) / 40.0)
        let semantic = min(1.0, Double(distinctWords) / 12.0)
        let categories = min(4, max(1, distinctWords / 4))
        let emotional = has(["love", "fear", "grief", "hope", "ache", "memory", "lonely", "warm", "miss", "tender"]) ? 0.7 : 0.2
        let symbol = has(["like", " as ", "becomes", "mirror", "shadow", "door", "tide", "echo", "thread"]) ? 0.6 : 0.2
        let risk = trimmed.count > 60 ? 0.6 : (trimmed.count > 25 ? 0.4 : 0.25)
        let effort = min(1.0, Double(wordCount) / 25.0 + 0.3)

        return ScoringInput(
            promptID: promptID, modality: modality,
            relevance: relevance, functionalValidity: 1.0, coherence: coherence,
            semanticDistance: semantic, rarityPercentile: rarity?.percentile,
            ideaCount: clauses, distinctCategoryCount: categories, detail: detail,
            emotionalCharge: emotional, symbolism: symbol, riskSignal: risk,
            reframingDetected: false, constraintSatisfied: !trimmed.isEmpty, effort: effort
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
