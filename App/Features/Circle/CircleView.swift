import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins
import MemoryCore

/// Supporters get *completion-only* alerts in the free ntfy app — never scores or health details.
/// Each supporter has their own unguessable topic; removing them (or "new link") revokes access.
struct CircleView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \Supporter.createdAt) private var supporters: [Supporter]
    @State private var inviting: Supporter?
    @State private var newLabel = ""
    @State private var status: String?

    var body: some View {
        List {
            Section {
                Text("Pick who gets a tiny ping when you finish (and, optionally, if you haven't by evening). They see **only** whether you practised — never scores, answers or check-ins.")
                    .font(theme.body).foregroundStyle(theme.text)
            }
            .listRowBackground(theme.surface)

            Section("Supporters") {
                ForEach(supporters) { s in
                    Button { inviting = s } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(theme.primary)
                            VStack(alignment: .leading) {
                                Text(s.label).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                                Text(s.notifyOnDone ? "Done alerts · evening nudge \(String(format: "%02d:%02d", s.missedHour, s.missedMinute))" : "Evening nudge only")
                                    .font(theme.caption).foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "qrcode").foregroundStyle(theme.text)
                        }
                        .frame(minHeight: theme.minTouch)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(supporters[i]) }
                    try? context.save()
                    sync()
                }
                HStack {
                    TextField("Name (e.g. Ali, or Mom's helper)", text: $newLabel)
                    Button("Add") {
                        let s = Supporter(label: newLabel.trimmingCharacters(in: .whitespaces))
                        context.insert(s)
                        try? context.save()
                        newLabel = ""
                        inviting = s
                        sync()
                    }
                    .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .listRowBackground(theme.surface)

            Section {
                TextField("Your WhatsApp number, e.g. 923001234567", text: $profile.whatsappNumber)
                    .keyboardType(.phonePad)
                    .onSubmit { try? context.save(); sync() }
                    // The phone keypad has no Return key, so also save when the number changes.
                    .onChange(of: profile.whatsappNumber) { _, _ in try? context.save(); sync() }
            } header: {
                Text("Cheer button")
            } footer: {
                Text("Supporters' alerts get a “Send a cheer” button that opens WhatsApp to message you. Free — it uses their own WhatsApp. Include the country code, no +.")
            }
            .listRowBackground(theme.surface)

            Section {
                Label(CircleService.shared.isServerConfigured ? "Server connected — evening nudges & weekly summaries on" : "No server yet — supporters still get “done” alerts",
                      systemImage: CircleService.shared.isServerConfigured ? "checkmark.icloud.fill" : "icloud.slash")
                    .foregroundStyle(theme.text)
                if let status { Text(status).font(.footnote).foregroundStyle(theme.secondaryText) }
            } footer: {
                Text("“Hasn't practised yet” alerts need the free Supabase server (see docs/INSTALL.md), because a phone can't report what it didn't do.")
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Your circle")
        .sheet(item: $inviting) { s in
            SupporterInviteView(supporter: s, profile: profile, onChange: sync).environment(\.theme, theme)
        }
    }

    private func sync() {
        Task {
            await CircleService.shared.syncCircle(profile: profile)
            status = CircleService.shared.lastError.map { "Couldn't reach the server: \($0)" }
        }
    }
}

struct SupporterInviteView: View {
    @Bindable var supporter: Supporter
    let profile: Profile
    let onChange: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var testResult: String?
    @State private var missed = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        if let qr = QRCode.image(for: supporter.subscribeURL.absoluteString) {
                            Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 200, height: 200)
                                .accessibilityLabel("QR code for \(supporter.label)'s alert link")
                        }
                        Text(supporter.topic).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        ShareLink(item: supporter.subscribeURL, message: Text(shareText)) {
                            Label("Send the link", systemImage: "square.and.arrow.up")
                        }
                    }
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("For \(supporter.label)")
                } footer: {
                    Text("\(supporter.label): install the free **ntfy** app → tap + → paste the topic above (server ntfy.sh), or just open the link. That's it — no account needed.")
                }

                Section("Alerts") {
                    Toggle("When the quest is done", isOn: $supporter.notifyOnDone)
                    DatePicker("“Not yet” nudge at", selection: $missed, displayedComponents: .hourAndMinute)
                    Toggle("Sunday summary (days practised)", isOn: $supporter.shareWeeklyCount)
                }

                Section {
                    Button("Send a test alert") {
                        Task {
                            let ok = await CircleService.shared.sendTest(to: supporter, profile: profile)
                            testResult = ok ? "Sent! It should pop up on their phone." : "Couldn't send — check the internet connection."
                        }
                    }
                    if let testResult { Text(testResult).font(.footnote) }
                    Button("New link (revokes the old one)", role: .destructive) {
                        supporter.topic = Supporter.newTopic()
                        onChange()
                    }
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let hm = Calendar.current.dateComponents([.hour, .minute], from: missed)
                        supporter.missedHour = hm.hour ?? 20
                        supporter.missedMinute = hm.minute ?? 30
                        try? Store.context.save()
                        onChange()
                        dismiss()
                    }
                }
            }
            .onAppear {
                missed = Calendar.current.date(bySettingHour: supporter.missedHour, minute: supporter.missedMinute, second: 0, of: Date()) ?? Date()
            }
        }
    }

    private var shareText: String {
        "Install the free ntfy app and subscribe to this to get a little ping when I practise in Memory Garden"
    }
}

enum QRCode {
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
