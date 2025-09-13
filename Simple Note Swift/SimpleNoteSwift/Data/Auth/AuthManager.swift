import Foundation

final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    @Published var access: String? {
        didSet { if let v = access { Keychain.set(Data(v.utf8), for: "access") } else { Keychain.remove("access") } }
    }
    @Published var refresh: String? {
        didSet { if let v = refresh { Keychain.set(Data(v.utf8), for: "refresh") } else { Keychain.remove("refresh") } }
    }
    private init() {
        if let d = Keychain.get("access") { access = String(data: d, encoding: .utf8) }
        if let d = Keychain.get("refresh") { refresh = String(data: d, encoding: .utf8) }
    }
    func clear() {
        access = nil
        refresh = nil
    }
}
