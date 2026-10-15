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
                Text("At most 2 training prompts a day. Reminders you set yourself are separate.")
            }

            Section {
                Picker("Minutes per day", selection: $profile.dailyMinutes) {
                    Text("10").tag(10); Text("15").tag(15); Text("25").tag(25)
                }
                .pickerStyle(.segmented)
                Toggle("Type answers in the Vault", isOn: $profile.typedAnswers)
                Toggle("Show letters in n-back", isOn: $profile.showNBackLetters)
                Stepper(value: $profile.desiredRetention, in: 0.80...0.97, step: 0.01) {
                    LabeledContent("Vault target", value: "\(Int(profile.desiredRetention * 100))% remembered")
                }
                NavigationLink("My palaces") { PalaceListView() }
            } header: {
                Text("Training")
            } footer: {
                Text("Typing answers (instead of just revealing) makes recall stronger. Letters in n-back are an accessibility aid; the standard task is audio-only.")
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
                Text("Memory Garden trains memory techniques and working memory. It is not a medical device and makes no claims about preventing or treating any condition.")
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
            Text("This removes your training history, palaces, Vault cards, reminders and circle. It can't be undone.")
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
                Button("Advance the course one day") { profile.courseDay = min(profile.courseDay + 1, Course.length); profile.lastCourseAdvance = nil; save("Course day \(profile.courseDay).") }
                Button("Make a benchmark due") { profile.lastBenchmark = nil; save("Benchmark due.") }
                Button("Reset course to day 1") { profile.courseDay = 1; profile.lessonsRead = []; save("Course reset.") }
            }
            Section("Data") {
                Button("Seed a fake baseline week") { seed() }
                LabeledContent("App Group", value: SharedStore.isAvailable ? "OK (\(SharedStore.groupID))" : "Unavailable — widget shows sample data")
            }
            if !log.isEmpty { Section { Text(log).font(.footnote) } }
        }
        .navigationTitle("Debug")
    }

    private func save(_ message: String) {
        try? context.save()
        log = message
    }

    private func seed() {
        let cal = Calendar.current
        for day in 0..<10 {
            let date = cal.date(byAdding: .day, value: day - 10, to: Date())!
            let words = 10 + day
            context.insert(TaskSession(task: .wordSprint, correct: Int(Double(words) * 0.8), total: words, meanRTms: 0, score: 0.8,
                                       level: words, seed: "seed\(day)", courseDay: day + 1, date: date))
            context.insert(TaskSession(task: .dualNBack, correct: 9, total: 12, meanRTms: 0, score: 0.75,
                                       level: 2 + day / 4, seed: "seed\(day)", courseDay: day + 1, date: date))
            let record = DayRecord(day: date)
            record.questDone = true
            context.insert(record)
        }
        for (i, value) in [(0, 11), (9, 17)] {
            let date = cal.date(byAdding: .day, value: i - 10, to: Date())!
            context.insert(TaskSession(task: .wordRecall, correct: value, total: 30, meanRTms: 0, score: Double(value) / 30,
                                       level: value, seed: "benchmark", courseDay: 1, isBenchmark: true, date: date))
        }
        save("Seeded 10 days.")
    }
}
