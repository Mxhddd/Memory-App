import SwiftUI
import SwiftData
import PhotosUI
import MemoryCore

/// The Vault: anything worth knowing — languages, facts, passages, people — on FSRS-6.
struct VaultView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: Router
    @Query(sort: \MemoryCard.createdAt, order: .reverse) private var cards: [MemoryCard]
    @State private var focusCard: UUID?
    @State private var adding = false
    @State private var importing = false
    @State private var reviewing = false
    @State private var editing: MemoryCard?

    @State private var openDeck: String?
    @State private var showAll = false

    private var dueCards: [MemoryCard] { cards.filter { $0.due <= Date() }.sorted { $0.due < $1.due } }
    private var decks: [String] { Array(Set(cards.map(\.deck))).sorted() }

    var body: some View {
        let due = dueCards
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vault").font(.caption.weight(.heavy)).tracking(1.2).foregroundStyle(theme.ornament)
                    Text(due.isEmpty ? (cards.isEmpty ? "Your Vault" : "All caught up") : "\(due.count) card\(due.count == 1 ? "" : "s") ready")
                        .font(theme.display(34)).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                    Text(subline(due)).font(theme.caption).foregroundStyle(theme.secondaryText)
                }

                NextCardStack(card: due.first, dueCount: due.count, hasCards: !cards.isEmpty) { reviewing = true }

                HStack(spacing: 10) {
                    Button { adding = true } label: { Label("New card", systemImage: "plus") }.buttonStyle(SecondaryButtonStyle())
                    Button { importing = true } label: { Label("Paste a list", systemImage: "doc.on.clipboard") }.buttonStyle(SecondaryButtonStyle())
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("The shelf").font(theme.display(26)).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                        ForEach(decks, id: \.self) { deck in
                            let group = cards.filter { $0.deck == deck }
                            let dueN = group.filter { $0.due <= Date() }.count
                            DeckPile(name: deck, meta: "\(group.count) card\(group.count == 1 ? "" : "s")", due: dueN,
                                     symbol: deck == "Major pegs" ? "key.fill" : deck == "Capitals" ? "globe.europe.africa.fill" : "rectangle.stack.fill",
                                     isStarter: false) {
                                withAnimation(.snappy) { openDeck = openDeck == deck ? nil : deck; showAll = false }
                            }
                        }
                        if !cards.contains(where: { $0.deck == "Major pegs" }) {
                            DeckPile(name: "Major system pegs 00–99", meta: "Starter pack · tap to add", due: 0, symbol: "key.fill", isStarter: true) {
                                install(deck: "Major pegs", VaultImport.majorPegs)
                            }
                        }
                        if !cards.contains(where: { $0.deck == "Capitals" }) {
                            DeckPile(name: "World capitals (tricky ones)", meta: "Starter pack · tap to add", due: 0, symbol: "globe.europe.africa.fill", isStarter: true) {
                                install(deck: "Capitals", VaultImport.capitals)
                            }
                        }
                    }
                }

                if let deck = openDeck {
                    let group = cards.filter { $0.deck == deck }
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(deck).font(theme.display(24)).foregroundStyle(theme.text)
                            Spacer()
                            Button("Close") { withAnimation(.snappy) { openDeck = nil } }.font(theme.bodyEmphasis).foregroundStyle(theme.primary)
                        }
                        .padding(.bottom, 6)
                        ForEach(Array(group.prefix(showAll ? 500 : 12))) { card in
                            Button { editing = card } label: { CardRow(card: card) }.buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { context.delete(card); try? context.save() } label: { Label("Delete card", systemImage: "trash") }
                                }
                            Rectangle().fill(theme.hairline).frame(height: 1)
                        }
                        if group.count > 12 && !showAll {
                            Button("Show all \(group.count)") { showAll = true }.font(theme.bodyEmphasis).foregroundStyle(theme.primary).padding(.top, 8)
                        }
                    }
                }

                Text("Recall before you reveal — retrieving a memory strengthens it far more than re-reading (the testing effect). FSRS brings each card back just before you'd forget it.")
                    .font(.caption).foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ThemedBackground())
        .navigationTitle("Vault")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) { CardEditor(card: nil, decks: decks).environment(\.theme, theme) }
        .sheet(isPresented: $importing) { ImportSheet(decks: decks).environment(\.theme, theme) }
        .sheet(item: $editing) { card in CardEditor(card: card, decks: decks).environment(\.theme, theme) }
        .fullScreenCover(isPresented: $reviewing, onDismiss: { focusCard = nil }) {
            NavigationStack { ReviewSessionView(profile: profile, countsForSession: false, focus: focusCard) }.environment(\.theme, theme)
        }
        .onChange(of: router.pending) { _, _ in handleRoute() }
        .task { handleRoute() }
    }

    private func handleRoute() {
        switch router.pending {
        case .review: router.pending = nil; reviewing = true
        case .card(let id): router.pending = nil; focusCard = id; reviewing = true
        default: break
        }
    }

    private func subline(_ due: [MemoryCard]) -> String {
        if !due.isEmpty { return "Think of each answer before you flip it." }
        if let next = cards.filter({ $0.due > Date() }).min(by: { $0.due < $1.due }) {
            return "Next card comes back \(next.due.formatted(.relative(presentation: .named)))."
        }
        return "Keep anything worth knowing: words, facts, faces, passages."
    }

    private func install(deck: String, _ pack: [VaultImport.Card]) {
        for c in pack { context.insert(MemoryCard(deck: deck, prompt: c.prompt, answer: c.answer)) }
        try? context.save()
        Haptic.success()
        SpotlightIndex.reindex()
    }
}

