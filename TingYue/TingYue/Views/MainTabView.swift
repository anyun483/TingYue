import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            BookShelfView().tabItem { Label("书架", systemImage: "books.vertical") }
            NowPlayingView().tabItem { Label("正在听", systemImage: "waveform") }
            SettingsView().tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
