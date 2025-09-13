import SwiftUI

@main
struct SimpleNoteSwiftApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppEnvironment())
        }
    }
}
