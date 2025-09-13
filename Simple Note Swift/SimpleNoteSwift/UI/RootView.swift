import SwiftUI

struct RootView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var isLoggedIn = AuthManager.shared.access != nil
    var body: some View {
        NavigationStack {
            if isLoggedIn {
                HomeScreen()
            } else {
                OnboardingScreen(onGetStarted: { isLoggedIn = true })
            }
        }
        .onReceive(AuthManager.shared.$access) { _ in
            isLoggedIn = AuthManager.shared.access != nil
        }
    }
}
