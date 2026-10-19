import Foundation

public enum ContraptionWritingState: String, Codable, Sendable {
    case empty, tooShort, tooLong, complete
}

public struct ContraptionWritingStatus: Codable, Equatable, Sendable {
    public let state: ContraptionWritingState
    public let wordCount: Int
    public let characterCount: Int
    public var isComplete: Bool { state == .complete }
    public var message: String {
        switch state {
        case .empty: return "Give your invention one short explanation: at least 8 words and 24 characters."
        case .tooShort: return "Add a little explanation: at least 8 words and 24 characters. More words do not earn more points."
        case .tooLong: return "Keep the explanation within 600 characters. Your text has been kept in full so you can edit it."
        case .complete: return "Explanation complete. Its meaning and originality are not automatically judged."
        }
    }
}

public struct ContraptionRuleCheck: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let isSatisfied: Bool
    public let actual: Int?
    public let required: Int?
    public let capability: ContraptionCapability?
}

public struct ContraptionScoreBreakdown: Codable, Equatable, Sendable {
    /// Up to 70 points for the fraction of authored mechanical requirements and constraints met.
    public let mechanicalFit: Int
    /// Up to 20 points for coverage of the five capabilities and the three objects' primary families.
    public let partRange: Int
    /// Exactly 10 points for meeting the short explanation's length requirements; never for verbosity.
    public let explanationCompletion: Int
    public var total: Int { min(100, max(0, mechanicalFit + partRange + explanationCompletion)) }
}

public struct ContraptionEvaluation: Codable, Equatable, Sendable {
    public let passed: Bool
    public let score: Int
    public let capabilities: ContraptionCapabilities
    public let capabilityChecks: [ContraptionRuleCheck]
    public let constraintChecks: [ContraptionRuleCheck]
    public let writingStatus: ContraptionWritingStatus
    public let recipeIsComplete: Bool
    public let distinctParts: Bool
    public let breakdown: ContraptionScoreBreakdown
    public let feedback: String
    public let nextStep: String
    public var scoreLabel: String { "Local puzzle score" }
    public var resultTitle: String { passed ? "It works." : "Back to the workbench." }
    public var checks: [ContraptionRuleCheck] { capabilityChecks + constraintChecks }
    public var scoreExplanation: String {
        "Mechanical fit \(breakdown.mechanicalFit)/70 · Part range \(breakdown.partRange)/20 · Explanation \(breakdown.explanationCompletion)/10. Clearing requires every rule and a complete explanation. This is not a validated creativity rating."
    }
}

/// A deterministic toy construction system, not a physics proof or a semantic writing judge.
/// The on-screen capability numbers and slot multipliers are the complete mechanical rules.
/// There is no hidden keyword matching, LLM grade, global originality claim, or score-by-length.
public struct ContraptionEvaluator: Sendable {
    public static let minimumWords = 8
    public static let minimumCharacters = 24
    public static let maximumCharacters = 600
    public init() {}

    public func writingStatus(for explanation: String) -> ContraptionWritingStatus {
        // Count the original string and reject the entire oversized submission. Never truncate it.
        let characterCount = explanation.count
        let wordCount = explanation.split { !$0.isLetter && !$0.isNumber }.count
        let state: ContraptionWritingState
        if characterCount > Self.maximumCharacters { state = .tooLong }
        else if explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { state = .empty }
        else if characterCount < Self.minimumCharacters || wordCount < Self.minimumWords { state = .tooShort }
        else { state = .complete }
        return .init(state: state, wordCount: wordCount, characterCount: characterCount)
    }

