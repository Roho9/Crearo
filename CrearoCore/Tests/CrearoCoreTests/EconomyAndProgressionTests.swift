import XCTest
@testable import CrearoCore

final class EconomyTests: XCTestCase {
    func testEarnAndSpend() throws {
        var wallet = ResourceWallet([.embers: 10])
        wallet.earn(.embers, 5)
        XCTAssertEqual(wallet[.embers], 15)
        try wallet.spend([ResourceAmount(.embers, 12)])
        XCTAssertEqual(wallet[.embers], 3)
    }

    func testSpendingMoreThanHeldThrowsAndDoesNotMutate() {
        var wallet = ResourceWallet([.embers: 3])
        XCTAssertThrowsError(try wallet.spend([ResourceAmount(.embers, 99)])) { error in
            guard case EconomyError.insufficientResources(let shortfall) = error else {
                return XCTFail("wrong error")
            }
            XCTAssertEqual(shortfall.first?.amount, 96)
        }
        XCTAssertEqual(wallet[.embers], 3, "a failed spend must not change the wallet")
    }

    func testCanAffordMultiResource() {
        let wallet = ResourceWallet([.embers: 5, .musefire: 2])
        XCTAssertTrue(wallet.canAfford([ResourceAmount(.embers, 5), ResourceAmount(.musefire, 1)]))
        XCTAssertFalse(wallet.canAfford([ResourceAmount(.embers, 5), ResourceAmount(.dreamsteel, 1)]))
    }

    func testWalletNeverGoesNegative() {
        var wallet = ResourceWallet()
        wallet[.embers] = -50
        XCTAssertEqual(wallet[.embers], 0)
    }

    func testWalletCodableRoundTrip() throws {
        let wallet = ResourceWallet([.embers: 7, .essence: 3, .hollowSparks: 1])
        let data = try WorldStateCodec.encoder().encode(wallet)
        let decoded = try WorldStateCodec.decoder().decode(ResourceWallet.self, from: data)
        XCTAssertEqual(wallet, decoded)
    }

    func testWorldStateRoundTrip() throws {
        let state = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        let data = try WorldStateCodec.data(from: state)
        let decoded = try WorldStateCodec.state(from: data)
        XCTAssertEqual(decoded.character.name, "Wren")
        XCTAssertEqual(decoded.companion.name, "Kindle")
        XCTAssertEqual(decoded.unlockedRegions, [.lastlight, .mirrorwood])
    }
}

final class ProgressionTests: XCTestCase {
    private func profile(_ dims: [CreativeDimension: Double], modalities: [Modality: Int] = [:]) -> CreativeProfile {
        var p = CreativeProfile()
        for (d, v) in dims { p.estimates[d.rawValue] = DimensionEstimate(value: v, samples: 5) }
        for (m, c) in modalities { p.modalityCounts[m.rawValue] = c }
        return p
    }

    func testRegionUnlocksWithFlexibility() {
        let p = profile([.flexibility: 0.5])
        let unlocked = RegionGates.unlockedRegions(for: p)
        XCTAssertTrue(unlocked.contains(.hushMire))
        XCTAssertFalse(unlocked.contains(.greymarch), "risk gate not yet met")
    }

    func testEndgameUnlocksOnlyWithBroadRange() {
        let narrow = profile([.flexibility: 0.9])
        XCTAssertFalse(RegionGates.unlockedRegions(for: narrow).contains(.theUnwritten))
        let broad = profile(Dictionary(uniqueKeysWithValues: CreativeDimension.allCases.map { ($0, 0.6) }))
        XCTAssertTrue(RegionGates.unlockedRegions(for: broad).contains(.theUnwritten))
    }

    func testClassEmergenceFromDrawing() {
        let p = profile([.elaboration: 0.8], modalities: [.drawing: 10])
        XCTAssertEqual(ClassEmergence().recognizedClass(from: p), .inkbinder)
    }

    func testWeakestDimensionsSeedBoss() {
        let p = profile([.originality: 0.1, .flexibility: 0.15, .usefulness: 0.9,
                         .elaboration: 0.8, .emotionalExpression: 0.8, .riskTaking: 0.8,
                         .symbolicThinking: 0.7, .fluency: 0.7])
        let boss = BossComposer().compose(from: p, namedCreations: ["Honeyfang", "Honeyfang", "Honeyfang"])
        let targeted = Set(boss.phases.map { $0.targetsDimension })
        XCTAssertTrue(targeted.contains(.originality))
        XCTAssertTrue(targeted.contains(.flexibility))
        XCTAssertTrue(boss.taunt.contains("Honeyfang"))
    }

    func testAbsenceDecayRespectsGracePeriodAndIsReversible() {
        let decay = DecayService(graceDays: 4, fullCorruptionDays: 30)
        XCTAssertEqual(decay.absenceSeverity(elapsed: 2 * 86_400), 0, "within grace = no decay")
        XCTAssertGreaterThan(decay.absenceSeverity(elapsed: 20 * 86_400), 0)

        var state = WorldState.newGame(characterName: "A", companionName: "B")
        state.creations = [BalanceEngine().fallbackCreation(region: .mirrorwood)]
        state.home.lastMeaningfulActivity = Date().addingTimeInterval(-20 * 86_400)
        let decayed = decay.applyAbsence(to: state, now: Date())
        XCTAssertGreaterThan(decayed.home.corruptionLevel, 0)
        XCTAssertLessThan(decayed.companion.brightness, 1.0)

        // A good creative act fully restores (creative quest, not a purchase; GDD §32).
        let goodScore = CreativityScore(gate: 0.9, dimensions: .uniform)
        let restored = decay.restore(decayed.creations[0], with: goodScore)
        XCTAssertEqual(restored.decay, .pristine)
    }
}
