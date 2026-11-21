import SwiftUI

enum PhoneTab: Hashable {
    case overview, tips, sources, settings
}

struct PhoneShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var tab = PhoneTab.overview

    var body: some View {
        TabView(selection: $tab) {
            Tab("Přehled", systemImage: "chart.pie.fill", value: PhoneTab.overview) {
                OverviewView(tab: $tab)
            }
            Tab("Tipy", systemImage: "lightbulb.fill", value: PhoneTab.tips) {
                TipsView()
            }
            Tab("Zdroje", systemImage: "square.stack.3d.up.fill", value: PhoneTab.sources) {
                SourcesView()
            }
            Tab("Nastavení", systemImage: "gearshape.fill", value: PhoneTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(TokenyColor.accent(scheme))
        .onAppear(perform: applyScreenshotTab)
    }

    private func applyScreenshotTab() {
        switch model.screenshotTab {
        case "tips": tab = .tips
        case "sources": tab = .sources
        case "settings": tab = .settings
        default: break
        }
    }
}
