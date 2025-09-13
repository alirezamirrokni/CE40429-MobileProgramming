import SwiftUI

struct OnboardingScreen: View {
    var onGetStarted: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("SimpleNote").font(.largeTitle).fontWeight(.bold)
            Text("A modern, offline-first note-taking app").multilineTextAlignment(.center)
            Spacer()
            NavigationLink("Log In") { LoginScreen() }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
            NavigationLink("Register") { RegisterScreen() }
                .padding(.horizontal, 24)
            Spacer().frame(height: 24)
        }.padding()
    }
}
