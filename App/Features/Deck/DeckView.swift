import SwiftUI
import SwiftData
import PhotosUI
import MemoryCore

/// Personal, functional content: people's names & faces, where things live, routines.
struct DeckView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \MemoryCard.createdAt, order: .reverse) private var cards: [MemoryCard]
    @State private var adding = false
    @State private var reviewing = false
    @State private var editing: MemoryCard?

    private var dueCount: Int { cards.filter { $0.due <= Date() }.count }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(dueCount > 0 ? "\(dueCount) card\(dueCount == 1 ? "" : "s") ready" : "All caught up")
                        .font(theme.display(26)).foregroundStyle(theme.text)
                    Text("Real-life memories practised at just the right moment (spaced retrieval). New cards are learned without guessing\(profile.errorlessNewCards ? " — errorless mode is on" : "").")
                        .font(theme.caption).foregroundStyle(theme.secondaryText)
                    Button("Review now") { reviewing = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(dueCount == 0)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(theme.surface)

            if cards.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        MascotView(mood: .idle, size: 90)
                        Text("Add something you want to remember: a neighbour's name, where the spare keys live, what to do when leaving the house.")
                            .font(theme.body).foregroundStyle(theme.text).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(theme.surface)
            }

            ForEach(CardKind.allCases) { kind in
                let group = cards.filter { $0.kind == kind }
                if !group.isEmpty {
                    Section(kind.label) {
                        ForEach(group) { card in
                            Button { editing = card } label: { CardRow(card: card) }
                                .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(group[i]) }
                            try? context.save()
                        }
                    }
                    .listRowBackground(theme.surface)
                }
            }

            Section("Memory tricks") {
                ForEach(StrategyTip.all) { tip in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                        Text(tip.body).font(theme.caption).foregroundStyle(theme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Practice")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    .accessibilityLabel("Add card")
            }
        }
        .sheet(isPresented: $adding) { CardEditor(card: nil).environment(\.theme, theme) }
        .sheet(item: $editing) { card in CardEditor(card: card).environment(\.theme, theme) }
        .fullScreenCover(isPresented: $reviewing) {
            NavigationStack { ReviewSessionView(profile: profile, countsForQuest: false) }.environment(\.theme, theme)
        }
    }
}

struct CardRow: View {
    @Environment(\.theme) private var theme
    let card: MemoryCard

    var body: some View {
        HStack(spacing: 12) {
            if let data = card.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: card.kind.icon).font(.title2).foregroundStyle(theme.primary).frame(width: 48, height: 48)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(card.prompt).font(theme.bodyEmphasis).foregroundStyle(theme.text).lineLimit(2)
                Text(card.isNew ? "New" : "Next: \(card.due.formatted(.relative(presentation: .named)))")
                    .font(theme.caption).foregroundStyle(theme.secondaryText)
            }
        }
        .frame(minHeight: theme.minTouch)
    }
}

struct CardEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let card: MemoryCard?

    @State private var kind: CardKind = .person
    @State private var prompt = ""
    @State private var answer = ""
    @State private var hint = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Data?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    ForEach(CardKind.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                }
                Section(kind == .person ? "Who" : "Question") {
                    TextField(kind.promptPlaceholder, text: $prompt, axis: .vertical)
                    if kind == .person {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(photo == nil ? "Add a photo (stays on this phone)" : "Change photo", systemImage: "photo")
                        }
                        if let photo, let image = UIImage(data: photo) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                Section("Answer") {
                    TextField(kind == .person ? "Name (e.g. Saima Aunty)" : "Answer", text: $answer, axis: .vertical)
                }
                Section {
                    TextField("Memory hook (optional)", text: $hint, axis: .vertical)
                } header: {
                    Text("Make it stick")
                } footer: {
                    Text(kind == .person ? "Link the name to something vivid: “Saima → sunny → yellow scarf”."
                                         : "Picture it vividly, or link it to a place in your home. Never store PINs or passwords here.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemedBackground())
            .navigationTitle(card == nil ? "New card" : "Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(prompt.isEmpty || answer.isEmpty)
                }
            }
            .onAppear {
                guard let card else { return }
                kind = card.kind; prompt = card.prompt; answer = card.answer; hint = card.hint; photo = card.photo
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        photo = UIImage(data: data)?.jpegData(compressionQuality: 0.7) ?? data
                    }
                }
            }
        }
    }

    private func save() {
        if let card {
            card.kindRaw = kind.rawValue; card.prompt = prompt; card.answer = answer; card.hint = hint; card.photo = photo
        } else {
            let new = MemoryCard(kind: kind, prompt: prompt, answer: answer, hint: hint, photo: photo)
            new.needsErrorless = Store.profile()?.errorlessNewCards ?? false
            context.insert(new)
        }
        try? context.save()
        Haptic.success()
        dismiss()
    }
}

struct StrategyTip: Identifiable {
    let id: String
    let title: String
    let body: String

    static let all: [StrategyTip] = [
        .init(id: "when-then", title: "When–then plans", body: "“When I put on my shoes, I take my keys.” Tie a task to a moment that always happens."),
        .init(id: "loci", title: "Memory palace", body: "Place each item of a list somewhere along a walk through your home. Walk it again to recall."),
        .init(id: "names", title: "Name hooks", body: "Repeat the name, say it back, and link it to a feature: “Bilal — bold blue glasses”."),
        .init(id: "home", title: "A home for everything", body: "Keys, glasses, phone: one fixed spot each. Fewer things to remember at all."),
        .init(id: "sleep", title: "Sleep on it", body: "Learning in the evening and checking in the morning helps memories settle."),
    ]
}
