import Foundation
import Security
import SwiftData

/// Supporter alerts without paid push.
///
/// * With Supabase configured: the app upserts a tiny `daily_status` row (done / sessions / weekly
///   streak — **no scores**). Postgres then posts to ntfy by itself: "done" via a trigger, and
///   "no quest yet" / weekly summary via pg_cron. See `backend/supabase/migrations/001_init.sql`.
/// * Without Supabase: the app posts "done" straight to each supporter's ntfy topic. ("Missed"
///   alerts need the server, because a phone can't report what it didn't do.)
@MainActor
final class CircleService {
    static let shared = CircleService()

    struct Config {
        var url: URL
        var anonKey: String
    }

    /// Reads `Backend.plist` in the bundle, overridable in Settings → Circle server.
    var config: Config? {
        let defaults = UserDefaults.standard
        let bundled = Bundle.main.url(forResource: "Backend", withExtension: "plist")
            .flatMap { NSDictionary(contentsOf: $0) as? [String: String] } ?? [:]
        let urlString = defaults.string(forKey: "supabase.url").flatMap { $0.isEmpty ? nil : $0 } ?? bundled["SUPABASE_URL"] ?? ""
        let key = defaults.string(forKey: "supabase.anonKey").flatMap { $0.isEmpty ? nil : $0 } ?? bundled["SUPABASE_ANON_KEY"] ?? ""
        guard !key.isEmpty, !urlString.contains("YOUR-PROJECT"), let url = URL(string: urlString), url.scheme == "https" else { return nil }
        return Config(url: url, anonKey: key)
    }

    var isServerConfigured: Bool { config != nil }

    private(set) var lastError: String?

    // MARK: Auth (Supabase anonymous sign-in)

