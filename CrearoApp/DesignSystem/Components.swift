import SwiftUI
import CrearoCore

// Reusable presentation pieces shared across features.

/// A made item, shown with its traditional + creative stats and decay (GDD §24, §36, §38).
struct CreationCard: View {
    let creation: Creation

    var body: some View {
        HearthCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(creation.name).font(Theme.heading).foregroundStyle(Theme.candle)
                    Spacer()
                    GlowTag(text: creation.type.rawValue.capitalized, color: Theme.magic)
                }
                if creation.effect.kind != .none {
                    Text(effectDescription).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
                }
                Text(creation.artDescriptor).font(.footnote.italic()).foregroundStyle(Theme.grey)

                // Creative properties (these are the ITEM's stats — fine to show; the player's hidden
                // creativity profile is what stays invisible).
                FlowChips(chips: [
                    ("Originality", creation.creative.originality),
                    ("Usefulness", creation.creative.usefulness),
                    ("Strangeness", creation.creative.strangeness),
                    ("Emotion", creation.creative.emotionalCharge),
                    ("Instability", creation.creative.instability)
                ])

                if creation.decay.health < 0.99 {
                    Label("Showing wear — restore it with a fresh making.", systemImage: "sparkle.magnifyingglass")
                        .font(.caption).foregroundStyle(Theme.grey)
                }
            }
        }
    }

    private var effectDescription: String {
        let e = creation.effect
        let pct = Int((e.magnitude * 100).rounded())
        switch e.kind {
        case .slow: return "Coats foes in resin — slows \(pct)% for \(Int(e.durationSec))s."
        case .fear: return "Shows enemies their own shadow — fear for \(Int(e.durationSec))s."
        case .shield: return "Raises a stubborn glass ward — absorbs \(pct)%."
        case .light: return "Sheds a light the fog cannot drink."
        case .burn: return "Sears with slow ember-light."
        case .charm: return "Soothes the corrupted into stillness."
        case .confuse: return "Bewilders the dull and the tidy."
        case .heal: return "Mends what the Grey has frayed."
        case .stealth: return "Wraps you in quiet."
        case .summon: return "Calls a small made thing to your side."
        case .reframe: return "Turns the battle's terms against itself."
        case .none: return ""
        }
    }
}

/// Tiny labeled 0...100 bars.
struct FlowChips: View {
    let chips: [(String, Double)]
    var body: some View {
        VStack(spacing: 4) {
            ForEach(chips, id: \.0) { chip in
                HStack(spacing: 8) {
                    Text(chip.0).font(.caption2).foregroundStyle(Theme.grey).frame(width: 80, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.night)
                            Capsule().fill(Theme.ember.opacity(0.8))
                                .frame(width: geo.size.width * min(1, max(0, chip.1 / 100)))
                        }
                    }.frame(height: 6)
                }
            }
        }
    }
}

/// The visible wallet (GDD §28).
struct ResourceWalletView: View {
    let wallet: ResourceWallet
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Resource.allCases, id: \.self) { r in
                    if wallet[r] > 0 {
                        GlowTag(text: "\(wallet[r]) \(r.displayName)", color: color(for: r))
                    }
                }
            }
        }
    }
    private func color(for r: Resource) -> Color {
        switch r {
        case .embers: return Theme.ember
        case .musefire: return Theme.candle
        case .essence: return Theme.moss
        case .hollowSparks: return Theme.magic
        default: return Theme.candle
        }
    }
}

/// Companion presence + their latest remark (GDD §18–19).
struct CompanionBanner: View {
    let name: String
    let line: String?
    let brightness: Double
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Theme.ember.opacity(0.3 + 0.7 * brightness))
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: "flame.fill").foregroundStyle(Theme.candle.opacity(0.4 + 0.6 * brightness)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Your companion" : name)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
                Text(line ?? "…").font(.callout.italic()).foregroundStyle(Theme.ink.opacity(0.9))
            }
        }
    }
}

/// A prophecy-style growth note (GDD §45) — myth, never metrics.
struct ProphecyBanner: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.stars.fill").foregroundStyle(Theme.magic)
            Text(text).font(.callout.italic()).foregroundStyle(Theme.candle)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.magic.opacity(0.1)))
    }
}
