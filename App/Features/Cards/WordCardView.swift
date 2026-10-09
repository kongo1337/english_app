import StudyCore
import SwiftUI

/// One flash card: the two faces, the top bar (level, menu, speaker), the swipe hints.
struct WordCardView<Model: FlashCardModel>: View {
    let model: Model
    let word: Word

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 40
    @ScaledMetric(relativeTo: .title) private var translationSize: CGFloat = 32

    var body: some View {
        ZStack {
            CardSurface()
            faces
            topBar
            swipeHints
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .onTapGesture { model.flip() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card")
        .accessibilityAction(named: "Перевернуть") { model.flip() }
        .accessibilityAction(named: "Озвучить") { model.speakLemma() }
        .accessibilityActions {
            ForEach(model.decisionActions) { action in
                Button(action.title) { action.run() }
            }
        }
    }

    // MARK: Faces

    @ViewBuilder private var faces: some View {
        if reduceMotion {
            ZStack {
                if model.isFlipped { face(isBack: true) } else { face(isBack: false) }
            }
            .animation(.easeInOut(duration: 0.15), value: model.isFlipped)
        } else {
            FlipView(isFlipped: model.isFlipped) {
                face(isBack: false)
            } back: {
                face(isBack: true)
            }
        }
    }

    private func face(isBack: Bool) -> some View {
        let side = isBack ? model.backSide : model.frontSide
        return VStack(spacing: Theme.Spacing.medium) {
            Spacer(minLength: 0)
            Group {
                switch side {
                case .english: englishContent(isBack: isBack)
                case .russian: russianContent(isBack: isBack)
                }
            }
            Spacer(minLength: 0)
            if !isBack { flipButton }
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.top, 60)
        .padding(.bottom, Theme.Spacing.large)
    }

    private func englishContent(isBack: Bool) -> some View {
        VStack(spacing: 10) {
            Text(word.lemma)
                .font(.system(size: wordSize, weight: .bold, design: .serif))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .accessibilityIdentifier(isBack ? "cardAnswer" : "cardWord")
            if let ipa = word.ipa {
                Text(ipa)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            if isBack { example }
        }
    }

    private func russianContent(isBack: Bool) -> some View {
        VStack(spacing: 8) {
            Text(word.primaryTranslation)
                .font(.system(size: translationSize, weight: .bold, design: .serif))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier(isBack ? "cardAnswer" : "cardWord")
            ForEach(Array(word.translations.dropFirst().enumerated()), id: \.offset) { _, extra in
                Text(extra)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if isBack { example }
        }
    }

    @ViewBuilder private var example: some View {
        if let english = word.exampleEN {
            VStack(spacing: 6) {
                Capsule().fill(Theme.border).frame(width: 40, height: 3).padding(.vertical, 6)
                Button { model.speakExample() } label: {
                    Text(ExampleHighlighter.attributed(english, lemma: word.lemma))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Озвучить пример")
                if let russian = word.exampleRU {
                    Text(russian)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var flipButton: some View {
        Button { model.flip() } label: {
            Text(model.direction == .enToRu ? "Перевод" : "Слово")
                .font(Theme.Typography.bodyEmphasized)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 32)
                .frame(minHeight: 48)
                .background(Theme.surfaceMuted, in: Capsule())
                .overlay { Capsule().strokeBorder(Theme.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("flipButton")
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack {
            HStack(spacing: 8) {
                LevelChip(level: word.cefr)
                if !word.headerDetail.isEmpty {
                    Text(word.headerDetail)
                        .accessibilityLabel(word.spokenHeaderDetail)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if model.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.warning)
                        .accessibilityLabel("В избранном")
                }
                menu
                if model.englishVisible { speakerButton }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private var menu: some View {
        Menu {
            ForEach(model.menuActions) { action in
                Button { action.run() } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Ещё действия")
        .accessibilityIdentifier("cardMenu")
    }

    private var speakerButton: some View {
        Button { model.speakLemma() } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(.title3))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Озвучить")
        .accessibilityIdentifier("speakButton")
    }

    // MARK: Swipe hints

    private var swipeHints: some View {
        let width = model.dragOffset(for: word.id).width
        let progress = SwipeDecision.hintProgress(forWidth: width)
        return ZStack {
            hint(model.rightHint, alignment: .topLeading, tilt: -10)
                .opacity(width > 0 ? progress : 0)
            hint(model.leftHint, alignment: .topTrailing, tilt: 10)
                .opacity(width < 0 ? progress : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hint(_ hint: SwipeHint, alignment: Alignment, tilt: Double) -> some View {
        let color = hint.color
        return Text(hint.text)
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 3) }
            .rotationEffect(.degrees(tilt))
            .padding(.top, 72)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}