    private struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var userID: String
        var expiresAt: Date
    }

    private var session: Session? {
        get { Keychain.read("supabase.session").flatMap { try? JSONDecoder().decode(Session.self, from: $0) } }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) { Keychain.write("supabase.session", data) }
            else { Keychain.delete("supabase.session") }
        }
    }

    private func validSession(_ config: Config) async throws -> Session {
        if let s = session, s.expiresAt > Date().addingTimeInterval(60) { return s }
        if let s = session, let refreshed = try? await authRequest(config, path: "token?grant_type=refresh_token",
                                                                   body: ["refresh_token": s.refreshToken]) {
            session = refreshed
            return refreshed
        }
        let fresh = try await authRequest(config, path: "signup", body: ["data": [String: String]()])
        session = fresh
        return fresh
    }

    private func authRequest(_ config: Config, path: String, body: [String: Any]) async throws -> Session {
        var req = URLRequest(url: URL(string: "\(config.url.absoluteString)/auth/v1/\(path)")!)
        req.httpMethod = "POST"
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any], let id = user["id"] as? String else {
            throw CircleError.server(String(data: data, encoding: .utf8) ?? "auth failed")
        }
        let expiresIn = json["expires_in"] as? Double ?? 3600
        return Session(accessToken: access, refreshToken: refresh, userID: id, expiresAt: Date().addingTimeInterval(expiresIn))
    }

    // MARK: REST helpers

    private func rest(_ method: String, _ path: String, body: Any? = nil, prefer: String? = nil) async throws {
        guard let config else { throw CircleError.notConfigured }
        let s = try await validSession(config)
        var req = URLRequest(url: URL(string: "\(config.url.absoluteString)/rest/v1/\(path)")!)
        req.httpMethod = method
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(s.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CircleError.server(String(data: data, encoding: .utf8) ?? "request failed")
        }
    }

    private let upsert = "resolution=merge-duplicates,return=minimal"

    // MARK: Sync

    /// Pushes the trainee row + supporters (topics, alert times). Call after Circle edits.
    func syncCircle(profile: Profile) async {
        guard let config else { return }
        do {
            let s = try await validSession(config)
            try await rest("POST", "trainees", body: [[
                "id": s.userID,
                "display_name": profile.displayName.isEmpty ? profile.mascotName : profile.displayName,
                "mascot_name": profile.mascotName,
                "theme": profile.themeRaw,
                "timezone": profile.timezoneID,
                "nudge_whatsapp": digits(profile.whatsappNumber),
            ] as [String: Any]], prefer: upsert)

            let supporters = (try? Store.context.fetch(FetchDescriptor<Supporter>())) ?? []
            // Remove supporters (or rotated topics) we no longer have, then upsert the rest by topic —
            // upserting keeps the server's "already alerted today" bookkeeping intact.
            let keep = supporters.map(\.topic).joined(separator: ",")
            try await rest("DELETE", supporters.isEmpty ? "supporters?trainee_id=eq.\(s.userID)"
                                                        : "supporters?trainee_id=eq.\(s.userID)&ntfy_topic=not.in.(\(keep))")
            if !supporters.isEmpty {
                try await rest("POST", "supporters?on_conflict=ntfy_topic", body: supporters.map { sup in [
                    "trainee_id": s.userID,
                    "label": sup.label,
                    "ntfy_topic": sup.topic,
                    "notify_on_done": sup.notifyOnDone,
                    "weekly_summary": sup.shareWeeklyCount,
                    "missed_check_local": String(format: "%02d:%02d", sup.missedHour, sup.missedMinute),
                ] as [String: Any] }, prefer: upsert)
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Reports today's completion. Server triggers the "done" alert exactly once per day.
    func reportToday(profile: Profile) async {
        let record = Store.dayRecord()
        if config == nil {
            await directDoneAlertIfNeeded(profile: profile, done: record.questDone)
            return
        }
        do {
            let s = try await validSession(config!)
            let day = Self.isoDay.string(from: Date())
            try await rest("POST", "daily_status", body: [[
                "trainee_id": s.userID,
                "day": day,
                "done": record.questDone,
                "sessions": record.stepsDone,
                "streak_weeks": Quest.weeklyStreak(),
            ] as [String: Any]], prefer: upsert)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteServerData() async {
        guard config != nil else { return }
        try? await rest("POST", "rpc/delete_me", body: [String: String]())
        session = nil
    }

    // MARK: ntfy (direct)

    private func directDoneAlertIfNeeded(profile: Profile, done: Bool) async {
        guard done else { return }
        let key = "ntfy.doneSent.\(Self.isoDay.string(from: Date()))"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let supporters = ((try? Store.context.fetch(FetchDescriptor<Supporter>())) ?? []).filter(\.notifyOnDone)
        guard !supporters.isEmpty else { return }
        for sup in supporters {
            try? await publish(topic: sup.topic, message: doneMessage(profile: profile))
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    struct NtfyMessage {
        var title: String
        var body: String
        var tags: [String]
        var actions: [[String: String]] = []
    }

    func doneMessage(profile: Profile) -> NtfyMessage {
        let name = profile.displayName.isEmpty ? profile.mascotName : profile.displayName
        let raccoon = profile.theme == .midnightRaccoon
        return NtfyMessage(
            title: raccoon ? "\(name)'s den got cozier today" : "\(name) finished today's practice",
            body: raccoon ? "Quest complete! Send a little cheer?" : "All done for today. A kind word goes a long way.",
            tags: [raccoon ? "raccoon" : "sparkles"],
            actions: nudgeAction(profile: profile, text: raccoon ? "Proud of you and \(profile.mascotName)" : "Well done today!", label: "Send a cheer")
        )
    }

    func nudgeAction(profile: Profile, text: String, label: String) -> [[String: String]] {
        let number = digits(profile.whatsappNumber)
        guard !number.isEmpty,
              let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        return [["action": "view", "label": label, "url": "https://wa.me/\(number)?text=\(encoded)"]]
    }

    func publish(topic: String, message: NtfyMessage) async throws {
        var req = URLRequest(url: URL(string: "https://ntfy.sh/")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var json: [String: Any] = ["topic": topic, "title": message.title, "message": message.body, "tags": message.tags]
        if !message.actions.isEmpty { json["actions"] = message.actions }
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CircleError.server("ntfy rejected the message")
        }
    }

    func sendTest(to supporter: Supporter, profile: Profile) async -> Bool {
        let msg = NtfyMessage(title: "Test from Memory Garden",
                              body: "You're subscribed! You'll get completion-only updates for \(profile.displayName.isEmpty ? profile.mascotName : profile.displayName).",
                              tags: ["tada"],
                              actions: nudgeAction(profile: profile, text: "Got your test alert!", label: "Say hi on WhatsApp"))
        return (try? await publish(topic: supporter.topic, message: msg)) != nil
    }

    // MARK: Utils

    func digits(_ s: String) -> String { s.filter(\.isNumber) }

    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    enum CircleError: LocalizedError {
        case notConfigured
        case server(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Server not set up (optional)."
            case .server(let s): return s
            }
        }
    }
}

/// Minimal Keychain wrapper for the anonymous session token.
enum Keychain {
    private static let service = "MemoryGarden"

    static func write(_ key: String, _ data: Data) {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
