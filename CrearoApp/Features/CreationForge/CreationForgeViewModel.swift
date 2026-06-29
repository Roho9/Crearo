import Foundation
import Observation
import CrearoCore

@MainActor
@Observable
final class CreationForgeViewModel {
    var ideaText = ""
    var modality: Modality = .writing

    var canForge: Bool { !ideaText.trimmingCharacters(in: .whitespaces).isEmpty }

    func forge(app: AppState) async {
        guard canForge else { return }
        await app.forge(ideaText: ideaText, modality: modality)
        ideaText = ""
    }
}
