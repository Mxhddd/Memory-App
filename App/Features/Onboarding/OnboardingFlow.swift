import SwiftUI
import SwiftData
import MemoryCore

/// Style → names → daily time → reminder → permissions → first benchmark.
struct OnboardingFlow: View {
    let existing: Profile?
    @Environment(\.modelContext) private var context

    private enum Step: Int, CaseIterable { case welcome, who, names, time, reminder, permissions, ready }
    @State private var step: Step = .welcome
    @State private var theme: ThemeID = .midnightRaccoon
    @State private var name = ""
    @State private var mascot = "Mochi"
    @State private var minutes = 15
    @State private var reminder = Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())!

    var body: some View {
        let t = Theme.forID(theme)
        ZStack {
            ThemedBackground()
            VStack(spacing: 0) {
                if step != .welcome {
                    ProgressPips(done: step.rawValue, total: Step.allCases.count - 1).padding()
                }
                ScrollView {
                    VStack(spacing: 20) { content }
                        .padding(20)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.theme, t)
        .preferredColorScheme(t.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .who: who
        case .names: names
        case .time: timeStep
        case .reminder: reminderStep
        case .permissions: permissionsStep
        case .ready: readyStep
        }
    }

    private func next() {
        Haptic.tap()
        if let n = Step(rawValue: step.rawValue + 1) { step = n }
    }

    private var welcome: some View {
        let t = Theme.forID(theme)
        return VStack(spacing: 20) {
            MascotView(mood: .happy, size: 160).padding(.top, 40)
            Text("Memory Garden").font(t.display(40)).foregroundStyle(t.text)
            SpeechBubble(text: "Train your memory the way memory champions do: memory palaces, number codes, working-memory drills and smart spaced recall — a little every day.")
            Text("Built on published research. Your progress is measured with honest benchmarks, not hype.")
                .font(.footnote).foregroundStyle(t.secondaryText).multilineTextAlignment(.center)
            Button("Let's begin") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var who: some View {
        VStack(spacing: 16) {
            SectionTitle(text: "Pick your style")
            ForEach(ThemeID.allCases) { id in
                let t = Theme.forID(id)
                Button {
                    theme = id
                    mascot = id == .midnightRaccoon ? "Mochi" : "Professor"
                    Haptic.soft()
                } label: {
                    HStack(spacing: 16) {
                        PixelSpriteView(art: t.mascotIdle).frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.copy.appTitle).font(t.display(24)).foregroundStyle(t.text)
                            Text(id == .midnightRaccoon ? "Cute-goth pixel den with Mochi the raccoon."
                                                        : "Calm, elegant, ivory and brass.")
                                .font(.callout).foregroundStyle(t.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: theme == id ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(t.primary)
                    }
                    .padding(16)
                    .background(t.shape().fill(t.surface))
                    .overlay(t.shape().stroke(theme == id ? t.primary : .clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(theme == id ? .isSelected : [])
            }
            Button("Continue") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var names: some View {
        let t = Theme.forID(theme)
        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "Introductions")
            Text("What should I call you?").font(t.bodyEmphasis).foregroundStyle(t.text)
            TextField("Your name", text: $name)
                .textContentType(.givenName)
                .font(t.body)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: t.cornerRadius).fill(t.surface))
                .foregroundStyle(t.text)
            Text("And your companion's name?").font(t.bodyEmphasis).foregroundStyle(t.text)
            HStack {
                PixelSpriteView(art: t.mascotIdle).frame(width: 56, height: 56)
                TextField("Mascot name", text: $mascot)
                    .font(t.body)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: t.cornerRadius).fill(t.surface))
                    .foregroundStyle(t.text)
            }
            Button("Continue") { next() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var timeStep: some View {
        let t = Theme.forID(theme)
        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "How long per day?")
            Text("Consistency beats marathons. The study this course is based on used about 30 minutes a day; 15 is a strong start.")
                .font(t.body).foregroundStyle(t.secondaryText)
            ForEach([10, 15, 25], id: \.self) { m in
                Button {
                    minutes = m
                    Haptic.soft()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(m) minutes").font(t.bodyEmphasis).foregroundStyle(t.text)
                            Text(m == 10 ? "Course + a short gym block every other day"
                                 : m == 15 ? "Course + gym every other day (recommended)"
                                 : "Course + full gym every day")
                                .font(t.caption).foregroundStyle(t.secondaryText)
                        }
                        Spacer()
                        Image(systemName: minutes == m ? "checkmark.circle.fill" : "circle").foregroundStyle(t.primary)
                    }
                    .themedCard()
                }
                .buttonStyle(.plain)
            }
            Button("Continue") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var reminderStep: some View {
        let t = Theme.forID(theme)
        return VStack(spacing: 16) {
            SectionTitle(text: "When should we train?")
            Text("Evenings work well: learning shortly before sleep gives memories a night to consolidate, and the next-day recall shows what stuck.")
                .font(t.body).foregroundStyle(t.secondaryText)
            DatePicker("Daily reminder", selection: $reminder, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(t.colorScheme)
            Button("Continue") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var permissionsStep: some View {
        let t = Theme.forID(theme)
        return VStack(spacing: 16) {
            SectionTitle(text: "Reminders")
            Text("Allow notifications for your daily training reminder and any personal reminders you set.")
                .font(t.body).foregroundStyle(t.secondaryText)
            Button("Allow notifications") { Task { await Notifications.requestAuthorization() } }
                .buttonStyle(PrimaryButtonStyle())
            if AlarmService.isSupported {
                Text("Personal reminders can also ring like an alarm, even on silent.")
                    .font(t.body).foregroundStyle(t.secondaryText)
                Button("Allow alarms") { Task { await AlarmService.requestAuthorization() } }
                    .buttonStyle(SecondaryButtonStyle())
            }
            Button("Continue") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var readyStep: some View {
        let t = Theme.forID(theme)
        return VStack(spacing: 20) {
            MascotView(mood: .happy, size: 150)
            SectionTitle(text: "First: your starting line")
            SpeechBubble(text: "Today you'll do two short benchmarks — word recall and digit span — so you can see real change later. Then lesson one of the Memory Palace course.")
            Text("Benchmarks repeat on days 14, 28 and 42, then monthly.")
                .font(t.caption).foregroundStyle(t.secondaryText)
            Button("Start") { finish() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func finish() {
        let profile = existing ?? Profile()
        if existing == nil { context.insert(profile) }
        profile.displayName = name.trimmingCharacters(in: .whitespaces)
        profile.mascotName = mascot.trimmingCharacters(in: .whitespaces).isEmpty ? "Mochi" : mascot
        profile.theme = theme
        profile.dailyMinutes = minutes
        let hm = Calendar.current.dateComponents([.hour, .minute], from: reminder)
        profile.reminderHour = hm.hour ?? 19
        profile.reminderMinute = hm.minute ?? 30
        profile.benchmarkStart = Date()
        profile.courseDay = 1
        profile.timezoneID = TimeZone.current.identifier
        profile.onboardingComplete = true
        try? context.save()
        Notifications.replan(profile: profile)
        Router.shared.pending = .startQuest
        SFX.play(.levelup)
    }
}
