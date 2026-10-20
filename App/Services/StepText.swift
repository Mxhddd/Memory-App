import Foundation
import MemoryCore

/// How a step of the day's plan is named and drawn, shared by Today, the widgets, the
/// Live Activity / Dynamic Island and App Shortcuts so they always agree.
enum StepText {
    static func title(_ step: QuestStep, theme: Theme) -> String {
        switch step.kind {
        case .vault: return "Vault warm-up"
        case .lesson(let id): return "Lesson · \(Course.lesson(id)?.title ?? "")"
        case .task(let t, let size):
            switch t {
            case .wordSprint, .sprintRetention, .listReview: return "\(theme.copy.realmName(t)) · \(size) words"
            case .numberSprint: return "\(theme.copy.realmName(t)) · \(size) digits"
            case .dualNBack: return "\(theme.copy.realmName(t)) · \(size)-back"
            default: return theme.copy.realmName(t)
            }
        }
    }

    @MainActor static func subtitle(_ step: QuestStep, theme: Theme, profile: Profile) -> String {
        switch step.kind {
        case .vault:
            let due = Quest.dueCards().count
            return due > 0 ? "\(due) cards ready — recall before you reveal" : "Cards reviewed"
        case .lesson: return "A few minutes of technique"
        case .task(let t, let size):
            if step.isBenchmark && Quest.inBaseline(profile) {
                return "Baseline \(min(3, profile.benchmarkCount + (Quest.benchmarkDoneToday(profile) ? 0 : 1))) of 3 · " + (t == .wordRecall ? "30 words" : "digits in order")
            }
            switch t {
            case .listReview: return "\(size) words from \(step.reviewOffset) days ago"
            case .championTest: return "72 words · about 35 min"
            case .championDelayed: return "Yesterday's 72 words"
            default: return theme.copy.realmBlurb(t)
            }
        }
    }

    static func symbol(_ step: QuestStep) -> String {
        switch step.kind {
        case .vault: return "rectangle.stack.fill"
        case .lesson: return "book.fill"
        case .task(let t, _):
            switch t {
            case .routeWalk: return "figure.walk"
            case .wordSprint, .sprintRetention: return "building.columns.fill"
            case .numberSprint: return "number"
            case .dualNBack: return "square.grid.3x3.fill"
            case .complexSpan: return "plusminus"
            case .sequences: return "sparkles"
            case .faceName: return "person.2.fill"
            case .ancientRunes: return "character.book.closed.fill"
            case .stash: return "shippingbox.fill"
            case .wordRecall, .digitSpan: return "flag.checkered"
            case .championTest: return "trophy.fill"
            case .championDelayed: return "sunrise.fill"
            case .listReview: return "arrow.counterclockwise"
            }
        }
    }
}
