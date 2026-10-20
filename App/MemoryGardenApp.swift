import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks
import CoreSpotlight
import TipKit
import MemoryCore

@main
struct MemoryGardenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(Router.shared)
        }
        .modelContainer(Store.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppEvents.appBecameActive()
                Router.shared.consumePendingRoute()
            }
            if phase == .background { DayRollover.schedule() }
        }
    }
}

/// Where a notification, widget, control, shortcut or Spotlight result should land.
@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    enum Destination: Equatable { case today, startQuest, reminders, newReminder, review, card(UUID) }
    @Published var pending: Destination?
    @Published var tab: Tab = .today

    enum Tab: Hashable { case today, train, vault, progress, reminders }

    func go(_ destination: Destination) {
        switch destination {
        case .today: tab = .today
        case .startQuest: tab = .today; pending = .startQuest
        case .reminders: tab = .reminders
        case .newReminder: tab = .reminders; pending = .newReminder
        case .review, .card: tab = .vault; pending = destination
        }
    }

    /// memorygarden://quest | review | reminders | new-reminder | today | card/<uuid>
    func open(_ url: URL) {
        switch url.host {
        case "quest": go(.startQuest)
        case "review": go(.review)
        case "reminders": go(.reminders)
        case "new-reminder": go(.newReminder)
        case "card":
            if let id = UUID(uuidString: url.lastPathComponent) { go(.card(id)) } else { go(.review) }
        default: go(.today)
        }
    }

    /// Controls and shortcuts leave a route in the App Group (they may run outside the app).
    func consumePendingRoute() {
        guard let route = SharedStore.defaults?.string(forKey: SharedStore.pendingRouteKey) else { return }
        SharedStore.defaults?.removeObject(forKey: SharedStore.pendingRouteKey)
        if let url = URL(string: "memorygarden://\(route)") { open(url) }
    }

    /// Home-screen quick actions (long-press the app icon).
    func handle(shortcutType: String) {
        switch shortcutType {
        case "start": go(.startQuest)
        case "review": go(.review)
        case "reminder": go(.newReminder)
        default: go(.today)
        }
    }
}

/// Rolls widgets, the Live Activity and reminders over to the new day shortly after midnight,
/// even if the app isn't opened (Background App Refresh — a free capability).
enum DayRollover {
    static let identifier = "com.mxhddd.memorygarden.dayrollover"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            Task { @MainActor in
                LiveActivityService.endIfStale()
                if let profile = Store.profile(), profile.onboardingComplete {
                    WidgetBridge.update(profile: profile)
                    Notifications.replan(profile: profile)
                }
                schedule()
                task.setTaskCompleted(success: true)
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        request.earliestBeginDate = midnight.addingTimeInterval(5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in Notifications.registerCategories() }
        DayRollover.register()
        try? Tips.configure([.displayFrequency(.daily)])
        application.shortcutItems = QuickActions.items
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = QuickActionSceneDelegate.self
        if let item = options.shortcutItem {
            Task { @MainActor in Router.shared.handle(shortcutType: item.type) }
        }
        return config
    }

    // Show banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        let info = request.content.userInfo
        let action = response.actionIdentifier
        await MainActor.run {
            switch action {
            case Notifications.Action.done.rawValue:
                if let s = info["intention"] as? String, let id = UUID(uuidString: s) { Notifications.markIntentionDone(id) }
            case Notifications.Action.snooze.rawValue:
                Notifications.snooze(request, minutes: 10)
            case Notifications.Action.tonight.rawValue:
                Notifications.snoozeToTonight(request)
            case Notifications.Action.start.rawValue:
                Router.shared.go(.startQuest)
            case Notifications.Action.answer.rawValue:
                if let text = (response as? UNTextInputNotificationResponse)?.userText,
                   let s = info["card"] as? String, let id = UUID(uuidString: s) {
                    Notifications.answerCard(id, with: text)
                }
            case Notifications.Action.showCard.rawValue:
                if let s = info["card"] as? String, let id = UUID(uuidString: s) { Router.shared.go(.card(id)) }
            default: // plain tap
                if info["intention"] != nil {
                    Router.shared.go(.reminders)
                } else if let s = info["card"] as? String, let id = UUID(uuidString: s) {
                    Router.shared.go(.card(id))
                } else if info["refresh"] != nil {
                    UIApplication.shared.open(SigningInfo.sideStoreURL)
                } else {
                    Router.shared.go(.today)
                }
            }
        }
    }
}

struct RootView: View {
    @Query private var profiles: [Profile]
    @EnvironmentObject private var router: Router

    var body: some View {
        Group {
            if let profile = profiles.first, profile.onboardingComplete {
                MainTabView(profile: profile)
                    .environment(\.theme, Theme.forID(profile.theme))
                    .preferredColorScheme(Theme.forID(profile.theme).colorScheme)
                    .onAppear { SFX.theme = profile.theme }
                    .onChange(of: profile.theme) { _, new in SFX.theme = new }
            } else {
                OnboardingFlow(existing: profiles.first)
                    .environment(\.theme, Theme.forID(profiles.first?.theme ?? .midnightRaccoon))
                    .preferredColorScheme(.dark)
            }
        }
        .onOpenURL { router.open($0) }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String { SpotlightIndex.open(id) }
        }
    }
}

/// Long-press the app icon: Start training · Review cards · New reminder.
enum QuickActions {
    static var items: [UIApplicationShortcutItem] {
        [
            UIApplicationShortcutItem(type: "start", localizedTitle: "Start training", localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: "moon.stars.fill")),
            UIApplicationShortcutItem(type: "review", localizedTitle: "Review cards", localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: "rectangle.stack.fill")),
            UIApplicationShortcutItem(type: "reminder", localizedTitle: "New reminder", localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: "bell.badge.fill")),
        ]
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in Router.shared.handle(shortcutType: shortcutItem.type) }
        completionHandler(true)
    }
}

struct MainTabView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @EnvironmentObject private var router: Router

    var body: some View {
        TabView(selection: $router.tab) {
            NavigationStack { TodayView(profile: profile) }
                .tabItem { Label("Today", systemImage: theme.id == .midnightRaccoon ? "moon.stars.fill" : "sun.max.fill") }
                .tag(Router.Tab.today)
            NavigationStack { TrainView(profile: profile) }
                .tabItem { Label("Train", systemImage: "building.columns.fill") }
                .tag(Router.Tab.train)
            NavigationStack { VaultView(profile: profile) }
                .tabItem { Label("Vault", systemImage: "rectangle.stack.fill") }
                .tag(Router.Tab.vault)
            NavigationStack { ProgressScreen(profile: profile) }
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Router.Tab.progress)
            NavigationStack { IntentionsView(profile: profile) }
                .tabItem { Label("Reminders", systemImage: "bell.badge.fill") }
                .tag(Router.Tab.reminders)
        }
        .tint(theme.primary)
        .task {
            Notifications.replan(profile: profile)
        }
    }
}
