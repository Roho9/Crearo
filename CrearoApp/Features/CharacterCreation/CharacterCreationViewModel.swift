import Foundation
import Observation
import CrearoCore

// The opening sequence is character creation AND the first hidden creativity baseline (GDD §10, §12–13).

@MainActor
@Observable
final class CharacterCreationViewModel {
    var characterName = ""
    var companionName = ""
    var symbolicObject = ""   // "one object that means something"
    var firstMark = ""        // the mark "so this place knows you live here"
    var backstory = ""        // "What did you make, once, that you were proud of?"
    var isSubmitting = false

    var canBegin: Bool { !characterName.trimmingCharacters(in: .whitespaces).isEmpty }

    func begin(app: AppState) async {
        isSubmitting = true
        defer { isSubmitting = false }

        let cName = characterName.trimmingCharacters(in: .whitespaces).isEmpty ? "Wren" : characterName
        let comp = companionName.trimmingCharacters(in: .whitespaces).isEmpty ? "Kindle" : companionName
        await app.startNewGame(characterName: cName, companionName: comp)

        // Persist the symbolic object + backstory onto the character (seeds NPC references, GDD §12).
        if var ws = app.worldState {
            ws.character.symbolicObjectName = symbolicObject.isEmpty ? nil : symbolicObject
            ws.character.backstory = backstory.isEmpty ? nil : backstory
            app.worldState = ws
        }

        // The first mark becomes the first permanent creation + the first baseline sample (GDD §10).
        if !firstMark.trimmingCharacters(in: .whitespaces).isEmpty {
            await app.forge(ideaText: firstMark, modality: .drawing)
        }
    }
}
