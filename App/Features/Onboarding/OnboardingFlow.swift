import SwiftUI
import SwiftData
import MemoryCore

/// "Who is this phone for?" → name & mascot → reminder time → everyday-memory check →
/// optional wellbeing check → permissions → the 7-day baseline burst starts tomorrow-ish (today).
struct OnboardingFlow: View {
    let existing: Profile?
    @Environment(\.modelContext) private var context

    private enum Step: Int, CaseIterable { case welcome, who, names, reminder, memory, wellbeing, permissions, ready }
    @State private var step: Step = .welcome
    @State private var theme: ThemeID = .midnightRaccoon
    @State private var name = ""
    @State private var mascot = "Mochi"
    @State private var reminder = Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())!
    @State private var memoryAnswers = Array(repeating: 2, count: EverydayMemoryCheck.items.count)
    @State private var hearing = false
    @State private var phq = Array(repeating: 0, count: 9)
    @State private var gad = Array(repeating: 0, count: 7)
    @State private var didWellbeing = false
    @State private var showCrisis = false

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
        .sheet(isPresented: $showCrisis) { CrisisResourcesView().environment(\.theme, t) }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .who: who
        case .names: names
        case .reminder: reminderStep
        case .memory: memoryStep
        case .wellbeing: wellbeingStep
        case .permissions: permissionsStep
        case .ready: readyStep
        }
    }

    private func next() {
        Haptic.tap()
        if let n = Step(rawValue: step.rawValue + 1) { step = n }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 20) {
            MascotView(mood: .happy, size: 160).padding(.top, 40)
            Text("Memory Garden").font(Theme.forID(theme).display(40)).foregroundStyle(Theme.forID(theme).text)
            SpeechBubble(text: "Hi! I'm a tiny memory coach. Five cozy minutes a day: games, your own flashcards, and reminders that actually remind you.")
            Text("This is brain fitness and memory training — not a medical test. It never diagnoses anything.")
                .font(.footnote).foregroundStyle(Theme.forID(theme).secondaryText).multilineTextAlignment(.center)
            Button("Let's begin") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var who: some View {
        VStack(spacing: 16) {
            SectionTitle(text: "Who is this phone for?")
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
                            Text(id == .midnightRaccoon ? "Cute-goth pixel den with Mochi the raccoon. Playful, cozy, nocturnal."
                                                        : "Calm and elegant. Large text, one step at a time, gentle pacing.")
                                .font(.callout).foregroundStyle(t.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: theme == id ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(t.primary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: t.cornerRadius).fill(t.surface))
                    .overlay(RoundedRectangle(cornerRadius: t.cornerRadius).strokeBorder(theme == id ? t.primary : t.outline.opacity(0.4), lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(theme == id ? .isSelected : [])
            }
            Text("Each phone has one person. The style also sets pacing: the Atelier uses gentler, errorless practice.")
                .font(.footnote).foregroundStyle(Theme.forID(theme).secondaryText)
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

    private var reminderStep: some View {
        let t = Theme.forID(theme)
        return VStack(spacing: 16) {
            SectionTitle(text: "When's a good time?")
            Text(theme == .midnightRaccoon
                 ? "Raccoons are night owls. An evening \(t.copy.eveningSession) helps memories settle during sleep, then a quick \(t.copy.morningSession) the next day."
                 : "Pick a calm time of day. Evening practice can help memories settle during sleep.")
                .font(t.body).foregroundStyle(t.secondaryText)
            DatePicker("Daily reminder", selection: $reminder, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(t.colorScheme)
            Button("Continue") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var memoryStep: some View {
        let t = Theme.forID(theme)
        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "Everyday memory")
            Text("How often does this happen to you lately?").font(t.body).foregroundStyle(t.secondaryText)
            ForEach(EverydayMemoryCheck.items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 8) {
                    Text(EverydayMemoryCheck.items[i].text).font(t.bodyEmphasis).foregroundStyle(t.text)
                    Picker("", selection: $memoryAnswers[i]) {
                        ForEach(1...5, id: \.self) { v in Text(EverydayMemoryCheck.scale[v - 1]).tag(v) }
                    }
                    .pickerStyle(.menu)
                    .tint(t.primary)
                }
                .themedCard()
            }
            Toggle("I sometimes struggle to hear conversations", isOn: $hearing)
                .font(t.body).foregroundStyle(t.text).tint(t.primary)
                .themedCard()
            Button("Continue") { next() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private var wellbeingStep: some View {
        let t = Theme.forID(theme)
        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "Wellbeing (optional)")
            Text("Mood, worry and sleep affect memory a lot. These standard questions (PHQ-9 and GAD-7) help the app read your practice fairly. Over the last 2 weeks, how often have you been bothered by…")
                .font(t.body).foregroundStyle(t.secondaryText)
            ForEach(PHQ9.items.indices, id: \.self) { i in questionRow(PHQ9.items[i], value: $phq[i]) }
            ForEach(GAD7.items.indices, id: \.self) { i in questionRow(GAD7.items[i], value: $gad[i]) }
            Button("Save & continue") {
                didWellbeing = true
                if PHQ9.needsSafetyResources(phq) { showCrisis = true }
                next()
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Skip for now") { next() }.buttonStyle(SecondaryButtonStyle())
        }
    }

    private func questionRow(_ text: String, value: Binding<Int>) -> some View {
        let t = Theme.forID(theme)
        return VStack(alignment: .leading, spacing: 8) {
            Text(text).font(t.bodyEmphasis).foregroundStyle(t.text)
            Picker("", selection: value) {
                ForEach(0..<4, id: \.self) { v in Text(frequencyOptions[v]).tag(v) }
            }
            .pickerStyle(.menu)
            .tint(t.primary)
        }
        .themedCard()
    }

    private var permissionsStep: some View {
        let t = Theme.forID(theme)
        return VStack(spacing: 16) {
            SectionTitle(text: "Reminders that actually remind")
            Text("Allow notifications so \(mascot) can nudge you. Reminders you set yourself can keep nudging until you tap Done.")
                .font(t.body).foregroundStyle(t.secondaryText)
            Button("Allow notifications") {
                Task { await Notifications.requestAuthorization() }
            }
            .buttonStyle(PrimaryButtonStyle())
            if AlarmService.isSupported {
                Text("On this iPhone, important reminders can also ring like an alarm — even on silent.")
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
            SectionTitle(text: "Your first week")
            SpeechBubble(text: "For the next 7 days we'll play the same few short games each day. That shows how *you* learn over days — the most useful signal there is. After that: your own flashcards and reminders, with a check-in week once a month.")
            Text("Tip: add a few personal cards (people, where things live) in Practice.")
                .font(t.caption).foregroundStyle(t.secondaryText)
            Button("Start my first quest") { finish() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: Save

    private func finish() {
        let profile = existing ?? Profile()
        if existing == nil { context.insert(profile) }
        profile.displayName = name.trimmingCharacters(in: .whitespaces)
        profile.mascotName = mascot.trimmingCharacters(in: .whitespaces).isEmpty ? "Mochi" : mascot
        profile.theme = theme
        let gentle = theme == .gildedAtelier
        profile.errorlessNewCards = gentle
        profile.simpleRatings = gentle
        profile.desiredRetention = gentle ? 0.92 : 0.88
        let hm = Calendar.current.dateComponents([.hour, .minute], from: reminder)
        profile.reminderHour = hm.hour ?? 19
        profile.reminderMinute = hm.minute ?? 30
        let p = EverydayMemoryCheck.profile(memoryAnswers)
        profile.complaintProspective = p.prospective
        profile.complaintRetrospective = p.retrospective
        profile.hearingConcern = hearing
        if didWellbeing {
            profile.phq9 = PHQ9.score(phq)
            profile.gad7 = GAD7.score(gad)
        }
        profile.burstStart = Date()
        profile.speedStart = Date()
        profile.timezoneID = TimeZone.current.identifier
        profile.onboardingComplete = true
        if (try? context.fetchCount(FetchDescriptor<ChecklistItem>())) ?? 0 == 0 {
            for (i, title) in ChecklistItem.defaults.enumerated() { context.insert(ChecklistItem(order: i, title: title)) }
        }
        try? context.save()
        Notifications.replan(profile: profile)
        Router.shared.pending = .startQuest
        SFX.play(.levelup)
    }
}

/// Shown if PHQ-9 item 9 is positive, and always reachable from Settings.
struct CrisisResourcesView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("You're not alone 💜").font(theme.display(30)).foregroundStyle(theme.text)
                    Text("You mentioned thoughts of being better off dead or of hurting yourself. Please reach out to someone today — a person you trust, your doctor, or a helpline. Talking helps.")
                        .font(theme.body).foregroundStyle(theme.text)
                    Button("Call 1122 (Pakistan emergency)") { openURL(URL(string: "tel:1122")!) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Find a free, confidential helpline") { openURL(URL(string: "https://findahelpline.com")!) }
                        .buttonStyle(SecondaryButtonStyle())
                    Text("Outside Pakistan, call your local emergency number. This app can't respond to emergencies.")
                        .font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                .padding(20)
            }
            .background(ThemedBackground())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
        }
    }
}
