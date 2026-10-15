import SwiftUI
import SwiftData
import MemoryCore

struct SettingsView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @AppStorage("sfxEnabled") private var sfx = true
    @AppStorage("liveActivityEnabled") private var liveActivity = true
    @AppStorage("supabase.url") private var supabaseURL = ""
    @AppStorage("supabase.anonKey") private var supabaseKey = ""
    @State private var reminder = Date()
    @State private var confirmDelete = false
    @State private var exportURL: URL?
    @State private var showCrisis = false
    @State private var versionTaps = 0
    @State private var notificationStatus = "…"

    var body: some View {
        Form {
            Section("You") {
                TextField("Name", text: $profile.displayName)
                TextField("Companion's name", text: $profile.mascotName)
                Picker("Style", selection: Binding(get: { profile.theme }, set: { profile.theme = $0 })) {
                    Text("Midnight Den (raccoon)").tag(ThemeID.midnightRaccoon)
                    Text("Gilded Atelier").tag(ThemeID.gildedAtelier)
                }
            }

            Section {
                DatePicker("Daily reminder", selection: $reminder, displayedComponents: .hourAndMinute)
                    .onChange(of: reminder) { _, value in
                        let hm = Calendar.current.dateComponents([.hour, .minute], from: value)
                        profile.reminderHour = hm.hour ?? 19
                        profile.reminderMinute = hm.minute ?? 30
                        Notifications.replan(profile: profile)
                    }
                Toggle("Evening nudge if not done", isOn: $profile.eveningNudge)
                    .onChange(of: profile.eveningNudge) { _, _ in Notifications.replan(profile: profile) }
                Toggle("Quest on Lock Screen", isOn: $liveActivity)
                    .onChange(of: liveActivity) { _, on in on ? LiveActivityService.sync(profile: profile) : LiveActivityService.endAll() }
                Toggle("Sounds", isOn: $sfx)
                LabeledContent("Notifications", value: notificationStatus)
                if AlarmService.isSupported {
                    LabeledContent("Alarms (ring on silent)", value: AlarmService.isAuthorized ? "Allowed" : "Not allowed")
                    if !AlarmService.isAuthorized {
                        Button("Allow alarms") { Task { await AlarmService.requestAuthorization() } }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("At most 3 practice prompts a day. Reminders you set yourself are separate.")
            }

            Section {
                Toggle("Gentle, errorless learning", isOn: $profile.errorlessNewCards)
                Toggle("Simple card buttons (Not yet / Got it)", isOn: $profile.simpleRatings)
                Stepper(value: $profile.desiredRetention, in: 0.80...0.95, step: 0.01) {
                    LabeledContent("Card target", value: "\(Int(profile.desiredRetention * 100))% remembered")
                }
            } header: {
                Text("Practice")
            } footer: {
                Text("A higher target means cards come back sooner. 90%+ suits a gentler pace.")
            }

            Section("Wellbeing & health") {
                NavigationLink("Doctor-visit checklist") { ChecklistView() }
                Button("Support & helplines") { showCrisis = true }
            }

            Section {
                TextField("https://YOUR-PROJECT.supabase.co", text: $supabaseURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Anon public key", text: $supabaseKey)
            } header: {
                Text("Circle server (optional)")
            } footer: {
                Text("Leave empty to use the values built into the app. See docs/INSTALL.md → Supabase.")
            }

            Section {
                Button("Export my data (JSON)") { exportURL = Exporter.exportFile() }
                if let exportURL { ShareLink("Share export", item: exportURL) }
                Button("Delete everything", role: .destructive) { confirmDelete = true }
            } header: {
                Text("Your data")
            } footer: {
                Text("Everything stays on this phone. Only “practised today: yes/no” is shared with people you add to your circle. No ads, no analytics, no tracking.")
            }

            Section {
                Text("Memory Garden is for memory training and general wellness. It does not diagnose, treat or predict any condition. If you notice changes in your memory, talk to your doctor.")
                    .font(.footnote)
                Text("Fonts: Pixelify Sans & Cormorant Garamond (SIL Open Font License).").font(.footnote)
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                    .onTapGesture { versionTaps += 1 }
                if versionTaps >= 5 { NavigationLink("Debug tools") { DebugView(profile: profile) } }
            } header: {
                Text("About")
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Settings")
        .onAppear {
            reminder = Calendar.current.date(bySettingHour: profile.reminderHour, minute: profile.reminderMinute, second: 0, of: Date()) ?? Date()
            Task {
                let s = await Notifications.authorizationStatus()
                notificationStatus = s == .authorized ? "On" : s == .denied ? "Off — enable in iOS Settings" : "Not asked yet"
            }
        }
        .onDisappear {
            try? context.save()
            WidgetBridge.update(profile: profile)
        }
        .sheet(isPresented: $showCrisis) { CrisisResourcesView().environment(\.theme, theme) }
        .confirmationDialog("Delete all Memory Garden data on this phone?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                Task {
                    await CircleService.shared.deleteServerData()
                    LiveActivityService.endAll()
                    Notifications.center.removeAllPendingNotificationRequests()
                    Store.deleteEverything()
                }
            }
        } message: {
            Text("This removes your practice history, cards, reminders and circle. It can't be undone.")
        }
    }
}

/// Hidden tools for testing on a real phone (tap Version 5×).
struct DebugView: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @State private var log = ""

    var body: some View {
        Form {
            Section("Reminders") {
                Button("Fire test reminders in 5–10 s") { Notifications.fireTestReminders(profile: profile); log = "Lock the phone and wait." }
                Button("Re-plan notifications") { Notifications.replan(profile: profile); log = "Re-planned." }
            }
            Section("Time travel") {
                Button("Burst started 1 day earlier") { shift(days: -1) }
                Button("Skip to next check-in week") { shift(days: -28) }
                Button("Make delayed recall ready now") {
                    if var p = DelayedRecall.pending { p.studiedAt = Date().addingTimeInterval(-DelayedRecall.delay); DelayedRecall.pending = p; log = "Ready." }
                    else { log = "No word list played yet." }
                }
            }
            Section("Data") {
                Button("Seed a fake baseline week") { seed() }
                LabeledContent("App Group", value: SharedStore.isAvailable ? "OK (\(SharedStore.groupID))" : "Unavailable — widget shows sample data")
            }
            if !log.isEmpty { Section { Text(log).font(.footnote) } }
        }
        .navigationTitle("Debug")
    }

    private func shift(days: Int) {
        profile.burstStart = Calendar.current.date(byAdding: .day, value: days, to: profile.burstStart) ?? profile.burstStart
        try? context.save()
        log = "Burst start is now \(profile.burstStart.formatted(date: .abbreviated, time: .omitted))."
    }

    private func seed() {
        let cal = Calendar.current
        for day in 0..<7 {
            let date = cal.date(byAdding: .day, value: day - 7, to: Date())!
            for task in [RealmTask.faceName, .ancientRunes, .wordList] {
                let score = min(1, 0.45 + Double(day) * 0.07 + Double.random(in: -0.05...0.05))
                let s = TaskSession(task: task, correct: Int(score * 6), total: 6, meanRTms: 1800, score: score,
                                    seed: "seed", burst: (0, day + 1), date: date)
                context.insert(s)
            }
            let record = DayRecord(day: date)
            record.questDone = true
            context.insert(record)
        }
        profile.burstStart = cal.date(byAdding: .day, value: -7, to: Date())!
        try? context.save()
        log = "Seeded 7 days."
    }
}
