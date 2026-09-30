import Foundation

/// Resolves an evaluated challenge against the current save before any rewards are applied.
/// Callers may reward only `.cleared`; retries can update a personal best but never consume a day.
public enum ChallengeAttemptDisposition: Equatable, Sendable {
    case unavailable
    case retry
    case cleared
}

public enum ChallengeProgression {
    public static func canAttempt(_ world: WorldState, level: Int, day: String,
                                  currentDay: String) -> Bool {
        level == world.level && day == currentDay && world.lastChallengeDay != day
    }

    /// Synchronous commit of the progression fields. A stale, repeated or failed answer cannot
    /// advance, append a story beat, add lifetime points or increase the streak.
    @discardableResult
    public static func record(into world: inout WorldState, level: Int, day: String,
                              currentDay: String, score: Int,
                              storyBeat: String) -> ChallengeAttemptDisposition {
        guard canAttempt(world, level: level, day: day, currentDay: currentDay) else {
            return .unavailable
        }
        let boundedScore = min(100, max(0, score))
        world.bestScore = max(world.bestScore, boundedScore)
        guard LevelGate.passes(score: boundedScore, level: level) else { return .retry }

        world.streak = isConsecutive(world.lastChallengeDay, before: day) ? world.streak + 1 : 1
        world.lastChallengeDay = day
        world.level += 1
        world.totalPoints += boundedScore
        world.storyLog.append(storyBeat)
        return .cleared
    }

    private static func isConsecutive(_ previous: String?, before day: String) -> Bool {
        guard let previous else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let prior = formatter.date(from: previous), let next = formatter.date(from: day) else {
            return false
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.dateComponents([.day], from: prior, to: next).day == 1
    }
}

/// Compatibility adapter between the six judged rubric criteria and the existing eight-axis
/// world profile. It uses the same assessment as the visible grade, never a second lexical score.
public enum ChallengeAssessment {
    public static func worldScore(from raw: RubricScores) -> CreativityScore {
        func unit(_ value: Double) -> Double { value.isFinite ? clamp01(value) : 0 }
        let fit = unit(raw.fit)
        var dimensions = DimensionScores(
            originality: unit(raw.originality),
            // The API does not separately assess fluency or flexibility. These are compatibility
            // proxies for the legacy profile, not measurements of idea/category counts.
            fluency: unit(raw.elaboration),
            flexibility: unit(raw.depth),
            elaboration: unit(raw.elaboration),
            usefulness: fit,
            riskTaking: unit(raw.boldness),
            emotionalExpression: unit(raw.delight),
            symbolicThinking: unit(raw.depth)
        )
        for dimension in CreativeDimension.allCases where dimension != .usefulness {
            dimensions[dimension] *= fit
        }
        return CreativityScore(gate: fit, dimensions: dimensions,
                               constraintSatisfied: fit >= 0.5,
                               effort: unit(raw.elaboration))
    }
}
