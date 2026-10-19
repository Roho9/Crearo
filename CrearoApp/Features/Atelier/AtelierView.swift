import SwiftUI
import CrearoCore

/// A game surface first: the strange world, three construction roles, and a short written idea.
struct AtelierView: View {
    @State private var game = AtelierGameModel()
    @State private var showingIndex = false
    @State private var showingCollection = false
    @State private var showingHint = false
    @FocusState private var writingFocused: Bool
    @Environment(AppState.self) private var legacy
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 43

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                    world(height: max(300, min(430, geometry.size.height * 0.46)))
                    workbench
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AtelierStyle.ink)
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        }
        .background(AtelierStyle.ink.ignoresSafeArea())
        .foregroundStyle(AtelierStyle.chalk)
        .preferredColorScheme(.dark)
        .task { await game.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await game.flush() } }
        }
        .sensoryFeedback(.selection, trigger: game.recipe)
        .sheet(isPresented: $showingIndex) { stationIndex }
        .sheet(isPresented: $showingCollection) { collection }
        .sheet(isPresented: $game.showingResult) { resultSheet }
    }

    private var masthead: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("CREARO").font(AtelierStyle.headline(29)).tracking(-0.8)
                Text("ODDWORKS / VOL. 01").font(AtelierStyle.caption).foregroundStyle(AtelierStyle.acid)
            }
            Spacer(minLength: 8)
            Button { showingCollection = true } label: {
                Image(systemName: "square.stack.3d.up")
                    .font(.title3).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Your collection")
            .disabled(game.isTesting)
            Button { showingIndex = true } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.title3).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Choose a station")
            .disabled(game.isTesting)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 16)
    }

    private func world(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("STATION \(game.selectedLevel.formatted(.number.precision(.integerLength(2)))) / 06")
                        .font(AtelierStyle.caption).tracking(1).foregroundStyle(AtelierStyle.acid)
                    Text(game.challenge.title + ".")
                        .font(AtelierStyle.headline(titleSize)).tracking(-1.3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(game.challenge.subtitle)
                        .font(.subheadline).foregroundStyle(AtelierStyle.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22).padding(.bottom, 16)

            AtelierSceneView(chapter: game.selectedLevel, parts: game.orderedParts,
                             selectedSocket: ContraptionSlot.allCases.firstIndex(of: game.selectedSlot) ?? 0,
                             attemptID: game.attemptID, isTesting: game.isTesting,
                             didPass: game.testResult?.passed,
                             onSocketTap: { index in
                                 guard !game.isTesting, ContraptionSlot.allCases.indices.contains(index) else { return }
                                 game.selectedSlot = ContraptionSlot.allCases[index]
                             }, onTestFinished: { game.finishTest() })
                .frame(height: height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("A surreal construction station. Loop waits beside your three objects. Use the Anchor, Engine, and Twist buttons below to select a role.")

            HStack(alignment: .top, spacing: 14) {
                Text("THE\nPROBLEM").font(AtelierStyle.caption).foregroundStyle(AtelierStyle.acid)
                Text(game.challenge.goal)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AtelierStyle.surface)
        }
    }

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("01 / MAKE THE MACHINE").font(AtelierStyle.caption).tracking(0.7)
                Spacer()
                Button { showingHint.toggle() } label: {
                    Label(showingHint ? "Close hint" : "A nudge", systemImage: "lightbulb")
                        .font(.footnote).frame(minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(AtelierStyle.acid)
            }
            Text(game.challenge.brief).font(.callout).foregroundStyle(AtelierStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
            if showingHint {
                Text(game.challenge.hint).font(.callout).foregroundStyle(AtelierStyle.acid)
                    .fixedSize(horizontal: false, vertical: true)
            }
            roleRack
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.triangle.swap").accessibilityHidden(true)
                Text(game.selectedSlot.purpose + " Choose an object below. Choosing one already used swaps its role.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote).foregroundStyle(AtelierStyle.muted)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 69), spacing: 8)], spacing: 8) {
                ForEach(ContraptionPart.allCases) { part in partButton(part) }
            }
            if let part = game.recipe[game.selectedSlot] {
                VStack(alignment: .leading, spacing: 9) {
                    Text(part.detail).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Text(ContraptionCapability.allCases.map { "\($0.title) \(part.contribution(in: game.selectedSlot)[$0])" }.joined(separator: "  /  "))
                        .font(AtelierStyle.caption).foregroundStyle(AtelierStyle.acid)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            liveRules
            AtelierRule()
            VStack(alignment: .leading, spacing: 12) {
                Text("02 / EXPLAIN THE IMPOSSIBLE").font(AtelierStyle.caption).tracking(0.7)
                Text(game.challenge.writingPrompt).font(.callout).foregroundStyle(AtelierStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("The trick is…", text: Binding(get: { game.explanation }, set: { game.setExplanation($0) }), axis: .vertical)
                    .font(.body).lineLimit(3...7)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AtelierStyle.chalk)
                    .padding(16)
                    .background(AtelierStyle.surface)
                    .overlay(alignment: .leading) { Rectangle().fill(writingFocused ? AtelierStyle.acid : AtelierStyle.line).frame(width: 2) }
                    .focused($writingFocused)
                    .disabled(game.isTesting || !game.hasLoaded)
                    .accessibilityLabel("Explain your invention")
                HStack(alignment: .top, spacing: 12) {
                    Text(game.assessment.writingStatus.isComplete ? "READY TO TEST" : "8+ WORDS / 24+ CHARACTERS")
                    Spacer()
                    Text("\(game.explanation.count) / 600")
                }
                .font(AtelierStyle.caption)
                .foregroundStyle(game.assessment.writingStatus.state == .tooLong ? AtelierStyle.coral : AtelierStyle.muted)
                if game.assessment.writingStatus.state == .tooLong {
                    Text(game.assessment.writingStatus.message).font(.footnote).foregroundStyle(AtelierStyle.coral)
                }
            }
            if let notice = game.storageNotice {
                Text(notice).font(.footnote).foregroundStyle(AtelierStyle.coral)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(22)
        .disabled(!game.hasLoaded)
    }

    private var roleRack: some View {
        HStack(spacing: 0) {
            ForEach(Array(ContraptionSlot.allCases.enumerated()), id: \.element) { index, slot in
                Button {
                    guard !game.isTesting else { return }
                    game.selectedSlot = slot
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("0\(index + 1)")
                            Spacer(minLength: 2)
                            Image(systemName: game.recipe[slot] == nil ? "plus" : "checkmark")
                        }.font(AtelierStyle.caption)
                        Text(slot.title.uppercased()).font(.system(.caption, design: .monospaced).weight(.bold))
                        Text(game.recipe[slot]?.title ?? "Choose")
                            .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .foregroundStyle(game.selectedSlot == slot ? AtelierStyle.ink : AtelierStyle.chalk)
                    .background(game.selectedSlot == slot ? AtelierStyle.acid : AtelierStyle.surface)
                    .overlay { Rectangle().strokeBorder(AtelierStyle.line, lineWidth: 0.5) }
                }
                .buttonStyle(.plain)
                .disabled(game.isTesting)
                .accessibilityLabel("\(slot.title): \(game.recipe[slot]?.title ?? "empty"). \(slot.purpose)")
                .accessibilityAddTraits(game.selectedSlot == slot ? [.isSelected] : [])
            }
        }
    }

    private func partButton(_ part: ContraptionPart) -> some View {
        let selected = game.recipe[game.selectedSlot] == part
        let used = game.recipe.parts.contains(part)
        return Button { game.choose(part) } label: {
            VStack(spacing: 9) {
                Image(systemName: part.symbolName).font(.system(size: 27, weight: .medium))
                    .frame(height: 30).accessibilityHidden(true)
                Text(part.title.uppercased()).font(.system(.caption2, design: .monospaced).weight(.bold))
                Rectangle().fill(selected ? AtelierStyle.ink : used ? AtelierStyle.lilac : .clear).frame(height: 2)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .foregroundStyle(selected ? AtelierStyle.ink : AtelierStyle.chalk)
            .background(selected ? AtelierStyle.acid : AtelierStyle.surface)
        }
        .buttonStyle(.plain).disabled(game.isTesting)
        .accessibilityLabel("\(part.title). \(part.detail)\(used ? " Already placed; selecting moves or swaps it." : "")")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var liveRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THE RULES / VISIBLE, ALWAYS").font(AtelierStyle.caption).foregroundStyle(AtelierStyle.muted)
            ForEach(game.assessment.checks) { check in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: check.isSatisfied ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(check.isSatisfied ? AtelierStyle.acid : AtelierStyle.muted)
                        .accessibilityHidden(true)
                    Text(check.title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let actual = check.actual, let required = check.required {
                        Text("\(actual) / \(required)").monospacedDigit().foregroundStyle(AtelierStyle.muted)
                    }
                }
                .font(.footnote)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(check.title + ". " + check.detail)
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 9) {
            if game.isTesting {
                Button("Show the result", action: game.finishTest).buttonStyle(AtelierActionStyle())
            } else {
                Button {
                    writingFocused = false
                    game.test()
                } label: {
                    HStack {
                        Text(game.hasLoaded ? "LET IT HAPPEN" : "OPENING THE WORKSHOP…")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(AtelierActionStyle()).disabled(!game.canTest)
                .accessibilityHint("Test your arrangement against this station's visible rules.")
            }
            Text(game.isTesting ? "Loop is trying your invention." : "Build something odd. Explain the trick. See what happens.")
                .font(.caption).foregroundStyle(AtelierStyle.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 10)
        .background(AtelierStyle.ink)
        .overlay(alignment: .top) { AtelierRule() }
    }

    private var resultSheet: some View {
        ScrollView {
            if let result = game.result {
                VStack(alignment: .leading, spacing: 24) {
                    sheetHeading(result.passed ? "AN IMPOSSIBILITY,\nDELIVERED." : "A BEAUTIFUL\nWRONG TURN.", kicker: game.challenge.title.uppercased())
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(result.score)").font(AtelierStyle.headline(88)).foregroundStyle(result.passed ? AtelierStyle.acid : AtelierStyle.coral)
                        Text("/100").font(.title2).foregroundStyle(AtelierStyle.muted)
                        Spacer()
                        Text("LOCAL\nPUZZLE\nSCORE").font(AtelierStyle.caption)
                    }
                    Text(result.feedback).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    Text(result.nextStep).font(.body).foregroundStyle(AtelierStyle.muted)
                    AtelierRule()
                    ForEach(result.checks) { check in
                        Label(check.title, systemImage: check.isSatisfied ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.callout).foregroundStyle(check.isSatisfied ? AtelierStyle.acid : AtelierStyle.coral)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(result.scoreExplanation).font(.footnote).foregroundStyle(AtelierStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    AtelierRule()
                    Text("YOUR THEORY").font(AtelierStyle.caption).foregroundStyle(AtelierStyle.lilac)
                    Text(game.explanation).font(.body).textSelection(.enabled)
                    if result.passed {
                        ShareLink(item: game.shareText) { Label("Share this experiment", systemImage: "square.and.arrow.up") }
                            .buttonStyle(AtelierActionStyle(secondary: true))
                        Button(game.selectedLevel < game.save.currentLevel ? "NEXT STRANGE PLACE →" : "BACK TO THE WORKSHOP", action: game.nextStation)
                            .buttonStyle(AtelierActionStyle())
                        if game.save.isCampaignComplete {
                            Text("All six stations solved. Replay with different objects to find another route.")
                                .font(.callout).foregroundStyle(AtelierStyle.acid)
                        }
                    } else {
                        Button("CHANGE THE PLAN") { game.showingResult = false }
                            .buttonStyle(AtelierActionStyle())
                    }
                }.padding(24)
            }
        }
        .background(AtelierStyle.ink).foregroundStyle(AtelierStyle.chalk)
        .presentationDragIndicator(.visible).presentationDetents([.large])
    }

    private var stationIndex: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sheetHeading("SIX PLACES.\nNO NORMAL IDEAS.", kicker: "THE STATION INDEX")
                Text("\(game.completedCount) / 6 solved. Find more than one way through.")
                    .foregroundStyle(AtelierStyle.muted)
                ForEach(ContraptionChallenge.catalog) { challenge in
                    let unlocked = challenge.level <= game.save.currentLevel
                    Button {
                        game.select(challenge.level)
                        showingIndex = false
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            AtelierRule()
                            HStack(alignment: .top, spacing: 16) {
                                Text("0\(challenge.level)").font(AtelierStyle.headline(34)).foregroundStyle(unlocked ? AtelierStyle.acid : AtelierStyle.muted)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(challenge.title).font(.title3.weight(.semibold))
                                    Text(challenge.subtitle).font(.footnote).foregroundStyle(AtelierStyle.muted)
                                    if let score = game.save.bestScores[challenge.id] {
                                        Text("BEST \(score) / 100").font(AtelierStyle.caption).foregroundStyle(AtelierStyle.acid)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: unlocked ? "arrow.up.right" : "lock")
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain).disabled(!unlocked || game.isTesting)
                    .accessibilityLabel("Station \(challenge.level), \(challenge.title). \(unlocked ? "Available" : "Solve earlier stations to open")")
                }
                Button("KEEP MAKING") { showingIndex = false }.buttonStyle(AtelierActionStyle(secondary: true))
            }.padding(24)
        }
        .background(AtelierStyle.ink).foregroundStyle(AtelierStyle.chalk)
        .presentationDragIndicator(.visible)
    }

    private var collection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sheetHeading("PROOF OF\nODD THINKING.", kicker: "YOUR COLLECTION")
                if game.save.journal.isEmpty {
                    Text("Your first working invention belongs here. Solve a station to keep the objects, your theory, and its score.")
                        .font(.body).foregroundStyle(AtelierStyle.muted)
                }
                ForEach(game.save.journal.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 14) {
                        AtelierRule()
                        Text("STATION 0\(entry.level) / \(entry.score) POINTS").font(AtelierStyle.caption).foregroundStyle(AtelierStyle.acid)
                        Text(entry.title).font(AtelierStyle.headline(30))
                        Text(ContraptionSlot.allCases.map { "\($0.title): \(entry.recipe[$0]?.title ?? "—")" }.joined(separator: " / "))
                            .font(AtelierStyle.caption).foregroundStyle(AtelierStyle.lilac)
                        Text(entry.explanation).font(.body).textSelection(.enabled)
                        Text("Local puzzle score. Saved on your device.").font(.caption).foregroundStyle(AtelierStyle.muted)
                        if let challenge = ContraptionChallenge.challenge(id: entry.challengeID) {
                            ShareLink(item: AtelierGameModel.share(challenge: challenge, recipe: entry.recipe, explanation: entry.explanation, score: entry.score)) {
                                Label("Share the experiment", systemImage: "square.and.arrow.up")
                            }.buttonStyle(AtelierActionStyle(secondary: true))
                        }
                    }
                }
                if let previous = legacy.worldState, !previous.challengeHistory.isEmpty || !previous.storyLog.isEmpty {
                    AtelierRule()
                    Text("FROM YOUR EARLIER ADVENTURES").font(AtelierStyle.caption).foregroundStyle(AtelierStyle.lilac)
                    ForEach(Array(previous.storyLog.prefix(max(0, previous.storyLog.count - previous.challengeHistory.count)).enumerated()), id: \.offset) { _, beat in
                        Text(beat).font(.body).foregroundStyle(AtelierStyle.muted)
                    }
                    ForEach(previous.challengeHistory) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.title).font(.headline)
                            Text(entry.answer).font(.body).foregroundStyle(AtelierStyle.muted)
                            Text("\(entry.isPracticeEstimate ? "Practice estimate" : "Feedback score"): \(entry.score) / 100")
                                .font(.caption).foregroundStyle(AtelierStyle.lilac)
                        }
                    }
                }
                Button("BACK TO MAKING") { showingCollection = false }.buttonStyle(AtelierActionStyle())
            }.padding(24)
        }
        .background(AtelierStyle.ink).foregroundStyle(AtelierStyle.chalk)
        .presentationDragIndicator(.visible)
    }

    private func sheetHeading(_ title: String, kicker: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kicker).font(AtelierStyle.caption).foregroundStyle(AtelierStyle.acid)
            Text(title).font(AtelierStyle.headline(titleSize)).tracking(-1).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }.padding(.top, 16)
    }
}
