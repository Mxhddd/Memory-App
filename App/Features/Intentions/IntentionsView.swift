import SwiftUI
import SwiftData
import MemoryCore

/// Prospective memory: reminders you set yourself — the biggest everyday failure source.
/// Drawn as a day path: today, tomorrow and later, each reminder a stop on a timeline.
struct IntentionsView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \Intention.time) private var intentions: [Intention]
    @EnvironmentObject private var router: Router
    @State private var adding = false

    private struct Stop: Identifiable {
        let intention: Intention
        let when: Date
        var id: String { "\(intention.id.uuidString)-\(Int(when.timeIntervalSince1970))" }
    }

    /// The occurrence that matters for each reminder: today's (even if it passed and isn't done), else the next.
    private var stops: [Stop] {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        return intentions.filter(\.active).compactMap { i in
            let occ = Notifications.occurrences(of: i, from: now, days: 3, calendar: .current).filter { $0 >= today }.sorted()
            // A one-off from an earlier day stays visible under "Earlier" so it can be cleared away.
            guard let when = occ.first(where: { Calendar.current.isDateInToday($0) || $0 > now }) else { return Stop(intention: i, when: i.time) }
            return Stop(intention: i, when: when)
        }
        .sorted { $0.when < $1.when }
    }

    var body: some View {
        let all = stops
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yours, separate from training").font(.caption.weight(.heavy)).tracking(1.1).foregroundStyle(theme.ornament)
                        Text("Reminders").font(theme.display(34)).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                    }
                    Spacer()
                    Button { adding = true } label: {
                        Image(systemName: "plus").font(.title2.weight(.bold)).foregroundStyle(theme.onPrimary)
                            .frame(width: theme.minTouch, height: theme.minTouch)
                            .background(theme.pill.fill(theme.primary))
                    }
                    .accessibilityLabel("New reminder")
                }

                if all.isEmpty {
                    VStack(spacing: 14) {
                        MascotView(mood: .idle, size: 96)
                        Text("Things you mean to do, at the moment you need them. Try “Call Aunty at 3 pm” or “When I leave the house → take my keys”.")
                            .font(theme.body).foregroundStyle(theme.text).multilineTextAlignment(.center)
                        Button("New reminder") { adding = true }.buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.vertical, 12)
                }

                ForEach(groups(all), id: \.title) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title).font(theme.bodyEmphasis).foregroundStyle(group.title == "Today" ? theme.ornament : theme.secondaryText)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.stops) { stop in
                            DayPathRow(intention: stop.intention, when: stop.when) {
                                Notifications.markIntentionDone(stop.intention.id, on: stop.when)
                                Haptic.success()
                            } onDelete: {
                                context.delete(stop.intention)
                                try? context.save()
                                Notifications.replan(profile: profile)
                                WidgetBridge.update(profile: profile)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("How these reach you").font(theme.bodyEmphasis).foregroundStyle(theme.text)
                    ForEach(ReminderLevel.allCases) { level in
                        Label {
                            Text("**\(level.label).** \(level.explanation)").font(.caption).foregroundStyle(theme.secondaryText)
                        } icon: {
                            Image(systemName: level == .alarm ? "alarm.fill" : "bell.fill").foregroundStyle(level == .alarm ? theme.primary : theme.ornament)
                        }
                    }
                    Text("You can also tick reminders off from a widget, Control Center or Siri.").font(.caption).foregroundStyle(theme.secondaryText)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ThemedBackground())
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) { IntentionEditor(profile: profile).environment(\.theme, theme) }
        .onChange(of: router.pending) { _, new in if new == .newReminder { router.pending = nil; adding = true } }
        .task { if router.pending == .newReminder { router.pending = nil; adding = true } }
    }

    private func groups(_ all: [Stop]) -> [(title: String, stops: [Stop])] {
        let cal = Calendar.current
        var out: [(title: String, stops: [Stop])] = []
        for stop in all {
            let title = stop.when < cal.startOfDay(for: Date()) ? "Earlier"
                : cal.isDateInToday(stop.when) ? "Today" : cal.isDateInTomorrow(stop.when) ? "Tomorrow" : "Later"
            if let i = out.firstIndex(where: { $0.title == title }) { out[i].stops.append(stop) } else { out.append((title, [stop])) }
        }
        // Old one-offs go last: they're housekeeping, not the day ahead.
        return out.filter { $0.title != "Earlier" } + out.filter { $0.title == "Earlier" }
    }
}

/// One stop on the day path: time, a dot on the line, the reminder and its Done button.
struct DayPathRow: View {
    @Environment(\.theme) private var theme
    let intention: Intention
    let when: Date
    let onDone: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let done = intention.isDone(on: when)
        let earlier = when < Calendar.current.startOfDay(for: Date())
        let waiting = when < Date() && !done && !earlier
        HStack(alignment: .top, spacing: 10) {
            Text(earlier ? when.formatted(.dateTime.day().month(.abbreviated)) : when.formatted(.dateTime.hour().minute()))
                .font(theme.display(24).monospacedDigit())
                .foregroundStyle(waiting ? theme.primary : theme.text)
                .frame(width: 92, alignment: .trailing)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            VStack(spacing: 0) {
                Group {
                    if theme.pixelBorders {
                        Rectangle().frame(width: 11, height: 11).rotationEffect(.degrees(45))
                    } else {
                        Circle().frame(width: 14, height: 14)
                    }
                }
                .foregroundStyle(done ? theme.success : waiting ? theme.primary : theme.ornament)
                .padding(.top, 8)
                Rectangle().fill(theme.hairline).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(intention.text).font(theme.bodyEmphasis)
                    .foregroundStyle(done ? theme.secondaryText : theme.text)
                    .strikethrough(done, color: theme.secondaryText)
                if !intention.whenCue.isEmpty {
                    Text("When \(intention.whenCue) →").font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                Label((intention.repeatsDaily ? "Every day · " : "") + intention.level.label + (waiting ? " · waiting" : ""),
                      systemImage: intention.level == .alarm ? "alarm.fill" : "bell.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(intention.level == .alarm ? theme.primary : theme.ornament)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)
            if earlier {
                Button("Clear", action: onDelete).buttonStyle(.bordered).tint(theme.secondaryText)
                    .accessibilityLabel("Clear: \(intention.text)")
            } else if done {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(theme.success).accessibilityLabel("Done")
            } else {
                Button("Done", action: onDone).buttonStyle(.borderedProminent).tint(theme.primary).foregroundStyle(theme.onPrimary)
                    .accessibilityLabel("Done: \(intention.text)")
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) { Label("Delete reminder", systemImage: "trash") }
        }
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
