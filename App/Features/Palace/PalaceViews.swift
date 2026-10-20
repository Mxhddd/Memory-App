import SwiftUI
import SwiftData
import MemoryCore

/// Your palaces: familiar routes with ordered stops.
struct PalaceListView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \Palace.createdAt) private var palaces: [Palace]
    @State private var creating = false

    var body: some View {
        List {
            Section {
                Text("A memory palace is a route you know by heart. Each stop holds one image. Champions keep several and rotate them.")
                    .font(theme.caption).foregroundStyle(theme.secondaryText)
            }
            .listRowBackground(theme.surface)
            ForEach(palaces) { palace in
                NavigationLink { PalaceEditor(palace: palace) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(palace.name).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                        Text("\(palace.stops.count) stops").font(theme.caption).foregroundStyle(theme.secondaryText)
                    }
                    .frame(minHeight: theme.minTouch)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(palaces[i]) }
                try? context.save()
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Palaces")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    .accessibilityLabel("New palace")
            }
        }
        .sheet(isPresented: $creating) { NavigationStack { PalaceEditor(palace: nil) }.environment(\.theme, theme) }
    }
}

struct PalaceEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let palace: Palace?

    @State private var name = ""
    @State private var stops: [String] = []
    @State private var newStop = ""
    @FocusState private var adding: Bool

    static let homeSuggestions = [
        "Front door", "Shoe rack", "Hallway mirror", "Light switch", "Sofa", "TV", "Window", "Bookshelf",
        "Dining table", "Fridge", "Stove", "Kitchen sink", "Bathroom door", "Washbasin", "Shower", "Bed",
        "Wardrobe", "Desk", "Balcony", "Rooftop water tank",
    ]

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. My home, Nani's house, the walk to uni", text: $name)
            }
            Section {
                ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                    HStack {
                        Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 28)
                        Text(stop)
                    }
                }
                .onMove { stops.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { stops.remove(atOffsets: $0) }
                HStack {
                    TextField("Next stop", text: $newStop)
                        .focused($adding)
                        .submitLabel(.next)
                        .onSubmit(addStop)
                    Button("Add", action: addStop).disabled(newStop.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Stops in walking order (\(stops.count))")
            } footer: {
                Text("Pick distinct places in the order you'd walk past them. Aim for 10 to start and 20+ later.")
            }
            if stops.count >= 2 {
                Section("The route as you'll walk it") {
                    PalaceMapView(stops: stops, walker: false, viewport: 2000)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                }
            }
            if stops.isEmpty {
                Section {
                    Button("Start from a typical home route") { stops = Self.homeSuggestions }
                } footer: {
                    Text("Then rename, reorder or delete stops so they match your real home.")
                }
            }
        }
        .navigationTitle(palace == nil ? "New palace" : "Edit palace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || stops.count < 3)
            }
        }
        .onAppear {
            if let palace { name = palace.name; stops = palace.stops }
        }
    }

    private func addStop() {
        let s = newStop.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        stops.append(s)
        newStop = ""
        adding = true
    }

    private func save() {
        if let palace {
            palace.name = name
            palace.stops = stops
        } else {
            context.insert(Palace(name: name.trimmingCharacters(in: .whitespaces), stops: stops))
        }
        try? context.save()
        Haptic.success()
        dismiss()
    }
}
