import SwiftUI
import SwiftData
import UserNotifications
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
            if phase == .active { AppEvents.appBecameActive() }
        }
    }
}

/// Where a notification / widget tap should land.
@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    enum Destination: Equatable { case today, delayedRecall, startQuest, reminders }
    @Published var pending: Destination?
    @Published var tab: Tab = .today

    enum Tab: Hashable { case today, practice, reminders, den }

    func open(_ url: URL) {
        switch url.host {
        case "quest": pending = .startQuest; tab = .today
        case "reminders": tab = .reminders
        case "recall": pending = .delayedRecall; tab = .today
        default: tab = .today
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in Notifications.registerCategories() }
        return true
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
                Router.shared.pending = (info["link"] as? String) == "delayedRecall" ? .delayedRecall : .startQuest
                Router.shared.tab = .today
            default: // plain tap
                if info["intention"] != nil {
                    Router.shared.tab = .reminders
                } else if (info["link"] as? String) == "delayedRecall" {
                    Router.shared.pending = .delayedRecall
                    Router.shared.tab = .today
                } else {
                    Router.shared.tab = .today
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
            } else {
                OnboardingFlow(existing: profiles.first)
                    .environment(\.theme, Theme.forID(profiles.first?.theme ?? .midnightRaccoon))
                    .preferredColorScheme(.dark)
            }
        }
        .onOpenURL { router.open($0) }
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
            NavigationStack { DeckView(profile: profile) }
                .tabItem { Label("Practice", systemImage: "rectangle.stack.fill") }
                .tag(Router.Tab.practice)
            NavigationStack { IntentionsView(profile: profile) }
                .tabItem { Label("Reminders", systemImage: "bell.badge.fill") }
                .tag(Router.Tab.reminders)
            NavigationStack { DenView(profile: profile) }
                .tabItem { Label(theme.copy.denTitle, systemImage: theme.id == .midnightRaccoon ? "sparkles" : "building.columns.fill") }
                .tag(Router.Tab.den)
        }
        .tint(theme.primary)
        .task {
            Notifications.replan(profile: profile)
            AppEvents.appBecameActive()
        }
    }
}
