import Foundation
import SwiftData
import WidgetKit
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
    var reviewOffset: Int = 0
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
///  2. Benchmarks: three baseline days first, then days 14, 28, 42 and monthly (technique-free)
///  3. Champion test on the first course day, at the end and monthly; its recall the next day
///  4. Memory Palace course day: lesson + drills (waits for the baseline; advances on days you train)
///  5. Yesterday's sprint recalled again, plus at most one older list (3, 7 or 21 days on)
///  6. Working-memory gym on alternate days
@MainActor
enum Quest {
    static func salt(_ profile: Profile) -> String { String(Int(profile.createdAt.timeIntervalSince1970)) }

    // MARK: Queries

    /// Sessions that count toward the day's plan (free play from the Train tab doesn't).
    static func planSessions(on date: Date = Date()) -> [TaskSession] { sessions(on: date).filter { !$0.isFreePlay } }

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

    /// Fixes the day's plan to the current course day the first time anything is done that day.
    static func pinPlan(_ profile: Profile, date: Date = Date()) {
        let record = Store.dayRecord(for: date)
        if record.planCourseDay == nil { record.planCourseDay = profile.courseDay }
    }

    static func isGymDay(_ profile: Profile, date: Date = Date()) -> Bool {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return profile.dailyMinutes >= 25 || day % 2 == 0
    }

    static func benchmarkDue(_ profile: Profile, date: Date = Date()) -> Bool {
        profile.benchmarks.isDue(on: date, lastCompleted: profile.lastBenchmark, completed: profile.benchmarkCount)
            || planSessions(on: date).contains { $0.isBenchmark } // keep showing today's battery once started
    }

    static func benchmarkDoneToday(_ profile: Profile, date: Date = Date()) -> Bool {
        Calendar.current.isDate(profile.lastBenchmark ?? .distantPast, inSameDayAs: date)
    }

    /// The first three benchmark days are a personal baseline: no technique yet, so the course waits.
    static func inBaseline(_ profile: Profile, date: Date = Date()) -> Bool {
        profile.benchmarkCount - (benchmarkDoneToday(profile, date: date) ? 1 : 0) < BenchmarkPlanner.baselineSessions
    }

