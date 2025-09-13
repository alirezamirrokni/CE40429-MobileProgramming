import SwiftUI

struct RegisterScreen: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var first = ""
    @State private var last = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var info: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TextField("First name", text: $first).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                TextField("Last name", text: $last).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled(true).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled(true).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                SecureField("Password", text: $password).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                if let i = info { Text(i).foregroundColor(.red) }
                Button {
                    Task {
                        busy = true
                        do {
                            try await env.api.register(username: username, email: email, password: password, first: first.isEmpty ? nil : first, last: last.isEmpty ? nil : last)
                            try await env.api.login(username: username, password: password)
                        } catch {
                            info = "Registration failed"
                        }
                        busy = false
                    }
                } label: { Text(busy ? "Please wait" : "Create account").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled(busy)
            }.padding()
        }.navigationTitle("Register")
    }
}