/// The next due card on top of a small fanned pile; tap to review.
struct NextCardStack: View {
    @Environment(\.theme) private var theme
    let card: MemoryCard?
    let dueCount: Int
    let hasCards: Bool
    let review: () -> Void

    var body: some View {
        Button(action: review) {
            ZStack(alignment: .top) {
                theme.shape(step: 8, radius: 26).fill(theme.pixelBorders ? Color(hex: 0x201A2D) : Color(hex: 0xF3EBD8))
                    .frame(height: 168).padding(.horizontal, 26).rotationEffect(.degrees(-5)).offset(y: 18)
                theme.shape(step: 8, radius: 26).fill(theme.pixelBorders ? Color(hex: 0x262036) : Color(hex: 0xFBF6EA))
                    .frame(height: 172).padding(.horizontal, 18).rotationEffect(.degrees(3)).offset(y: 10)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text((card?.deck ?? (hasCards ? "Up to date" : "Empty")).uppercased())
                            .font(.caption.weight(.heavy)).tracking(1).foregroundStyle(theme.ornament)
                        Spacer()
                        if dueCount > 0 {
                            Text("\(dueCount) due").font(.caption.weight(.bold)).foregroundStyle(theme.ornament)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(theme.pill.fill(theme.ornament.opacity(0.14)))
                        }
                    }
                    Spacer(minLength: 0)
                    Text(card?.prompt ?? (hasCards ? "Nothing due — your memories are resting." : "Add a starter pack below, or write your first card."))
                        .font(card == nil ? theme.bodyEmphasis : theme.display(24))
                        .foregroundStyle(theme.text)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Label(card == nil ? (hasCards ? "Come back later" : "Start with a pack below") : "Review now", systemImage: "play.fill")
                        .font(theme.caption.weight(.bold))
                        .foregroundStyle(card == nil ? theme.secondaryText : theme.primary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180, alignment: .leading)
                .background(theme.shape(step: 8, radius: 26).fill(theme.pixelBorders ? Color(hex: 0x2F2640) : .white))
                .shadow(color: theme.pixelBorders ? .clear : Color(hex: 0x1E2A44).opacity(0.12), radius: 17, y: 16)
                .padding(.horizontal, 10)
            }
            .frame(height: 206)
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
        .accessibilityLabel(card == nil ? "No cards due" : "Review \(dueCount) due cards")
    }
}

/// One deck on the shelf: a small pile with a "due" ribbon. Starter packs are drawn as an outline.
struct DeckPile: View {
    @Environment(\.theme) private var theme
    let name: String
    let meta: String
    let due: Int
    let symbol: String
    let isStarter: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            ZStack(alignment: .topTrailing) {
                if !isStarter {
                    theme.shape(step: 6, radius: 18).fill(theme.pixelBorders ? Color(hex: 0x221B2F) : theme.raised)
                        .rotationEffect(.degrees(-4)).offset(x: 4, y: 8)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: symbol).font(.title3).foregroundStyle(theme.ornament)
                    Spacer(minLength: 0)
                    Text(name).font(theme.bodyEmphasis).foregroundStyle(theme.text).lineLimit(2).multilineTextAlignment(.leading)
                    Text(meta).font(.caption).foregroundStyle(theme.secondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                .background(theme.shape(step: 6, radius: 18).fill(isStarter ? Color.clear : (theme.pixelBorders ? Color(hex: 0x2A2238) : theme.surface)))
                .overlay(theme.shape(step: 6, radius: 18).stroke(isStarter ? theme.hairline : .clear, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                if due > 0 {
                    Text("\(due) due").font(.caption.weight(.heavy)).foregroundStyle(theme.onPrimary)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(theme.pill.fill(theme.primary))
                        .offset(x: 6, y: 10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isStarter ? "Add starter pack: \(name)" : "\(name), \(meta), \(due) due")
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
