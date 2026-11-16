import SwiftUI

@main
struct MySnakeApp: App {
    var body: some Scene {
        WindowGroup {
            SnakeRootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
