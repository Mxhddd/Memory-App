import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import MemoryCore

// Retrieval practice from the Home Screen and Lock Screen: a due Vault card, recalled before
// revealing, then graded right there (FSRS-6, same as the Vault).

struct FlashcardEntry: TimelineEntry {
    let date: Date
    let cardID: UUID?
    let prompt: String
    let answer: String
    let deck: String
    let revealed: Bool
    let dueCount: Int
    let theme: Theme

    static func sample(theme: Theme = .midnightRaccoon) -> FlashcardEntry {
        FlashcardEntry(date: Date(), cardID: nil, prompt: "Capital of Kazakhstan?", answer: "Astana", deck: "Capitals",
                       revealed: false, dueCount: 6, theme: theme)
    }
}

struct FlashcardProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlashcardEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping (FlashcardEntry) -> Void) {
        completion(context.isPreview ? .sample() : load(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlashcardEntry>) -> Void) {
        let now = Date()
        // Cards fall due over time; look again in 30 minutes.
        completion(Timeline(entries: [load(now: now)], policy: .after(now.addingTimeInterval(1800))))
    }

    private func load(now: Date) -> FlashcardEntry {
        let theme = SharedStore.readSnapshot()?.theme ?? .midnightRaccoon
        let context = ModelContext(Store.container)
        let due = VaultGrading.dueCount(in: context, now: now)
        guard let card = VaultGrading.nextDue(in: context, now: now) else {
            return FlashcardEntry(date: now, cardID: nil, prompt: "", answer: "", deck: "", revealed: false, dueCount: 0, theme: theme)
        }
        return FlashcardEntry(date: now, cardID: card.id, prompt: card.prompt, answer: card.answer, deck: card.deck,
                              revealed: FlashcardState.revealedID == card.id.uuidString, dueCount: due, theme: theme)
    }
}

struct FlashcardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlashcardWidget", provider: FlashcardProvider()) { entry in
            FlashcardView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: entry.theme) }
        }
        .configurationDisplayName("Recall a card")
        .description("A due Vault card. Think of the answer, reveal it, then grade it — without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct FlashcardView: View {
    let entry: FlashcardEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let theme = entry.theme
        if let id = entry.cardID {
            if family == .accessoryRectangular {
                lockScreen(id)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.deck.uppercased()).font(.caption2.weight(.heavy)).foregroundStyle(theme.ornament).lineLimit(1)
                        Spacer()
                        Text("\(entry.dueCount) due").font(.caption2.weight(.semibold)).foregroundStyle(theme.secondaryText)
                    }
                    Text(entry.prompt)
                        .font(family == .systemMedium ? .headline : .subheadline.weight(.bold))
                        .foregroundStyle(theme.text)
                        .lineLimit(family == .systemMedium ? 3 : 4)
                        .minimumScaleFactor(0.75)
                    if entry.revealed {
                        Text(entry.answer).font(.subheadline.weight(.semibold)).foregroundStyle(theme.primary).lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer(minLength: 0)
                    if entry.revealed {
                        HStack(spacing: 6) {
                            gradeButton(id, .again, "Again", theme.danger)
                            gradeButton(id, .good, "Got it", theme.success)
                        }
                    } else {
                        Button(intent: RevealCardIntent(cardID: id)) {
                            Label("Show answer", systemImage: "eye.fill").font(.caption.weight(.bold)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primary)
                    }
                }
                .widgetURL(WidgetLinks.card(id))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(theme.success)
                Text("No cards due").font(.headline).foregroundStyle(theme.text)
                Text("Add anything you want to keep in the Vault.").font(.caption).foregroundStyle(theme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(WidgetLinks.review)
        }
    }

    private func gradeButton(_ id: UUID, _ rating: Rating, _ title: String, _ tint: Color) -> some View {
        Button(intent: GradeCardIntent(cardID: id, rating: rating)) {
            Text(title).font(.caption.weight(.bold)).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }

    private func lockScreen(_ id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.prompt).font(.headline).lineLimit(2).widgetAccentable()
            if entry.revealed {
                HStack {
                    Text(entry.answer).font(.caption).lineLimit(1)
                    Spacer()
                    Button(intent: GradeCardIntent(cardID: id, rating: .good)) { Image(systemName: "checkmark") }
                    Button(intent: GradeCardIntent(cardID: id, rating: .again)) { Image(systemName: "arrow.uturn.left") }
                }
            } else {
                Button(intent: RevealCardIntent(cardID: id)) {
                    Label("Reveal · \(entry.dueCount) due", systemImage: "eye")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Reminders

struct RemindersWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RemindersWidget", provider: SnapshotProvider()) { entry in
            RemindersWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: entry.snapshot.theme) }
                .widgetURL(WidgetLinks.reminders)
        }
        .configurationDisplayName("Your reminders")
        .description("What's next, with a Done button.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct RemindersWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.snapshot
        let theme = s.theme
        let items = Array(s.reminders.prefix(family == .systemMedium ? 3 : 1))
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "bell.slash").foregroundStyle(theme.secondaryText)
                Text("Nothing coming up").font(.headline).foregroundStyle(theme.text)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if family == .accessoryRectangular, let r = items.first {
            HStack {
                VStack(alignment: .leading) {
                    Text(r.text).font(.headline).lineLimit(1).widgetAccentable()
                    Text(r.time, style: .time).font(.caption)
                }
                Spacer()
                if let id = UUID(uuidString: r.id) {
                    Button(intent: ReminderDoneIntent(reminderID: id)) { Image(systemName: "checkmark") }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Reminders", systemImage: "bell.fill").font(.caption.weight(.heavy)).foregroundStyle(theme.ornament)
                ForEach(items, id: \.id) { r in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.text).font(.subheadline.weight(.semibold)).foregroundStyle(theme.text).lineLimit(1)
                            Text(r.time, style: .time).font(.caption2).foregroundStyle(theme.secondaryText)
                        }
                        Spacer(minLength: 4)
                        if let id = UUID(uuidString: r.id) {
                            Button(intent: ReminderDoneIntent(reminderID: id)) {
                                Image(systemName: "checkmark").font(.caption.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.primary)
                            .accessibilityLabel("Done: \(r.text)")
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
