import Foundation
import Observation
import CrearoCore

@MainActor
@Observable
final class GrowthReportViewModel {
    var boss: PersonalizedBoss?
    var showShadow = false

    /// Poetic, NON-numeric names for the dimensions in the "Sky of Makings" (GDD §43).
    static let starName: [CreativeDimension: String] = [
        .originality: "Newness",
        .fluency: "Flow",
        .flexibility: "Many Roads",
        .elaboration: "Depth",
        .usefulness: "Use",
        .riskTaking: "Daring",
        .emotionalExpression: "Feeling",
        .symbolicThinking: "Symbol"
    ]

    func revealShadow(app: AppState) {
        boss = app.previewFinalBoss()
        showShadow = boss != nil
    }
}
