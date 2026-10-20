import Foundation

/// A free Apple ID signs apps for 7 days. SideStore embeds the profile it signed with as
/// `embedded.mobileprovision`; its `ExpirationDate` is when the app stops opening unless
/// SideStore refreshes it first. Reading it lets the app warn before that happens.
enum SigningInfo {
    /// Expiry of this install's signature (nil for App Store/TestFlight or simulator builds).
    static let expiry: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return parseExpiry(data)
    }()

    /// The profile is a CMS envelope around an XML plist; the plist is plain text inside it.
    static func parseExpiry(_ data: Data) -> Date? {
        guard let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"), let end = text.range(of: "</plist>", range: start.upperBound..<text.endIndex) else { return nil }
        let xml = Data(text[start.lowerBound..<end.upperBound].utf8)
        let plist = try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }

    /// Whole days left before the signature expires (rounded down), or nil if unknown.
    static func daysLeft(now: Date = Date()) -> Int? {
        guard let expiry else { return nil }
        return max(0, Int(expiry.timeIntervalSince(now) / 86_400))
    }

    static func hoursLeft(now: Date = Date()) -> Double? {
        expiry.map { $0.timeIntervalSince(now) / 3600 }
    }

    /// Opens SideStore so the person can tap Refresh.
    static let sideStoreURL = URL(string: "sidestore://")!
}
