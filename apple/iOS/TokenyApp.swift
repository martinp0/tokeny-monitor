import BackgroundTasks
import SwiftUI
import TokenyCore

@main
struct TokenyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel.shared
    @State private var watch = WatchBridge()

    nonisolated static let refreshTaskID = "cz.martinpohl.tokeny.refresh"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.auth.observe() }
                .task { await model.proStore.observe() }
                .task {
                    watch.activate(model: model)
                    model.onChange = { [watch, model] in watch.push(from: model) }
                    await model.refreshIfStale()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await model.proStore.syncNow()
                    await model.refreshIfStale()
                }
            case .background:
                Self.scheduleRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            Self.scheduleRefresh()
            await AppModel.shared.refresh()
        }
    }

    /// Asks iOS to wake the app in ~1 hour to refresh widgets and check the budget.
    nonisolated static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.auth.state == .unknown {
                ProgressView()
            } else if model.shouldShowOnboarding {
                OnboardingView()
            } else if model.showsImportHub {
                ImportHubView()
            } else {
                sessionHome
            }
        }
        .task(id: model.auth.isSignedIn) {
            if model.auth.isSignedIn || model.onDevice != nil {
                model.finishOnboarding()
            }
        }
    }

    /// If/else instead of a `switch` with `where` clauses. That switch, inside the root
    /// result builder, crashed swift-frontend in TypeCheckDecl while archiving.
    @ViewBuilder
    private var sessionHome: some View {
        if model.showsOnDevice {
            OnDeviceInsightsView()
        } else if model.auth.isSignedIn && model.auth.isLocalIdentity {
            LocalIdentityView()
        } else if model.auth.isSignedIn {
            DashboardView()
        } else if model.auth.state == .unknown {
            ProgressView()
        } else {
            SignInView()
        }
    }
}
