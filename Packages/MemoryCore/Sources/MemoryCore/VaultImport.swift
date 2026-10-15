import Foundation

/// Parses pasted cards: one per line, "front;back", "front<TAB>back" or "front,back".
/// Cloze passages: a line with {{c::…}} becomes one card per gap.
public enum VaultImport {
    public struct Card: Equatable, Sendable {
        public var prompt: String
        public var answer: String
    }

    public static func parse(_ text: String) -> [Card] {
        var cards: [Card] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.contains("{{c::") {
                cards.append(contentsOf: cloze(line))
                continue
            }
            for sep in ["\t", ";", ","] where line.contains(sep) {
                let parts = line.components(separatedBy: sep)
                let front = parts[0].trimmingCharacters(in: .whitespaces)
                let back = parts.dropFirst().joined(separator: sep).trimmingCharacters(in: .whitespaces)
                if !front.isEmpty && !back.isEmpty { cards.append(Card(prompt: front, answer: back)) }
                break
            }
        }
        return cards
    }

    /// "The {{c::hippocampus}} binds memories" → prompt with "[…]", answer "hippocampus".
    public static func cloze(_ line: String) -> [Card] {
        let pattern = try! NSRegularExpression(pattern: "\\{\\{c::(.+?)\\}\\}")
        let ns = line as NSString
        let matches = pattern.matches(in: line, range: NSRange(location: 0, length: ns.length))
        return matches.map { m in
            let answer = ns.substring(with: m.range(at: 1))
            var prompt = ns.replacingCharacters(in: m.range, with: "[…]")
            prompt = pattern.stringByReplacingMatches(in: prompt, range: NSRange(location: 0, length: (prompt as NSString).length), withTemplate: "$1")
            return Card(prompt: prompt, answer: answer)
        }
    }

    /// Starter packs.
    public static var majorPegs: [Card] {
        MajorSystem.pegs.enumerated().map { Card(prompt: String(format: "%02d", $0.offset), answer: $0.element) }
    }

    public static let capitals: [Card] = [
        ("Pakistan", "Islamabad"), ("Turkey", "Ankara"), ("Australia", "Canberra"), ("Canada", "Ottawa"),
        ("Brazil", "Brasília"), ("Nigeria", "Abuja"), ("Morocco", "Rabat"), ("Kazakhstan", "Astana"),
        ("New Zealand", "Wellington"), ("Switzerland", "Bern"), ("Vietnam", "Hanoi"), ("Myanmar", "Naypyidaw"),
        ("Sri Lanka", "Sri Jayawardenepura Kotte"), ("Tanzania", "Dodoma"), ("Bolivia", "Sucre"), ("Malaysia", "Kuala Lumpur"),
        ("Indonesia", "Jakarta"), ("Egypt", "Cairo"), ("Iran", "Tehran"), ("Saudi Arabia", "Riyadh"),
        ("Japan", "Tokyo"), ("South Korea", "Seoul"), ("Norway", "Oslo"), ("Finland", "Helsinki"),
        ("Portugal", "Lisbon"), ("Kenya", "Nairobi"), ("Chile", "Santiago"), ("Peru", "Lima"),
        ("Mongolia", "Ulaanbaatar"), ("Iceland", "Reykjavík"),
    ].map { Card(prompt: "Capital of \($0.0)?", answer: $0.1) }
}
