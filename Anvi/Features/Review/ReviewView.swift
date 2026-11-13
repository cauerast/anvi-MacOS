import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @Bindable var session: ReviewSession

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if let entry = session.current {
                cardArea(entry)
                Divider()
                answerBar
            } else {
                finished
            }
        }
        .navigationTitle(session.title)
        .background(.background)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                model.endStudy()
            } label: {
                Label("End", systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
            .help(Text("End session (Esc)"))

            Spacer()

            if !session.isFinished {
                QueueCounts(
                    new: session.queue.new.count,
                    learning: session.queue.learning.count,
                    review: session.queue.reviews.count
                )
            }

            Button {
                session.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!session.canUndo)
            .help(Text("Undo last answer (⌘Z)"))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Card

    private func cardArea(_ entry: StudyQueue.Entry) -> some View {
        let files = model.store.files
        let card = entry.card
        return ScrollView {
            VStack(spacing: 28) {
                CardFaceView(text: card.front, imageURL: card.frontImage.map(files.mediaURL), font: .system(size: 38, weight: .medium))
                if session.isRevealed {
                    Divider()
                    CardFaceView(text: card.back, imageURL: card.backImage.map(files.mediaURL))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if !card.tags.isEmpty {
                    Text(card.tags.map { "#\($0)" }.joined(separator: "  "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(40)
            .frame(maxWidth: Theme.cardMaxWidth)
            .frame(maxWidth: .infinity, minHeight: 360)
        }
        .animation(.easeOut(duration: 0.18), value: session.isRevealed)
        .id(card.id)
    }

    // MARK: Answers

    private var answerBar: some View {
        HStack(spacing: 12) {
            if session.isRevealed {
                ForEach(Array(ReviewRating.allCases.enumerated()), id: \.element) { index, rating in
                    AnswerButton(
                        rating: rating,
                        interval: session.intervals[rating].map { IntervalText.string(until: $0) } ?? "",
                        shortcut: KeyEquivalent(Character("\(index + 1)"))
                    ) {
                        session.answer(rating)
                    }
                }
            } else {
                Button {
                    session.reveal()
                } label: {
                    Text("Show Answer")
                        .frame(maxWidth: 320)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.space, modifiers: [])
                .help(Text("Space"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 92)
    }

    // MARK: Finished

    @ViewBuilder
    private var finished: some View {
        if let next = session.nextCardDate {
            EmptyStateView(
                title: "Take a short break",
                message: "Cards you are still learning come back \(next.formatted(.relative(presentation: .named)))."
            ) {
                Button("Back to Library") { model.endStudy() }
            }
            .task(id: next) {
                let delay = max(1, next.timeIntervalSinceNow - StudyQueue.learnAheadLimit + 1)
                try? await Task.sleep(for: .seconds(delay))
                session.refresh()
            }
        } else {
            EmptyStateView(
                title: "All done for now",
                message: "You answered \(session.answeredCount) cards. Come back tomorrow to keep your streak going."
            ) {
                Button("Back to Library") { model.endStudy() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct AnswerButton: View {
    var rating: ReviewRating
    var interval: String
    var shortcut: KeyEquivalent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.color(for: rating))
                Text(interval)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 140)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .keyboardShortcut(shortcut, modifiers: [])
        .help(Text("Key \(String(shortcut.character))"))
    }

    private var title: LocalizedStringKey {
        switch rating {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}
