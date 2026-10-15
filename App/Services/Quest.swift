import Foundation
import SwiftData
import MemoryCore

/// One step of today's quest.
enum QuestStepKind: Hashable {
    case task(RealmTask)
    case deck
}

struct QuestStep: Identifiable, Hashable {
    var kind: QuestStepKind
    var done: Bool
    var id: String {
        switch kind {
        case .task(let t): return t.rawValue
        case .deck: return "deck"
        }
    }
}

/// Decides today's quest, builds game contexts and records results.
///
/// Burst days (7 days every 4 weeks) = *measurement*: Face–Name + Ancient Runes with the same
/// stimuli all week (learning curve) + one rotating task, all at fixed difficulty.
/// Other days = *training*: personal deck + one adaptive task (+ speed sessions when scheduled).
@MainActor
enum Quest {
    static let trainingRotation: [RealmTask] = [.stash, .snackPrices, .sequences, .wordList, .faceName, .ancientRunes]

    static func salt(_ profile: Profile) -> String { String(Int(profile.createdAt.timeIntervalSince1970)) }

    static func todaysSessions(_ date: Date = Date()) -> [TaskSession] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let d = FetchDescriptor<TaskSession>(predicate: #Predicate { $0.date >= start && $0.date < end && $0.isDelayedRecall == false })
        return (try? Store.context.fetch(d)) ?? []
    }

    static func cardCount() -> Int {
        (try? Store.context.fetchCount(FetchDescriptor<MemoryCard>())) ?? 0
    }

