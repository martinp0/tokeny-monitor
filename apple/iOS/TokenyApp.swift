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
                .task { model.applyLaunchArguments() }
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
        @Bindable var model = model
        return Group {
            if model.auth.state == .unknown && !model.screenshotShell {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tokenyScreen()
            } else if model.shouldShowOnboarding {
                OnboardingView()
            } else if model.showsShell {
                PhoneShell()
            } else {
                SignInView()
            }
        }
        .tint(TokenyColor.accent(colorScheme))
        .sheet(isPresented: $model.showsImportHub) {
            ImportHubView()
        }
        .task(id: model.auth.isSignedIn) {
            if model.auth.isSignedIn || model.onDevice != nil {
                model.finishOnboarding()
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
}
