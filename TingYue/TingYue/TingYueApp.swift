import SwiftUI
import SwiftData

@main
struct TingYueApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    // 支持从文件 App / AirDrop / 微信「用其他应用打开」导入
                    guard let context = try? ModelContext(
                        ModelContainer(for: Book.self)) else { return }
                    _ = try? ImportService.importFile(url, context: context)
                }
        }
        .modelContainer(for: Book.self)
    }
}