    static func championYesterday(date: Date = Date()) -> TaskSession? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        return sessions(on: yesterday).first { $0.task == .championTest }
    }

    static func championDue(_ profile: Profile, date: Date = Date()) -> Bool {
        if planSessions(on: date).contains(where: { $0.task == .championTest }) { return true }
        let plan = Store.dayRecord(for: date).planCourseDay ?? profile.courseDay
        let since = profile.lastChampion.flatMap { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0), to: Calendar.current.startOfDay(for: date)).day }
        return ChampionTest.isDue(courseDay: plan, taken: profile.championCount, daysSinceLast: since)
    }

    static func dayIndex(_ date: Date) -> Int { Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0 }

    /// The best sprint of each recent day: the lists that come back 3, 7 and 21 days later.
    static func sprintLists(date: Date = Date()) -> [(list: ListReview.List, palaceID: UUID?)] {
        let since = Calendar.current.date(byAdding: .day, value: -40, to: date)!
        let raw = RealmTask.wordSprint.rawValue
        let d = FetchDescriptor<TaskSession>(predicate: #Predicate { $0.taskRaw == raw && $0.date >= since })
        let all = (try? Store.context.fetch(d)) ?? []
        var lists: [(list: ListReview.List, palaceID: UUID?)] = []
        for (day, sameDay) in Dictionary(grouping: all, by: { dayIndex($0.date) }) {
            guard let best = sameDay.max(by: { $0.level < $1.level }) else { continue }
            lists.append((list: ListReview.List(seed: best.seed, size: best.level, day: day), palaceID: best.palaceID))
        }
        return lists
    }

    /// Today's later re-recall: the one already played today, or the most overdue one.
    static func listReviewFor(date: Date = Date()) -> (due: ListReview.Due, done: Bool)? {
        if let s = planSessions(on: date).first(where: { $0.task == .listReview }) {
            return (due: ListReview.Due(seed: s.seed, size: s.level, offset: s.reviewOffset), done: true)
        }
        let raw = RealmTask.listReview.rawValue
        let reviews = (try? Store.context.fetch(FetchDescriptor<TaskSession>(predicate: #Predicate { $0.taskRaw == raw }))) ?? []
        let done = Set(reviews.map { ListReview.key(seed: $0.seed, offset: $0.reviewOffset) })
        guard let due = ListReview.due(lists: sprintLists(date: date).map(\.list), done: done, today: dayIndex(date)) else { return nil }
        return (due: due, done: false)
    }

    static func yesterdaysSprint(date: Date = Date()) -> TaskSession? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        return sessions(on: yesterday).filter { $0.task == .wordSprint }.max { $0.level < $1.level }
    }

    static func steps(for profile: Profile, date: Date = Date()) -> [QuestStep] {
        let today = planSessions(on: date)
        func done(_ t: RealmTask) -> Bool { today.contains { $0.task == t } }
        var steps: [QuestStep] = []

        if !dueCards(date).isEmpty || Store.dayRecord(for: date).vaultDone {
            steps.append(QuestStep(kind: .vault, done: Store.dayRecord(for: date).vaultDone))
        }

        if benchmarkDue(profile, date: date) {
            steps.append(QuestStep(kind: .task(.wordRecall, size: WordBank.benchmarkFormSize), done: done(.wordRecall), isBenchmark: true))
            steps.append(QuestStep(kind: .task(.digitSpan, size: 3), done: done(.digitSpan), isBenchmark: true))
        }

        if !inBaseline(profile, date: date) {
            if championYesterday(date: date) != nil || done(.championDelayed) {
                steps.append(QuestStep(kind: .task(.championDelayed, size: ChampionTest.size), done: done(.championDelayed)))
            }
            if championDue(profile, date: date) {
                steps.append(QuestStep(kind: .task(.championTest, size: ChampionTest.size), done: done(.championTest)))
            }
            let course = courseDay(profile, date: date)
            if let lesson = course.lesson {
                steps.append(QuestStep(kind: .lesson(lesson.id), done: profile.lessonsRead.contains(lesson.id)))
            }
            for drill in course.drills {
                let task = Self.task(for: drill.kind)
                steps.append(QuestStep(kind: .task(task, size: drill.size), done: done(task)))
            }
        }

        // Re-recalls follow any sprint you played (free play too): recalling it is the training.
        if let sprint = yesterdaysSprint(date: date) {
            steps.append(QuestStep(kind: .task(.sprintRetention, size: sprint.level), done: done(.sprintRetention)))
        }
        if let review = listReviewFor(date: date) {
            steps.append(QuestStep(kind: .task(.listReview, size: review.due.size), done: review.done, reviewOffset: review.due.offset))
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

    static func context(for task: RealmTask, size requested: Int, profile: Profile, date: Date = Date()) -> GameContext {
        let stamp = Notifications.dayStamp(date)
        var seed = "\(salt(profile))-\(stamp)-\(task.rawValue)"
        var size = task == .sequences ? profile.sequenceSpan : requested
        var palaceID = [.wordSprint, .sprintRetention, .routeWalk, .listReview].contains(task) ? palace(forItems: size)?.id : nil
        var reviewOffset = 0
        var championForm = 0
        if task == .wordRecall { seed = "benchmark" } // fixed forms; the form index rotates
        if task == .sprintRetention, let s = yesterdaysSprint(date: date) {
            seed = s.seed
            if let id = s.palaceID { palaceID = id }   // walk the palace the words were placed in
        }
        if task == .listReview, let review = listReviewFor(date: date) {
            seed = review.due.seed
            size = review.due.size
            reviewOffset = review.due.offset
            if let id = sprintLists(date: date).first(where: { $0.list.seed == review.due.seed })?.palaceID { palaceID = id }
        }
        if task == .championTest {
            championForm = BenchmarkPlanner.championForm(forSession: profile.championCount, userSeed: salt(profile))
            seed = "champion-\(championForm)"
            size = ChampionTest.size
        }
        if task == .championDelayed {
            let test = championYesterday(date: date) ?? sessions(on: date).first { $0.task == .championDelayed }
            if let test { seed = test.seed; championForm = Int(test.seed.split(separator: "-").last ?? "") ?? 0 }
            size = ChampionTest.size
        }
        let level = task.domain == .associative ? DifficultyStore.level(for: task) : 2
        var ctx = GameContext(task: task, seed: seed, size: size, level: level, courseDay: profile.courseDay,
                              palaceID: palaceID, benchmarkForm: BenchmarkPlanner.form(forSession: profile.benchmarkCount, userSeed: salt(profile)),
                              championForm: championForm, reviewOffset: reviewOffset, isBenchmark: task.isBenchmark, startedAt: date)
        if task == .wordSprint { ctx.pace = pace(.wordSprint) }
        if task == .numberSprint { ctx.pace = pace(.numberSprint) }
        return ctx
    }

    /// Today's study seconds per item: the speed ladder replayed over past course sprints.
    static func pace(_ kind: DrillKind) -> Double {
        let raw = kind == .wordSprint ? RealmTask.wordSprint.rawValue : RealmTask.numberSprint.rawValue
        let d = FetchDescriptor<TaskSession>(predicate: #Predicate { $0.taskRaw == raw && !$0.isFreePlay }, sortBy: [SortDescriptor(\.date)])
        let past = (try? Store.context.fetch(d)) ?? []
        return EncodingPace.pace(kind: kind, accuracies: past.map(\.score))
    }

    // MARK: Recording

    /// Most shinies free play can add in a day (the session itself is the main reward).
    static let freePlayShinyCap = 5

    /// Saves a finished game, adapts levels, and returns true if this completed the day's session.
    /// A game belongs to the day it was started on, even if it ends after midnight.
    @discardableResult
    static func record(_ outcome: GameOutcome, ctx: GameContext, profile: Profile) -> Bool {
        let day = ctx.startedAt
        let calendar = Calendar.current
        let now = Date()
        let stamp = calendar.isDate(now, inSameDayAs: day) ? now
            : calendar.date(bySettingHour: 23, minute: 59, second: 59, of: day) ?? day
        if !ctx.isFreePlay { pinPlan(profile, date: day) }
        let session = TaskSession(task: ctx.task, correct: outcome.correct, total: outcome.total, meanRTms: outcome.meanRTms,
                                  score: outcome.score, level: outcome.level ?? ctx.size, seed: ctx.seed,
                                  courseDay: profile.courseDay, isBenchmark: ctx.isBenchmark,
                                  palaceID: ctx.palaceID, reviewOffset: ctx.reviewOffset, date: stamp)
        session.isFreePlay = ctx.isFreePlay
        session.prediction = outcome.prediction
        session.secondsPerItem = outcome.secondsPerItem
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
        if let id = ctx.palaceID, let palace = palaces().first(where: { $0.id == id }) { palace.lastUsed = now }
        if ctx.task == .championTest, !calendar.isDate(profile.lastChampion ?? .distantPast, inSameDayAs: day) {
            profile.championCount += 1
            profile.lastChampion = stamp
        }
        if ctx.isFreePlay {
            let earned = sessions(on: day).filter(\.isFreePlay).count - 1   // this one is already inserted
            if earned < freePlayShinyCap { profile.shinies += 1 }
        } else {
            profile.shinies += 1
        }

        if ctx.isBenchmark {
            let battery: Set<RealmTask> = [.wordRecall, .digitSpan]
            let doneToday = Set(planSessions(on: day).filter(\.isBenchmark).map(\.task)).union([ctx.task])
            if battery.isSubset(of: doneToday), !calendar.isDate(profile.lastBenchmark ?? .distantPast, inSameDayAs: day) {
                profile.lastBenchmark = stamp
                profile.benchmarkCount += 1
            }
        }
        Store.save()
        if ctx.isFreePlay {
            // Free play never ticks off plan steps or moves the course; just refresh the surfaces.
            AppEvents.questChanged(profile: profile, justCompleted: false)
            return false
        }
        advanceCourseIfDone(profile, date: day)
        return refreshCompletion(profile, date: day)
    }

    static func markLessonRead(_ id: String, profile: Profile, date: Date = Date()) -> Bool {
        pinPlan(profile, date: date)
        if !profile.lessonsRead.contains(id) { profile.lessonsRead.append(id) }
        Store.save()
        advanceCourseIfDone(profile, date: date)
        return refreshCompletion(profile, date: date)
    }

    static func markVaultDone(profile: Profile, date: Date = Date()) -> Bool {
        pinPlan(profile, date: date)
        let record = Store.dayRecord(for: date)
        if !record.vaultDone {
            record.vaultDone = true
            profile.shinies += 1
        }
        Store.save()
        return refreshCompletion(profile, date: date)
    }

    /// The course moves to the next day once the day's lesson and drills are done — at most once a day.
    static func advanceCourseIfDone(_ profile: Profile, date: Date = Date()) {
        let calendar = Calendar.current
        guard !calendar.isDate(profile.lastCourseAdvance ?? .distantPast, inSameDayAs: date),
              !inBaseline(profile, date: date) else { return }
        let course = courseDay(profile, date: date)
        let today = planSessions(on: date)
        let lessonDone = course.lesson.map { profile.lessonsRead.contains($0.id) } ?? true
        let drillsDone = course.drills.allSatisfy { d in today.contains { $0.task == task(for: d.kind) } }
        if lessonDone && drillsDone && profile.courseDay < Course.length {
            profile.courseDay += 1
            profile.lastCourseAdvance = date
            Store.save()
        }
    }

    /// Updates the day record and fires side effects. Returns true when the session *just* completed.
    @discardableResult
    static func refreshCompletion(_ profile: Profile, date: Date = Date()) -> Bool {
        let s = steps(for: profile, date: date)
        let record = Store.dayRecord(for: date)
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

    /// "Delete everything": stop every alarm, notification and Live Activity first (so nothing keeps
    /// ringing for data that no longer exists), then wipe the store. RootView falls back to onboarding.
    static func eraseEverything() {
        AlarmService.cancelAll()
        LiveActivityService.endAll()
        Notifications.center.removeAllPendingNotificationRequests()
        Notifications.center.removeAllDeliveredNotifications()
        Store.deleteEverything()
        SpotlightIndex.clear()
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
    }

    /// Called on launch / foreground.
    static func appBecameActive() {
        guard let profile = Store.profile(), profile.onboardingComplete else { return }
        // Widgets and controls may have graded cards or ticked off reminders while we were away;
        // refreshCompletion replans everything, so just clear the flag.
        SharedStore.defaults?.removeObject(forKey: SharedStore.needsRefreshKey)
        _ = Quest.refreshCompletion(profile)
        SpotlightIndex.refreshIfStale()
        VaultGrading.refitIfNeeded(profile, in: Store.context)
        Task { await CircleService.shared.reportToday(profile: profile) }
    }
}
