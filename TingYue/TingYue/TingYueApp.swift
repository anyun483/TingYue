import SwiftUI

@main
struct TingYueApp: App {
    @StateObject private var store = BookStore.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .onOpenURL { url in
                    // 支持从文件 App / AirDrop / 微信「用其他应用打开」导入
                    store.importFromOutside(url)
                }
        }
    }
}
