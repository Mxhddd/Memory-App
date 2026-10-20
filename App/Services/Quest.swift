import Foundation
import SwiftData
import MemoryCore

/// One step of today's training session.
enum QuestStepKind: Hashable {
    case vault                       // spaced-repetition warm-up
    case lesson(String)              // Memory Palace lesson
    case task(RealmTask, size: Int)  // a drill or benchmark
}

struct QuestStep: Identifiable, Hashable {
    var kind: QuestStepKind
    var done: Bool
    var isBenchmark: Bool = false
    var id: String {
        switch kind {
        case .vault: return "vault"
        case .lesson(let id): return "lesson-\(id)"
        case .task(let t, let size): return "\(t.rawValue)-\(size)"
        }
    }
}

/// Builds today's session and records results.
///
///  1. Vault warm-up (due cards)
///  2. Memory Palace course day: lesson + drills (the course only advances on days you train)
///  3. Yesterday's sprint, recalled again (consolidation check)
///  4. Working-memory gym on alternate days
///  5. Benchmarks on days 0, 14, 28, 42, then monthly (technique-free transfer tests)
@MainActor
enum Quest {
    static func salt(_ profile: Profile) -> String { String(Int(profile.createdAt.timeIntervalSince1970)) }

    // MARK: Queries

    static func sessions(on date: Date = Date()) -> [TaskSession] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let d = FetchDescriptor<TaskSession>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return (try? Store.context.fetch(d)) ?? []
    }

    static func cardCount() -> Int {
        (try? Store.context.fetchCount(FetchDescriptor<MemoryCard>())) ?? 0
    }

    static func dueCards(_ now: Date = Date()) -> [MemoryCard] {
        let d = FetchDescriptor<MemoryCard>(predicate: #Predicate { $0.due <= now }, sortBy: [SortDescriptor(\.due)])
        return (try? Store.context.fetch(d)) ?? []
    }

    static func palaces() -> [Palace] {
        (try? Store.context.fetch(FetchDescriptor<Palace>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    /// The palace to use today: least recently used with enough stops (rotation limits interference).
    static func palace(forItems items: Int) -> Palace? {
        let all = palaces()
        let fitting = all.filter { $0.stops.count >= items }
        let pool = fitting.isEmpty ? all : fitting
        return pool.min { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
    }

    // MARK: Plan

    /// Today's course day: pinned to the day the session started on (see `DayRecord.planCourseDay`).
    static func courseDay(_ profile: Profile, date: Date = Date()) -> CourseDay {
        let day = Store.dayRecord(for: date).planCourseDay ?? profile.courseDay
        return Course.day(day, wordLevel: profile.wordLevel, digitLevel: profile.digitLevel)
    }

    /// Fixes today's plan to the current course day the first time anything is done today.
    static func pinPlan(_ profile: Profile) {
        let record = Store.dayRecord()
        if record.planCourseDay == nil { record.planCourseDay = profile.courseDay }
    }

    static func isGymDay(_ profile: Profile, date: Date = Date()) -> Bool {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return profile.dailyMinutes >= 25 || day % 2 == 0
    }

    static func benchmarkDue(_ profile: Profile, date: Date = Date()) -> Bool {
        profile.benchmarks.isDue(on: date, lastCompleted: profile.lastBenchmark)
            || sessions(on: date).contains { $0.isBenchmark } // keep showing today's battery once started
    }

    static func yesterdaysSprint() -> TaskSession? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        return sessions(on: yesterday).filter { $0.task == .wordSprint }.max { $0.level < $1.level }
    }

    static func steps(for profile: Profile, date: Date = Date()) -> [QuestStep] {
        let today = sessions(on: date)
        func done(_ t: RealmTask) -> Bool { today.contains { $0.task == t } }
        var steps: [QuestStep] = []

        if !dueCards(date).isEmpty || Store.dayRecord(for: date).vaultDone {
            steps.append(QuestStep(kind: .vault, done: Store.dayRecord(for: date).vaultDone))
        }

        if benchmarkDue(profile, date: date) {
            steps.append(QuestStep(kind: .task(.wordRecall, size: WordBank.benchmarkFormSize), done: done(.wordRecall), isBenchmark: true))
            steps.append(QuestStep(kind: .task(.digitSpan, size: 3), done: done(.digitSpan), isBenchmark: true))
        }

        let course = courseDay(profile, date: date)
        if let lesson = course.lesson {
            steps.append(QuestStep(kind: .lesson(lesson.id), done: profile.lessonsRead.contains(lesson.id)))
        }
        for drill in course.drills {
            let task = Self.task(for: drill.kind)
            steps.append(QuestStep(kind: .task(task, size: drill.size), done: done(task)))
        }

        if let sprint = yesterdaysSprint() {
            steps.append(QuestStep(kind: .task(.sprintRetention, size: sprint.level), done: done(.sprintRetention)))
        }

        if isGymDay(profile, date: date) {
            steps.append(QuestStep(kind: .task(.dualNBack, size: profile.nBackLevel), done: done(.dualNBack)))
            if profile.dailyMinutes >= 25 {
                steps.append(QuestStep(kind: .task(.complexSpan, size: 0), done: done(.complexSpan)))
            }
        }
        return steps
    }

    static func task(for kind: DrillKind) -> RealmTask {
        switch kind {
        case .routeWalk: return .routeWalk
        case .wordSprint: return .wordSprint
        case .numberSprint: return .numberSprint
        case .faceName: return .faceName
        }
    }

    // MARK: Contexts

    static func context(for task: RealmTask, size: Int, profile: Profile, date: Date = Date()) -> GameContext {
        let stamp = Notifications.dayStamp(date)
        var seed = "\(salt(profile))-\(stamp)-\(task.rawValue)"
        if task == .wordRecall { seed = "benchmark" } // fixed forms; the form index rotates
        if task == .sprintRetention, let s = yesterdaysSprint() { seed = s.seed }
        let level = task.domain == .associative ? DifficultyStore.level(for: task) : 2
        let size = task == .sequences ? profile.sequenceSpan : size
        let palace = [.wordSprint, .sprintRetention, .routeWalk].contains(task) ? palace(forItems: size) : nil
        return GameContext(task: task, seed: seed, size: size, level: level, courseDay: profile.courseDay,
                           palaceID: palace?.id, benchmarkForm: BenchmarkPlanner.form(forSession: profile.benchmarkCount),
                           isBenchmark: task.isBenchmark)
    }

    // MARK: Recording

    /// Saves a finished game, adapts levels, and returns true if this completed today's session.
    @discardableResult
    static func record(_ outcome: GameOutcome, ctx: GameContext, profile: Profile) -> Bool {
        pinPlan(profile)
        let session = TaskSession(task: ctx.task, correct: outcome.correct, total: outcome.total, meanRTms: outcome.meanRTms,
                                  score: outcome.score, level: outcome.level ?? ctx.size, seed: ctx.seed,
                                  courseDay: profile.courseDay, isBenchmark: ctx.isBenchmark)
        Store.context.insert(session)

        switch ctx.task {
        case .wordSprint:
            profile.wordLevel = Course.nextWordLevel(current: max(profile.wordLevel, ctx.size), accuracy: outcome.score)
        case .numberSprint:
            profile.digitLevel = Course.nextDigitLevel(current: max(profile.digitLevel, ctx.size), accuracy: outcome.score)
        case .dualNBack:
            if let next = outcome.nextLevel { profile.nBackLevel = next }
        case .sequences:
            if let next = outcome.nextLevel { profile.sequenceSpan = max(2, next) }
            if !outcome.trials.isEmpty { DifficultyStore.record(outcome.trials, for: ctx.task) }
        case .faceName, .ancientRunes, .stash:
            if !outcome.trials.isEmpty { DifficultyStore.record(outcome.trials, for: ctx.task) }
        default: break
        }
        if let id = ctx.palaceID, let palace = palaces().first(where: { $0.id == id }) { palace.lastUsed = Date() }
        profile.shinies += 1

        if ctx.isBenchmark {
            let battery: Set<RealmTask> = [.wordRecall, .digitSpan]
            let doneToday = Set(sessions().filter(\.isBenchmark).map(\.task)).union([ctx.task])
            if battery.isSubset(of: doneToday), !Calendar.current.isDateInToday(profile.lastBenchmark ?? .distantPast) {
                profile.lastBenchmark = Date()
                profile.benchmarkCount += 1
            }
        }
        Store.save()
        advanceCourseIfDone(profile)
        return refreshCompletion(profile)
    }

    static func markLessonRead(_ id: String, profile: Profile) -> Bool {
        pinPlan(profile)
        if !profile.lessonsRead.contains(id) { profile.lessonsRead.append(id) }
        Store.save()
        advanceCourseIfDone(profile)
        return refreshCompletion(profile)
    }

    static func markVaultDone(profile: Profile) -> Bool {
        pinPlan(profile)
        Store.dayRecord().vaultDone = true
        profile.shinies += 1
        Store.save()
        return refreshCompletion(profile)
    }

    /// The course moves to the next day once today's lesson and drills are done — at most once a day.
    static func advanceCourseIfDone(_ profile: Profile) {
        guard !Calendar.current.isDateInToday(profile.lastCourseAdvance ?? .distantPast) else { return }
        let course = courseDay(profile)
        let today = sessions()
        let lessonDone = course.lesson.map { profile.lessonsRead.contains($0.id) } ?? true
        let drillsDone = course.drills.allSatisfy { d in today.contains { $0.task == task(for: d.kind) } }
        if lessonDone && drillsDone && profile.courseDay < Course.length {
            profile.courseDay += 1
            profile.lastCourseAdvance = Date()
            Store.save()
        }
    }

    /// Updates the day record and fires side effects. Returns true when the session *just* completed.
    @discardableResult
    static func refreshCompletion(_ profile: Profile) -> Bool {
        let s = steps(for: profile)
        let record = Store.dayRecord()
        record.stepsTotal = s.count
        record.stepsDone = s.filter(\.done).count
        var justCompleted = false
        if !record.questDone && !s.isEmpty && s.allSatisfy(\.done) {
            record.questDone = true
            record.completedAt = Date()
            profile.shinies += 3
            justCompleted = true
        }
        Store.save()
        AppEvents.questChanged(profile: profile, justCompleted: justCompleted)
        return justCompleted
    }

    // MARK: Streaks

    /// Consecutive weeks (Mon–Sun) with ≥ 4 training days — forgiving weekly streaks.
    static func weeklyStreak() -> Int {
        let records = (try? Store.context.fetch(FetchDescriptor<DayRecord>(predicate: #Predicate { $0.questDone == true }))) ?? []
        var cal = Calendar.current
        cal.firstWeekday = 2
        let byWeek = Dictionary(grouping: records) { cal.dateInterval(of: .weekOfYear, for: $0.day)?.start ?? $0.day }
        var streak = 0
        var week = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        if (byWeek[week]?.count ?? 0) < 4 { week = cal.date(byAdding: .weekOfYear, value: -1, to: week)! }
        while (byWeek[week]?.count ?? 0) >= 4 {
            streak += 1
            week = cal.date(byAdding: .weekOfYear, value: -1, to: week)!
        }
        return streak
    }

    static func activeDays(last days: Int) -> Int {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let d = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.questDone == true && $0.day >= since })
        return (try? Store.context.fetchCount(d)) ?? 0
    }

    static func questDays(thisWeek date: Date = Date()) -> Int {
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let start = cal.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        let d = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.questDone == true && $0.day >= start })
        return (try? Store.context.fetchCount(d)) ?? 0
    }
}

/// Fan-out of side effects whenever session progress changes.
@MainActor
enum AppEvents {
    static func questChanged(profile: Profile, justCompleted: Bool) {
        WidgetBridge.update(profile: profile)
        LiveActivityService.sync(profile: profile)
        Notifications.replan(profile: profile)
        if justCompleted {
            Task { await CircleService.shared.reportToday(profile: profile) }
        }
    }

    /// Called on launch / foreground.
    static func appBecameActive() {
        guard let profile = Store.profile(), profile.onboardingComplete else { return }
        _ = Quest.refreshCompletion(profile)
        Task { await CircleService.shared.reportToday(profile: profile) }
    }
}
