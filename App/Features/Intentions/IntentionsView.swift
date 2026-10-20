import SwiftUI
import SwiftData
import MemoryCore

/// Prospective memory: reminders you set yourself — the biggest everyday failure source.
struct IntentionsView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \Intention.time) private var intentions: [Intention]
    @EnvironmentObject private var router: Router
    @State private var adding = false

    var body: some View {
        List {
            if intentions.isEmpty {
                Section {
                    Text("Add a reminder like “Call Aunty at 3 pm” or “When I leave the house → take my keys”.")
                        .font(theme.body).foregroundStyle(theme.text)
                }
                .listRowBackground(theme.surface)
            }

            Section("Your reminders") {
                ForEach(intentions) { intention in
                    IntentionRow(intention: intention) {
                        Notifications.markIntentionDone(intention.id)
                        Haptic.success()
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(intentions[i]) }
                    try? context.save()
                    Notifications.replan(profile: profile)
                    WidgetBridge.update(profile: profile)
                }
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    .accessibilityLabel("Add reminder")
            }
        }
        .sheet(isPresented: $adding) { IntentionEditor(profile: profile).environment(\.theme, theme) }
        .onChange(of: router.pending) { _, new in if new == .newReminder { router.pending = nil; adding = true } }
        .task { if router.pending == .newReminder { router.pending = nil; adding = true } }
    }
}

struct IntentionRow: View {
    @Environment(\.theme) private var theme
    let intention: Intention
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: intention.level == .alarm ? "alarm.fill" : intention.level == .nag ? "bell.and.waves.left.and.right.fill" : "bell.fill")
                .font(.title2).foregroundStyle(theme.ornament).frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(intention.text).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                if !intention.whenCue.isEmpty {
                    Text("When \(intention.whenCue)").font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                Text(intention.repeatsDaily ? "Every day · \(intention.time.formatted(date: .omitted, time: .shortened))"
                                            : intention.time.formatted(date: .abbreviated, time: .shortened))
                    .font(theme.caption).foregroundStyle(theme.secondaryText)
            }
            Spacer()
            if intention.isDone(on: Date()) {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(theme.success).accessibilityLabel("Done today")
            } else {
                Button("Done", action: onDone).buttonStyle(.borderedProminent).tint(theme.primary).foregroundStyle(theme.onPrimary)
            }
        }
        .frame(minHeight: theme.minTouch)
    }
}

struct IntentionEditor: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var whenCue = ""
    @State private var time = Date().addingTimeInterval(3600)
    @State private var daily = false
    @State private var level: ReminderLevel = .nag
    @State private var alarmAllowed = AlarmService.isAuthorized

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("e.g. Call Aunty", text: $text)
                    TextField("When… (optional, e.g. I finish lunch)", text: $whenCue)
                }
                Section("Time") {
                    DatePicker("At", selection: $time, displayedComponents: daily ? [.hourAndMinute] : [.date, .hourAndMinute])
                    Toggle("Every day", isOn: $daily)
                }
                Section {
                    Picker("How insistent", selection: $level) {
                        ForEach(ReminderLevel.allCases.filter { $0 != .alarm || AlarmService.isSupported }) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(level.explanation).font(.footnote).foregroundStyle(.secondary)
                    if level == .alarm && !alarmAllowed {
                        Button("Allow alarms") {
                            Task { alarmAllowed = await AlarmService.requestAuthorization() }
                        }
                    }
                } footer: {
                    Text("Tip: “When I put on my shoes → take my keys” plans work better than willpower.")
                }
            }
            .navigationTitle("New reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let i = Intention(text: text.trimmingCharacters(in: .whitespaces), whenCue: whenCue.trimmingCharacters(in: .whitespaces),
                                          time: time, repeatsDaily: daily, level: level)
                        context.insert(i)
                        try? context.save()
                        Notifications.replan(profile: profile)
                        WidgetBridge.update(profile: profile)
                        Haptic.success()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
