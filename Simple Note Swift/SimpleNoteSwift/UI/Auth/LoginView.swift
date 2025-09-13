import SwiftUI

struct LoginScreen: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?
    var body: some View {
        VStack(spacing: 16) {
            TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled(true).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            SecureField("Password", text: $password).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            if let e = errorText { Text(e).foregroundColor(.red) }
            Button {
                Task {
                    busy = true
                    do {
                        try await env.api.login(username: username, password: password)
                        await env.db.clear()
                        await Repository(api: env.api, db: env.db).syncOnce(query: "")
                    } catch {
                        errorText = "Login failed"
                    }
                    busy = false
                }
            } label: { Text(busy ? "Please wait" : "Log In").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled(busy)
        }.padding().navigationTitle("Log In")
    }
}