    static func dueCards(_ now: Date = Date()) -> [MemoryCard] {
        let d = FetchDescriptor<MemoryCard>(predicate: #Predicate { $0.due <= now }, sortBy: [SortDescriptor(\.due)])
        return (try? Store.context.fetch(d)) ?? []
    }

    static func plannedTasks(for profile: Profile, date: Date = Date()) -> [RealmTask] {
        let planner = profile.planner
        if planner.burstDay(for: date) != nil {
            return planner.tasks(for: date)
        }
        let dayIndex = max(planner.dayIndex(for: date), 0)
        var tasks = [trainingRotation[dayIndex % trainingRotation.count]]
        let speedDone = speedSessionsInCurrentPhase(profile)
        if SpeedSchedule.sessionSuggested(phase: SpeedSchedule.phase(start: profile.speedStart, now: date), sessionsDoneInPhase: speedDone),
           dayIndex % 3 != 2 { // ~10 sessions spread over the first 6 weeks
            tasks.append(.runeSort)
        }
        if cardCount() == 0 && tasks.count < 2 {
            tasks.append(trainingRotation[(dayIndex + 2) % trainingRotation.count])
        }
        return tasks
    }

    static func steps(for profile: Profile, date: Date = Date()) -> [QuestStep] {
        let doneTasks = Set(todaysSessions(date).map(\.taskRaw))
        var steps = plannedTasks(for: profile, date: date).map { QuestStep(kind: .task($0), done: doneTasks.contains($0.rawValue)) }
        if profile.planner.burstDay(for: date) == nil, cardCount() > 0 {
            steps.insert(QuestStep(kind: .deck, done: Store.dayRecord(for: date).deckDone), at: 0)
        }
        return steps
    }

    static func isBurstDay(_ profile: Profile, date: Date = Date()) -> Bool {
        profile.planner.burstDay(for: date) != nil
    }

    static func context(for task: RealmTask, profile: Profile, date: Date = Date()) -> GameContext {
        let planner = profile.planner
        let burst = planner.burstDay(for: date)
        let dayIndex = max(planner.dayIndex(for: date), 0)
        let seed: String
        if let b = burst {
            seed = "\(salt(profile))-burst\(b.burst)-\(task.rawValue)" // same stimuli all burst week
        } else {
            seed = "\(salt(profile))-day\(dayIndex)-\(task.rawValue)"
        }
        let gentle = profile.errorlessNewCards
        let level = burst != nil ? 2 : DifficultyStore.level(for: task, gentle: gentle)
        let firstTask = plannedTasks(for: profile, date: date).first == task
        let moonBell = firstTask && (burst != nil || dayIndex % 2 == 0)
        let form = burst.map { $0.burst } ?? (dayIndex + 3)
        return GameContext(task: task, seed: seed, burst: burst, level: level, gentle: gentle, moonBell: moonBell, wordForm: form)
    }

    static func delayedRecallContext(_ pending: DelayedRecall.Pending, profile: Profile) -> GameContext {
        GameContext(task: .wordList, seed: pending.seed, burst: pending.burst >= 0 ? (burst: pending.burst, day: pending.burstDay) : nil,
                    level: 2, gentle: profile.errorlessNewCards, moonBell: false, wordForm: pending.form, delayedRecall: true)
    }

    /// Saves a finished game and returns true if this completed today's quest.
    @discardableResult
    static func record(_ outcome: GameOutcome, ctx: GameContext, profile: Profile) -> Bool {
        let session = TaskSession(task: ctx.task, correct: outcome.correct, total: outcome.total, meanRTms: outcome.meanRTms,
                                  score: outcome.score, seed: ctx.seed, burst: ctx.burst, delayed: ctx.delayedRecall)
        Store.context.insert(session)
        if !ctx.isMeasurement && !outcome.trials.isEmpty {
            DifficultyStore.record(outcome.trials, for: ctx.task)
        }
        if ctx.task == .runeSort {
            UserDefaults.standard.set(speedSessionsInCurrentPhase(profile) + 1, forKey: speedKey(profile))
        }
        profile.shinies += 1

        if ctx.task == .wordList && !ctx.delayedRecall {
            DelayedRecall.pending = .init(form: ctx.wordForm, seed: ctx.seed, studiedAt: Date(),
                                          burst: ctx.burst?.burst ?? -1, burstDay: ctx.burst?.day ?? 0)
            Notifications.scheduleDelayedRecall(mascot: profile.mascotName, theme: profile.theme)
        }
        if ctx.delayedRecall { DelayedRecall.pending = nil }
        Store.save()
        return refreshCompletion(profile)
    }

    static func recordMoonBell(hit: Bool, ctx: GameContext) {
        let session = TaskSession(task: .moonBell, correct: hit ? 1 : 0, total: 1, meanRTms: 0, score: hit ? 1 : 0,
                                  seed: ctx.seed, burst: ctx.burst)
        Store.context.insert(session)
        Store.save()
    }

    static func markDeckDone(profile: Profile) -> Bool {
        Store.dayRecord().deckDone = true
        profile.shinies += 1
        Store.save()
        return refreshCompletion(profile)
    }

    /// Updates the day record and fires all side effects. Returns true when the quest *just* completed.
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

    // Speed module bookkeeping (ACTIVE-style initial block + boosters)
    private static func speedKey(_ profile: Profile) -> String {
        let phase = SpeedSchedule.phase(start: profile.speedStart, now: Date())
        switch phase {
        case .initial: return "speed.initial"
        case .booster(let n): return "speed.booster\(n)"
        case .rest: return "speed.rest"
        }
    }

    static func speedSessionsInCurrentPhase(_ profile: Profile) -> Int {
        UserDefaults.standard.integer(forKey: speedKey(profile))
    }

    /// Consecutive weeks (Mon–Sun) with ≥ 4 quest days — forgiving weekly streaks, not daily ones.
    static func weeklyStreak() -> Int {
        let records = (try? Store.context.fetch(FetchDescriptor<DayRecord>(predicate: #Predicate { $0.questDone == true }))) ?? []
        var cal = Calendar.current
        cal.firstWeekday = 2
        let byWeek = Dictionary(grouping: records) { cal.dateInterval(of: .weekOfYear, for: $0.day)?.start ?? $0.day }
        var streak = 0
        var week = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        // The current week counts if it already qualifies; otherwise start from last week.
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

/// Fan-out of side effects whenever quest progress changes.
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
        for date in SharedStore.takePendingLapses() {
            Store.context.insert(LapseLog(date: date, note: "from widget"))
        }
        Store.save()
        _ = Quest.refreshCompletion(profile)
        Task { await CircleService.shared.reportToday(profile: profile) }
    }
}
