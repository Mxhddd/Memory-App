import SwiftUI
import SwiftData
import PhotosUI
import MemoryCore

/// The Vault: anything worth knowing — languages, facts, passages, people — on FSRS-6.
struct VaultView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \MemoryCard.createdAt, order: .reverse) private var cards: [MemoryCard]
    @State private var adding = false
    @State private var importing = false
    @State private var reviewing = false
    @State private var editing: MemoryCard?

    private var dueCount: Int { cards.filter { $0.due <= Date() }.count }
    private var decks: [String] { Array(Set(cards.map(\.deck))).sorted() }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(dueCount > 0 ? "\(dueCount) card\(dueCount == 1 ? "" : "s") ready" : "All caught up")
                        .font(theme.display(26)).foregroundStyle(theme.text)
                    Text("Recall before you reveal — retrieving a memory strengthens it far more than re-reading (the testing effect). FSRS brings each card back just before you'd forget it.")
                        .font(theme.caption).foregroundStyle(theme.secondaryText)
                    Button("Review now") { reviewing = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(dueCount == 0)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(theme.surface)

            Section("Starter packs") {
                starter("Major system pegs 00–99", deck: "Major pegs", cards: VaultImport.majorPegs,
                        note: "Powers the Number Sprint. Learn these during course week 2.")
                starter("World capitals (tricky ones)", deck: "Capitals", cards: VaultImport.capitals, note: "30 cards")
            }
            .listRowBackground(theme.surface)

            ForEach(decks, id: \.self) { deck in
                let group = cards.filter { $0.deck == deck }
                Section("\(deck) · \(group.count)") {
                    ForEach(group.prefix(50)) { card in
                        Button { editing = card } label: { CardRow(card: card) }.buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let shown = Array(group.prefix(50))
                        for i in offsets { context.delete(shown[i]) }
                        try? context.save()
                    }
                    if group.count > 50 {
                        Text("+ \(group.count - 50) more").font(.footnote).foregroundStyle(theme.secondaryText)
                    }
                }
                .listRowBackground(theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Vault")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { adding = true } label: { Label("New card", systemImage: "plus") }
                    Button { importing = true } label: { Label("Paste a list", systemImage: "doc.on.clipboard") }
                } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                .accessibilityLabel("Add cards")
            }
        }
        .sheet(isPresented: $adding) { CardEditor(card: nil, decks: decks).environment(\.theme, theme) }
        .sheet(isPresented: $importing) { ImportSheet(decks: decks).environment(\.theme, theme) }
        .sheet(item: $editing) { card in CardEditor(card: card, decks: decks).environment(\.theme, theme) }
        .fullScreenCover(isPresented: $reviewing) {
            NavigationStack { ReviewSessionView(profile: profile, countsForSession: false) }.environment(\.theme, theme)
        }
    }

    private func starter(_ title: String, deck: String, cards pack: [VaultImport.Card], note: String) -> some View {
        let installed = cards.contains { $0.deck == deck }
        return Button {
            guard !installed else { return }
            for c in pack { context.insert(MemoryCard(deck: deck, prompt: c.prompt, answer: c.answer)) }
            try? context.save()
            Haptic.success()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                    Text(note).font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Image(systemName: installed ? "checkmark.circle.fill" : "plus.circle").foregroundStyle(theme.primary)
            }
            .frame(minHeight: theme.minTouch)
        }
        .disabled(installed)
    }
}

struct CardRow: View {
    @Environment(\.theme) private var theme
    let card: MemoryCard

    var body: some View {
        HStack(spacing: 12) {
            if let data = card.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
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
    let decks: [String]

    @State private var deck = "General"
    @State private var prompt = ""
    @State private var answer = ""
    @State private var hint = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck") {
                    TextField("Deck name", text: $deck)
                    if !decks.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(decks, id: \.self) { d in
                                    Button(d) { deck = d }.buttonStyle(.bordered).tint(theme.primary)
                                }
                            }
                        }
                    }
                }
                Section("Front") {
                    TextField("Question, word, or cue", text: $prompt, axis: .vertical)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photo == nil ? "Add a picture (optional)" : "Change picture", systemImage: "photo")
                    }
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Section("Back") { TextField("Answer", text: $answer, axis: .vertical) }
                Section {
                    TextField("Memory hook (optional)", text: $hint, axis: .vertical)
                } footer: {
                    Text("A vivid image or palace stop that links front and back.")
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
                if let card { deck = card.deck; prompt = card.prompt; answer = card.answer; hint = card.hint; photo = card.photo }
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
        let d = deck.trimmingCharacters(in: .whitespaces).isEmpty ? "General" : deck.trimmingCharacters(in: .whitespaces)
        if let card {
            card.deck = d; card.prompt = prompt; card.answer = answer; card.hint = hint; card.photo = photo
        } else {
            context.insert(MemoryCard(deck: d, prompt: prompt, answer: answer, hint: hint, photo: photo))
        }
        try? context.save()
        Haptic.success()
        dismiss()
    }
}

struct ImportSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let decks: [String]
    @State private var deck = "Imported"
    @State private var text = ""

    private var parsed: [VaultImport.Card] { VaultImport.parse(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck") { TextField("Deck name", text: $deck) }
                Section {
                    TextEditor(text: $text).frame(minHeight: 200).font(.body.monospaced())
                } header: {
                    Text("Paste one card per line")
                } footer: {
                    Text("front;back · front<tab>back · front,back — or a passage with {{c::gaps}} for fill-in cards. Spreadsheets copy as tab-separated.")
                }
                Section { Text("\(parsed.count) cards found").foregroundStyle(theme.secondaryText) }
            }
            .navigationTitle("Paste a list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(parsed.count)") {
                        for c in parsed { context.insert(MemoryCard(deck: deck, prompt: c.prompt, answer: c.answer)) }
                        try? context.save()
                        Haptic.success()
                        dismiss()
                    }
                    .disabled(parsed.isEmpty)
                }
            }
        }
    }
}