    public func evaluate(challenge: ContraptionChallenge, recipe: ContraptionRecipe,
                         explanation: String) -> ContraptionEvaluation {
        let capabilities = recipe.capabilities
        let writing = writingStatus(for: explanation)
        let capabilityChecks = challenge.requirements.map { requirement in
            let actual = capabilities[requirement.capability]
            return ContraptionRuleCheck(id: requirement.capability.rawValue, title: requirement.text,
                detail: "\(requirement.capability.title): \(actual) of \(requirement.minimum) needed.",
                isSatisfied: actual >= requirement.minimum, actual: actual, required: requirement.minimum,
                capability: requirement.capability)
        }
        let constraintChecks = challenge.constraints.enumerated().map { index, constraint in
            let satisfied: Bool
            let actual: Int?
            let required: Int?
            let capability: ContraptionCapability?
            switch constraint {
            case let .excludedPart(part, _):
                satisfied = !recipe.parts.contains(part); actual = nil; required = nil; capability = nil
            case let .maximum(key, value, _):
                satisfied = capabilities[key] <= value; actual = capabilities[key]; required = value; capability = key
            case let .excludedSlot(part, slot, _):
                satisfied = recipe[slot] != part; actual = nil; required = nil; capability = nil
            }
            return ContraptionRuleCheck(id: "constraint-\(index)", title: constraint.text,
                detail: satisfied ? "Constraint met." : "Change the arrangement to meet this constraint.",
                isSatisfied: satisfied, actual: actual, required: required, capability: capability)
        }
        let soundRecipe = recipe.isComplete && recipe.hasDistinctParts
        let allRules = capabilityChecks.allSatisfy(\.isSatisfied) && constraintChecks.allSatisfy(\.isSatisfied)
        let passed = soundRecipe && allRules && writing.isComplete

        let requirementFractions = challenge.requirements.map {
            min(1, max(0, Double(capabilities[$0.capability]) / Double($0.minimum)))
        }
        let constraintFractions = constraintChecks.map { $0.isSatisfied ? 1.0 : 0.0 }
        let fractions = requirementFractions + constraintFractions
        let fit = soundRecipe && !fractions.isEmpty
            ? Int((70 * fractions.reduce(0, +) / Double(fractions.count)).rounded()) : 0
        let families = Set(recipe.parts.map(\.primaryCapability)).count
        let covered = ContraptionCapability.allCases.filter { key in recipe.parts.contains { $0.capabilities[key] > 0 } }.count
        let range = soundRecipe ? covered * 2 + (families * 10 / 3) : 0
        let breakdown = ContraptionScoreBreakdown(mechanicalFit: fit, partRange: min(20, range),
                                                 explanationCompletion: writing.isComplete ? 10 : 0)
        let feedback: String
        let nextStep: String
        if !recipe.isComplete {
            feedback = "Give Anchor, Engine, and Twist one object each."
            nextStep = "Tap an empty slot, then choose an object. The anchor doubles reach and care; the engine doubles lift and motion; the twist doubles signal."
        } else if !recipe.hasDistinctParts {
            feedback = "There is only one of each object in this workshop."
            nextStep = "Use three different objects. Move or swap an object between roles to change what it contributes."
        } else if let index = constraintChecks.firstIndex(where: { !$0.isSatisfied }) {
            feedback = challenge.constraints[index].text
            nextStep = Self.constraintTip(challenge.constraints[index])
        } else if let missing = challenge.requirements.filter({ capabilities[$0.capability] < $0.minimum })
            .min(by: { Double(capabilities[$0.capability]) / Double($0.minimum) < Double(capabilities[$1.capability]) / Double($1.minimum) }) {
            feedback = "\(missing.capability.title) is \(capabilities[missing.capability])/\(missing.minimum). The contraption needs a little more."
            nextStep = Self.tip(for: missing.capability)
        } else if !writing.isComplete {
            feedback = "The objects meet every mechanical rule. Your explanation needs one adjustment."
            nextStep = writing.message
        } else {
            feedback = "Your arrangement meets every mechanical rule, and your short explanation is complete."
            nextStep = "Try a different engine or swap two roles on a replay. Your score describes these visible puzzle rules; it does not measure how original your idea is."
        }
        return .init(passed: passed, score: breakdown.total, capabilities: capabilities,
                     capabilityChecks: capabilityChecks, constraintChecks: constraintChecks, writingStatus: writing,
                     recipeIsComplete: recipe.isComplete, distinctParts: recipe.hasDistinctParts,
                     breakdown: breakdown, feedback: feedback, nextStep: nextStep)
    }

    private static func tip(for capability: ContraptionCapability) -> String {
        switch capability {
        case .lift: return "Try a fan, spring, or sail in the engine, where lift doubles. Check the station's constraints before choosing."
        case .reach: return "Try a sail or mirror in the anchor, where reach doubles. Other objects still add their own reach."
        case .signal: return "Try a bell or mirror in the twist, where signal doubles. The other two objects can add signal too."
        case .motion: return "A spring, magnet, or wheel in the engine doubles its movement. Check the station's constraints before choosing."
        case .care: return "A seed in the anchor doubles care. A sail, bell, or wheel can add more care from another slot."
        }
    }
    private static func constraintTip(_ constraint: ContraptionConstraint) -> String {
        switch constraint {
        case let .excludedPart(part, _):
            return "Replace the \(part.title.lowercased()) with another object, then check the capability totals again. More than one combination can work."
        case let .maximum(capability, value, _):
            let role = capability == .signal ? "twist" : capability == .motion || capability == .lift ? "engine" : "anchor"
            return "Keep \(capability.title.lowercased()) at \(value) or below. Move a high-\(capability.rawValue) object out of the \(role), or choose an object with less \(capability.rawValue)."
        case let .excludedSlot(part, slot, _):
            return "Move the \(part.title.lowercased()) out of \(slot.title.lowercased()), or replace it. Swapping roles changes the totals."
        }
    }
}
