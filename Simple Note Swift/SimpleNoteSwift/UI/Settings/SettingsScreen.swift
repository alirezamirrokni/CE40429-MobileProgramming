import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var user: UserInfo?
    @State private var showLogout = false
    var body: some View {
        List {
            if let u = user {
                Section {
                    HStack {
                        Circle().fill(.blue).frame(width: 48, height: 48)
                        VStack(alignment: .leading) {
                            Text(u.username).fontWeight(.semibold)
                            Text(u.email).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
            }
            Section {
                NavigationLink("Change Password") { ChangePasswordScreen() }
                Button("Log Out") { showLogout = true }.foregroundColor(.red)
            }
        }
        .task {
            do {
                user = try await env.api.userinfo()
            } catch {}
        }
        .alert("Log Out", isPresented: $showLogout) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                AuthManager.shared.clear()
            }
        }
        .navigationTitle("Settings")
    }
}

struct ChangePasswordScreen: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var old = ""
    @State private var new = ""
    @State private var info: String?
    var body: some View {
        Form {
            SecureField("Old password", text: $old)
            SecureField("New password", text: $new)
            if let i = info { Text(i).foregroundColor(.red) }
            Button("Save") {
                Task {
                    do {
                        try await env.api.changePassword(old: old, new: new)
                        info = "Updated"
                    } catch {
                        info = "Failed"
                    }
                }
            }
        }.navigationTitle("Change Password")
    }
}
